"""Moshi controls with temporary markers and a fake service manager."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "moshi/control.sh"
TARGET = "~/.config/moshi/control.sh"
SERVICE_TARGET = "~/.config/moshi/service.py"
MISE = shutil.which("mise")


def toml_value(value):
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{json.dumps(key)} = {toml_value(item)}"
                                  for key, item in value.items()) + " }"
    if isinstance(value, list):
        return "[" + ", ".join(toml_value(item) for item in value) + "]"
    return json.dumps(value)


class MoshiControlTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="moshi control home ")
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name).resolve()
        self.directory = self.home / ".config/moshi"
        self.enabled = self.directory / "enabled"
        self.disabled = self.directory / "disabled"
        self.log = self.home / "unexpected-moshi-call"
        self.service_log = self.home / "service-calls"
        fake_bin = self.home / "fake bin"
        fake_bin.mkdir()
        notifier = fake_bin / "moshi-hook"
        notifier.write_text('#!/bin/sh\nprintf called > "$MOSHI_TEST_CALL_LOG"\nexit 99\n')
        notifier.chmod(0o755)
        service = fake_bin / "python3"
        service.write_text(
            '#!/bin/sh\n'
            '[ "$1" = "$HOME/.config/moshi/service.py" ] || exit 98\n'
            'case "$2" in on|off)\n'
            '  [ -e "$HOME/.config/moshi/disabled" ] && [ ! -e "$HOME/.config/moshi/enabled" ] || exit 97;;\n'
            'esac\n'
            'printf "%s\\n" "$2" >> "$MOSHI_TEST_SERVICE_LOG"\n'
            '[ "$2" != "${MOSHI_TEST_SERVICE_FAIL:-}" ] || exit 23\n'
            '[ "$2" != status ] || printf "Moshi service: test backend.\\n"\n'
            'exit 0\n'
        )
        service.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / "different xdg root"),
                        PATH=f"{fake_bin}:/usr/bin:/bin",
                        MOSHI_TEST_CALL_LOG=str(self.log),
                        MOSHI_TEST_SERVICE_LOG=str(self.service_log))
        self.env.pop("DOTFILES_MOSHI_ENABLED", None)
        self.env.pop("DOTFILES_MOSHI_DISABLED", None)
        self.addCleanup(lambda: self.assertFalse(self.log.exists(), "control invoked Moshi"))

    def control(self, *args, overrides=None, check=True):
        return subprocess.run(["/bin/sh", str(SOURCE), *args],
                              env=dict(self.env, **(overrides or {})), cwd=self.home,
                              capture_output=True, text=True, check=check, timeout=5)

    def assert_status(self, result, expected):
        self.assertRegex(result.stdout.lower(), rf"\b{expected}\b")
        self.assertEqual(result.stderr, "")

    def marker(self, name, content="personal marker\n"):
        self.directory.mkdir(parents=True, exist_ok=True)
        (self.directory / name).write_text(content)

    def snapshot(self):
        return {str(path.relative_to(self.home)): path.read_bytes() if path.is_file() else None
                for path in self.home.rglob("*") if path != self.service_log}

    def test_default_status_is_off_and_read_only(self):
        before = self.snapshot()
        self.assert_status(self.control(), "off")
        self.assert_status(self.control("status"), "off")
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(self.directory.exists())

    def test_bootstrap_does_not_install_moshi(self):
        config = tomllib.loads((ROOT / "mise/config.toml").read_text())
        self.assertFalse(any("moshi" in package for package in config["bootstrap"]["packages"]))
        self.assertEqual(config["dotfiles"]["~/.config/moshi/config.toml"]["mode"], "copy")

    def test_status_preserves_existing_markers_and_unrelated_files(self):
        self.marker("enabled", "keep this marker\n")
        self.marker("config.toml", 'paired = "local only"\n')
        before = self.snapshot()
        self.assert_status(self.control("status"), "on")
        self.assertEqual(self.snapshot(), before)
        self.marker("disabled", "explicit disable wins\n")
        before = self.snapshot()
        self.assert_status(self.control(), "off")
        self.assertEqual(self.snapshot(), before)

    def test_round_trip_is_idempotent_and_uses_home_even_with_other_xdg_root(self):
        self.marker("config.toml", 'paired = "preserve me"\n')
        for action in ("on", "on", "off", "off", "on"):
            with self.subTest(action=action):
                self.assert_status(self.control(action), action)
                self.assertEqual(self.enabled.is_file(), action == "on")
                self.assertEqual(self.disabled.is_file(), action == "off")
                self.assertEqual((self.directory / "config.toml").read_text(),
                                 'paired = "preserve me"\n')
                self.assert_status(self.control("status"), action)
        self.assertFalse(Path(self.env["XDG_CONFIG_HOME"]).exists())

    def test_environment_cannot_enable_and_explicit_disable_wins(self):
        before = self.snapshot()
        self.assert_status(self.control("status", overrides={"DOTFILES_MOSHI_ENABLED": "1"}), "off")
        self.assert_status(self.control("status", overrides={
            "DOTFILES_MOSHI_ENABLED": "1", "DOTFILES_MOSHI_DISABLED": "1",
        }), "off")
        self.assert_status(self.control("status", overrides={
            "DOTFILES_MOSHI_ENABLED": "0", "DOTFILES_MOSHI_DISABLED": "0",
        }), "off")
        self.assertEqual(self.snapshot(), before)
        self.marker("enabled")
        before = self.snapshot()
        self.assert_status(self.control("status", overrides={"DOTFILES_MOSHI_DISABLED": "1"}), "off")
        self.assertEqual(self.snapshot(), before)
        self.marker("disabled")
        self.assert_status(self.control("status", overrides={"DOTFILES_MOSHI_ENABLED": "1"}), "off")

    def test_on_refuses_environment_disable_without_starting_service(self):
        self.marker("disabled")
        overrides = {"DOTFILES_MOSHI_DISABLED": "1"}
        before = self.snapshot()
        result = self.control("on", overrides=overrides, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DOTFILES_MOSHI_DISABLED=1", result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(self.service_log.exists())
        self.assert_status(self.control("status", overrides=overrides), "off")
        self.assert_status(self.control("status"), "off")

    def test_on_starts_service_and_off_stops_it(self):
        self.control("on")
        self.control("off")
        self.assertEqual(self.service_log.read_text().splitlines(), ["on", "status", "off", "status"])

    def test_failed_service_start_leaves_hooks_disabled(self):
        self.marker("enabled")
        result = self.control("on", overrides={"MOSHI_TEST_SERVICE_FAIL": "on"}, check=False)
        self.assertEqual(result.returncode, 23)
        self.assertFalse(self.enabled.exists())
        self.assertTrue(self.disabled.exists())

    def test_failed_service_stop_still_revokes_hooks_and_reports_failure(self):
        self.marker("enabled")
        result = self.control("off", overrides={"MOSHI_TEST_SERVICE_FAIL": "off"}, check=False)
        self.assertEqual(result.returncode, 23)
        self.assertFalse(self.enabled.exists())
        self.assertTrue(self.disabled.exists())

    def test_off_overrides_environment_enable(self):
        self.marker("enabled")
        overrides = {"DOTFILES_MOSHI_ENABLED": "1"}
        self.assert_status(self.control("off", overrides=overrides), "off")
        self.assertTrue(self.disabled.is_file())
        self.assertFalse(self.enabled.exists())
        self.assert_status(self.control("status", overrides=overrides), "off")

    def test_invalid_action_and_arity_do_not_change_files(self):
        invalid = [("enable",), ("",), ("on", "extra"), ("off", "extra"), ("status", "extra")]
        for existing in (False, True):
            if existing:
                self.marker("enabled", "preserve current choice\n")
            for args in invalid:
                with self.subTest(existing=existing, args=args):
                    before = self.snapshot()
                    result = self.control(*args, check=False)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(self.snapshot(), before)

    @unittest.skipUnless(MISE, "requires mise with dotfiles support")
    def test_mise_task_deploys_control_and_forwards_arguments(self):
        source_config = tomllib.loads((ROOT / "mise/config.toml").read_text())
        mapping = source_config["dotfiles"][TARGET]
        self.assertEqual((ROOT / "mise" / mapping["source"]).resolve(), SOURCE)
        self.assertEqual(mapping["mode"], "symlink")
        service_mapping = source_config["dotfiles"][SERVICE_TARGET]
        self.assertEqual(service_mapping, {"source": "../moshi/service.py", "mode": "symlink"})
        for marker in ("enabled", "disabled"):
            self.assertNotIn(f"~/.config/moshi/{marker}", source_config["dotfiles"])
        task = source_config["tasks"]["moshi"]
        config = self.home / "mise.toml"
        config.write_text(
            "[dotfiles]\n"
            f'{json.dumps(TARGET)} = {toml_value(dict(mapping, source=str(SOURCE)))}\n'
            f'{json.dumps(SERVICE_TARGET)} = {toml_value(dict(service_mapping, source=str(ROOT / "moshi/service.py")))}\n'
            "[tasks.moshi]\n" +
            "".join(f"{json.dumps(key)} = {toml_value(value)}\n" for key, value in task.items())
        )
        env = dict(self.env, MISE_GLOBAL_CONFIG_FILE=str(config),
                   MISE_TRUSTED_CONFIG_PATHS=str(self.home),
                   MISE_DATA_DIR=str(self.home / "mise data"),
                   MISE_CACHE_DIR=str(self.home / "mise cache"),
                   MISE_STATE_DIR=str(self.home / "mise state"),
                   MISE_NO_AUTO_INSTALL="1")
        subprocess.run([MISE, "-C", str(self.home), "dot", "apply", "--yes", TARGET, SERVICE_TARGET],
                       env=env, capture_output=True, text=True, check=True, timeout=10)
        deployed = self.directory / "control.sh"
        self.assertTrue(deployed.is_symlink())
        self.assertEqual(deployed.resolve(), SOURCE)
        command = [MISE, "-C", str(self.home), "run", "moshi"]

        def run(*args):
            return subprocess.run([*command, *args], env=env, cwd=self.home,
                                  capture_output=True, text=True, check=True, timeout=10)

        self.assertRegex(run().stdout.lower(), r"\boff\b")
        self.assertFalse(self.enabled.exists())
        self.assertFalse(self.disabled.exists())
        self.assertRegex(run("on").stdout.lower(), r"\bon\b")
        self.assertTrue(self.enabled.is_file())
        self.assertFalse(self.disabled.exists())
        before = (self.enabled.read_bytes(), self.enabled.stat().st_mtime_ns)
        self.assertRegex(run("status").stdout.lower(), r"\bon\b")
        self.assertEqual((self.enabled.read_bytes(), self.enabled.stat().st_mtime_ns), before)
        self.assertRegex(run("off").stdout.lower(), r"\boff\b")
        self.assertTrue(self.disabled.is_file())
        self.assertFalse(self.enabled.exists())


if __name__ == "__main__":
    unittest.main()
