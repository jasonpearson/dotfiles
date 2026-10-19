"""Notification deployment and installed-CLI smoke tests; never play audio."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
CONF = ROOT / "tmux/attention-notifications.conf"
TMUX = shutil.which("tmux")
# Run under `mise exec -- python ...` to test the configured release. An explicit
# binary override remains available for testing a development checkout.
ATTENTION = os.environ.get("TMUX_ATTENTION_TEST_BIN", shutil.which("tmux-attention"))


class NotificationDeploymentTests(unittest.TestCase):
    def test_release_pin_and_config_replace_local_checkout_and_legacy_env(self):
        config = tomllib.loads((ROOT / "mise/config.toml").read_text())
        self.assertRegex(config["tools"]["github:jasonpearson/tmux-attention"],
                         r"^\d+\.\d+\.\d+$")
        self.assertNotIn("TMUX_ATTENTION_DIR_COMMAND", config.get("env", {}))
        self.assertIn("dir_command='zoxide query --list'",
                      (ROOT / "tmux/tmux-attention-config").read_text())

    def test_sound_config_is_mapped_and_sourced(self):
        config = tomllib.loads((ROOT / "mise/config.toml").read_text())
        mapping = config["dotfiles"]["~/.config/tmux/attention-notifications.conf"]
        self.assertEqual(mapping, {"source": "../tmux/attention-notifications.conf", "mode": "symlink"})
        self.assertIn("source-file -q ~/.config/tmux/attention-notifications.conf",
                      (ROOT / "tmux/tmux.conf").read_text())

    def test_shell_config_leaves_sound_playback_to_tmux(self):
        personal = (ROOT / "bash/config/personal.bash").read_text()
        for helper in ("play_sound", "afplay", "paplay", "aplay"):
            self.assertNotIn(helper, personal)

    def test_claude_keeps_state_hooks_without_standalone_audio(self):
        config = json.loads((ROOT / "agents/claude/settings.json").read_text())
        for event, state in [("PermissionRequest", "blocked"), ("Stop", "done")]:
            commands = [hook["command"] for group in config["hooks"][event] for hook in group["hooks"]]
            self.assertTrue(any(command.startswith(f"mise exec -- tmux-attention {state} ") for command in commands))
        for groups in config["hooks"].values():
            for group in groups:
                for hook in group["hooks"]:
                    self.assertNotIn("afplay", hook.get("command", ""))
                    self.assertNotIn("printf '\\a'", hook.get("command", ""))


    def test_claude_state_reporting_failure_cannot_block_the_agent(self):
        config = json.loads((ROOT / "agents/claude/settings.json").read_text())
        commands = {hook["command"] for groups in config["hooks"].values()
                    for group in groups for hook in group["hooks"]
                    if "tmux-attention" in hook.get("command", "")}
        with tempfile.TemporaryDirectory() as temp:
            mise = Path(temp) / "mise"
            mise.write_text('#!/bin/sh\nprintf "unexpected output\\n"\nprintf "unexpected error\\n" >&2\nexit 2\n')
            mise.chmod(0o755)
            for command in commands:
                with self.subTest(command=command):
                    result = subprocess.run(["/bin/sh", "-c", command],
                                            env=dict(os.environ, PATH=temp),
                                            input='{"hook_event_name":"PreToolUse"}',
                                            capture_output=True, text=True, timeout=5)
                    self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))


@unittest.skipUnless(TMUX, "requires tmux")
class NotificationConfigTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="attention-sound-")
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name).resolve()
        self.socket = self.home / "private socket"
        self.env = dict(os.environ, HOME=str(self.home), TMUX_TMPDIR=str(self.home))
        self.env.pop("TMUX", None)
        self.env.pop("TMUX_PANE", None)
        self.addCleanup(lambda: subprocess.run(
            [TMUX, "-S", str(self.socket), "kill-server"], env=self.env, capture_output=True))
        self.tm("-f", "/dev/null", "new-session", "-d", "-s", "sound-test", "sleep 300")
        self.tm("set-option", "-g", "default-shell", "/bin/sh")

    def tm(self, *args):
        return subprocess.run([TMUX, "-S", str(self.socket), *args], env=self.env,
                              capture_output=True, text=True, check=True, timeout=10).stdout.strip()

    def test_native_platform_sound_policy(self):
        # Merely source/read options: no attention event can launch afplay.
        self.tm("source-file", str(CONF))
        supported = (os.uname().sysname == "Darwin" and os.access("/usr/bin/afplay", os.X_OK)
                     and os.access("/System/Library/Sounds/Submarine.aiff", os.R_OK))
        self.assertEqual(self.tm("show-options", "-gv", "@attention_notify"), "always" if supported else "off")
        self.assertEqual(self.tm("show-options", "-gv", "@attention_notify_command"),
                         "/usr/bin/afplay /System/Library/Sounds/Submarine.aiff" if supported else "")

    def test_non_macos_reload_clears_old_sound_settings(self):
        fake_bin = self.home / "bin"
        fake_bin.mkdir()
        uname = fake_bin / "uname"
        uname.write_text("#!/bin/sh\nprintf '%s\\n' Linux\n")
        uname.chmod(0o755)
        self.tm("set-environment", "-g", "PATH", f"{fake_bin}:{os.environ['PATH']}")
        self.tm("set-option", "-g", "@attention_notify", "always")
        self.tm("set-option", "-g", "@attention_notify_command", "old command")
        self.tm("source-file", str(CONF))
        self.assertEqual(self.tm("show-options", "-gv", "@attention_notify"), "off")
        self.assertEqual(self.tm("show-options", "-gv", "@attention_notify_command"), "")

    @unittest.skipUnless(ATTENTION, "requires tmux-attention on PATH or TMUX_ATTENTION_TEST_BIN")
    def test_installed_cli_dispatches_once_and_preserves_command_failure(self):
        log = self.home / "notifications"
        self.tm("source-file", str(CONF))
        # Override BEFORE any state command, even on macOS. No real sound.
        self.tm("set-option", "-g", "@attention_notify_command",
                f"printf '%s\\n' \"$TMUX_ATTENTION_STATE\" >> {shlex.quote(str(log))}")
        self.tm("set-option", "-g", "@attention_notify", "always")
        pane = self.tm("display-message", "-p", "#{pane_id}")
        pid = self.tm("display-message", "-p", "#{pid}")
        env = dict(self.env, TMUX=f"{self.socket},{pid},0", TMUX_PANE=pane)
        for state in ("working", "done", "done"):
            subprocess.run([str(ATTENTION), state], env=env, capture_output=True, check=True, timeout=10)
        result = subprocess.run([str(ATTENTION), "run", "--", "/bin/sh", "-c", "exit 7"],
                                env=env, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 7)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if log.exists() and len(log.read_text().splitlines()) >= 2:
                break
            time.sleep(0.05)
        self.assertTrue(log.exists(), "notification command never ran")
        self.assertEqual(log.read_text().splitlines(), ["done", "failed"])


if __name__ == "__main__":
    unittest.main()
