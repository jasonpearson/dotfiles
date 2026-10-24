"""Portable Claude/Codex hook adapter tests; never invoke the machine's real Moshi."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMMAND = 'sh "$HOME/.config/moshi/agent-hook.sh" claude-hook'
CODEX_COMMAND = 'sh "$HOME/.config/moshi/agent-hook.sh" codex-hook'


class MoshiHookTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="moshi hooks ")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.adapter = self.home / ".config/moshi/agent-hook.sh"
        self.adapter.parent.mkdir(parents=True)
        self.bin = self.home / "bin-on-path"
        self.bin.mkdir()
        (self.bin / "sh").symlink_to("/bin/sh")
        # Redirect only the system-wide fallback prefixes into this sandbox.
        # This lets missing-binary tests run even on a paired developer machine.
        script = (ROOT / "moshi/agent-hook.sh").read_text()
        self.brew = self.home / "homebrew/bin/moshi-hook"
        for prefix, location in [
            ("/opt/homebrew/bin/moshi-hook", self.brew),
            ("/usr/local/bin/moshi-hook", self.home / "usr-local/bin/moshi-hook"),
            ("/opt/local/bin/moshi-hook", self.home / "opt-local/bin/moshi-hook"),
        ]:
            script = script.replace(prefix, shlex.quote(str(location)))
        self.adapter.write_text(script)
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin),
                        XDG_CONFIG_HOME=str(self.home / "elsewhere"))
        self.env.pop("DOTFILES_MOSHI_DISABLED", None)
        self.env.pop("DOTFILES_MOSHI_ENABLED", None)

    def enable(self):
        self.adapter.with_name("enabled").touch()

    def binary(self, path, label="path", status=0):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f'''#!/bin/sh
printf '%s\\n' '{label}' "$@"
while IFS= read -r line; do printf '%s\\n' "$line"; done
exit {status}
''')
        path.chmod(0o755)

    def run_hook(self, agent="claude-hook", arguments=()):
        # Build commands from known adapter arguments, never execute a command
        # taken from application settings (which installers may have rewritten).
        self.assertIn(agent, ("claude-hook", "codex-hook"))
        command = 'sh "$HOME/.config/moshi/agent-hook.sh" ' + shlex.join((agent, *arguments))
        return subprocess.run(["/bin/sh", "-c", command], env=self.env,
                              input='{"hook_event_name":"PermissionRequest"}\n',
                              text=True, capture_output=True, timeout=5)

    def test_path_binary_preserves_input_arguments_output_and_status(self):
        self.enable()
        self.binary(self.bin / "moshi-hook", status=7)
        self.binary(self.home / ".local/bin/moshi-hook", label="fallback")
        result = self.run_hook(arguments=("argument with spaces",))
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, 'path\nclaude-hook\nargument with spaces\n'
                         '{"hook_event_name":"PermissionRequest"}\n')
        self.assertEqual(result.stderr, "")

    def test_minimal_path_falls_back_to_user_install_then_homebrew(self):
        self.enable()
        local = self.home / ".local/bin/moshi-hook"
        self.binary(local, label="local")
        self.binary(self.brew, label="brew")
        self.assertTrue(self.run_hook().stdout.startswith("local\nclaude-hook\n"))
        local.unlink()
        self.assertTrue(self.run_hook().stdout.startswith("brew\nclaude-hook\n"))

    def test_missing_binary_is_quiet_success(self):
        self.enable()
        result = self.run_hook()
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))

    def test_default_is_disabled_even_when_binary_exists(self):
        self.binary(self.bin / "moshi-hook", status=42)
        result = self.run_hook()
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))

    def test_environment_cannot_enable_without_marker(self):
        self.binary(self.bin / "moshi-hook", status=42)
        for value in ("1", "true", "on"):
            with self.subTest(value=value):
                self.env["DOTFILES_MOSHI_ENABLED"] = value
                result = self.run_hook()
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))

    def test_removing_opt_in_stops_future_hooks(self):
        self.enable()
        self.binary(self.bin / "moshi-hook")
        self.assertTrue(self.run_hook().stdout)
        self.adapter.with_name("enabled").unlink()
        result = self.run_hook()
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))

    def test_explicit_disable_overrides_local_opt_in(self):
        self.enable()
        self.binary(self.bin / "moshi-hook", status=42)
        marker = self.adapter.with_name("disabled")
        self.env["DOTFILES_MOSHI_ENABLED"] = "1"
        for opt_out in ("marker", "environment"):
            with self.subTest(opt_out=opt_out):
                marker.unlink(missing_ok=True)
                self.env.pop("DOTFILES_MOSHI_DISABLED", None)
                if opt_out == "marker":
                    marker.touch()
                else:
                    self.env["DOTFILES_MOSHI_DISABLED"] = "1"
                result = self.run_hook()
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))

    def test_configured_codex_hooks_require_local_opt_in(self):
        config = json.loads((ROOT / "agents/codex/hooks.json").read_text())
        commands = [hook["command"] for groups in config["hooks"].values()
                    for group in groups for hook in group["hooks"]
                    if "moshi" in hook.get("command", "")]
        self.assertEqual(len(commands), 4)
        self.binary(self.bin / "moshi-hook")
        for command in commands:
            with self.subTest(command=command):
                self.assertEqual(command, CODEX_COMMAND)
                result = self.run_hook(agent="codex-hook")
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
                self.enable()
                self.assertTrue(self.run_hook(agent="codex-hook").stdout.startswith("path\ncodex-hook\n"))
                self.env["DOTFILES_MOSHI_DISABLED"] = "1"
                result = self.run_hook(agent="codex-hook")
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))
                self.env.pop("DOTFILES_MOSHI_DISABLED")
                self.adapter.with_name("enabled").unlink()

    def test_settings_do_not_load_an_ungated_moshi_plugin(self):
        settings = json.loads((ROOT / "agents/claude/settings.json").read_text())
        plugin_dirs = settings.get("env", {}).get("CLAUDE_CODE_PLUGIN_DIRS", "")
        self.assertNotIn("moshi", plugin_dirs.lower())
        for plugin in settings.get("enabledPlugins", {}):
            self.assertNotIn("moshi", plugin.lower())

    def test_shared_hooks_contain_no_machine_specific_paths(self):
        for filename in ("agents/claude/settings.json", "agents/codex/hooks.json"):
            with self.subTest(filename=filename):
                source = (ROOT / filename).read_text()
                self.assertNotIn("/Users/", source)
                self.assertNotIn("/home/", source)

    @unittest.skipUnless(shutil.which("mise"), "requires mise >= 2026.10.4")
    def test_claude_settings_copy_protects_source_from_installer_edits(self):
        mappings = tomllib.loads((ROOT / "mise/config.toml").read_text())["dotfiles"]
        self.assertIn("settings.json", mappings["~/.claude"]["exclude"])
        settings_mapping = mappings["~/.claude/settings.json"]
        self.assertEqual(settings_mapping, {
            "source": "../agents/claude/settings.json", "mode": "copy",
        })
        with tempfile.TemporaryDirectory(prefix="claude deployment ") as temp:
            home = Path(temp)
            source = home / "source/claude"
            source.mkdir(parents=True)
            settings_source = source / "settings.json"
            settings_source.write_bytes((ROOT / "agents/claude/settings.json").read_bytes())
            source_contents = settings_source.read_bytes()
            (source / "other.json").write_text('{"shared": true}\n')
            target = home / ".claude/settings.json"
            target.parent.mkdir()
            target.symlink_to(settings_source)
            unrelated = target.with_name("local-only.json")
            unrelated.write_text('{"work": "preserve"}\n')
            config = home / "mise.toml"
            config.write_text(
                '[dotfiles]\n'
                f'"~/.claude" = {{ source = "{source}", mode = "symlink-each", exclude = ["settings.json"] }}\n'
                f'"~/.claude/settings.json" = {{ source = "{settings_source}", mode = "copy" }}\n'
            )
            env = dict(os.environ, HOME=temp, XDG_CONFIG_HOME=str(home / ".config"),
                       MISE_GLOBAL_CONFIG_FILE=str(config), MISE_TRUSTED_CONFIG_PATHS=temp,
                       MISE_DATA_DIR=str(home / "data"), MISE_CACHE_DIR=str(home / "cache"),
                       MISE_STATE_DIR=str(home / "state"))
            subprocess.run([shutil.which("mise"), "-C", temp, "dot", "apply", "--yes",
                            "~/.claude", "~/.claude/settings.json"],
                           env=env, check=True, text=True, capture_output=True)
            self.assertFalse(target.is_symlink())
            self.assertEqual(target.read_bytes(), source_contents)
            self.assertTrue(target.with_name("other.json").is_symlink())
            self.assertEqual(unrelated.read_text(), '{"work": "preserve"}\n')
            # Installer changes belong only to this computer's writable copy.
            deployed = json.loads(target.read_text())
            deployed["env"]["CLAUDE_CODE_PLUGIN_DIRS"] = "local-installer-state"
            target.write_text(json.dumps(deployed))
            self.assertEqual(settings_source.read_bytes(), source_contents)

    def test_settings_use_adapter_and_keep_permission_request_synchronous(self):
        settings = json.loads((ROOT / "agents/claude/settings.json").read_text())
        hooks = [(event, hook) for event, groups in settings["hooks"].items()
                 for group in groups for hook in group["hooks"]
                 if "moshi" in hook.get("command", "")]
        self.assertEqual(len(hooks), 10)
        for event, hook in hooks:
            self.assertEqual(hook["command"], COMMAND)
            self.assertEqual(hook["async"], event != "PermissionRequest")
        config = tomllib.loads((ROOT / "mise/config.toml").read_text())
        mapping = config["dotfiles"]["~/.config/moshi/agent-hook.sh"]
        self.assertEqual(mapping, {"source": "../moshi/agent-hook.sh", "mode": "symlink"})
        self.assertNotIn("~/.config/moshi/disabled", config["dotfiles"])
        self.assertNotIn("~/.config/moshi/enabled", config["dotfiles"])


if __name__ == "__main__":
    unittest.main()
