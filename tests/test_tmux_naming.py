"""Naming integration tests: private servers and fake agents, never paid calls."""

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
TMUX = shutil.which("tmux")


@unittest.skipUnless(TMUX and shutil.which("cc"), "requires tmux and a C compiler for fake agents")
class WindowNamingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-names-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name).resolve()
        self.socket = self.home / "private socket"
        self.env = dict(os.environ, HOME=str(self.home), TMUX_TMPDIR=str(self.home))
        self.env.pop("TMUX", None)
        self.env.pop("TMUX_PANE", None)
        self.env.pop("PI_SESSION_ID", None)
        self.env.pop("PI_SESSION_FILE", None)
        config = self.home / ".config/tmux"
        config.mkdir(parents=True)
        # Parse the real config without unrelated shell/theme/plugin startup.
        text = (ROOT / "tmux/tmux.conf").read_text().split("# Other plugins still use tpack", 1)[0]
        self.conf = config / "tmux.conf"
        self.conf.write_text("\n".join(line for line in text.splitlines() if not line.startswith("run-shell ")))
        self.cwd = self.home / "project with spaces"
        self.cwd.mkdir()
        self.bin = self.home / "bin"
        self.bin.mkdir()
        # A local executable gives tmux real foreground process names on both
        # Linux and macOS, without launching agents. Copying Apple's platform
        # binaries invalidates their signatures; symlinks keep the name sleep.
        fake = self.bin / "fake"
        subprocess.run(["cc", "-x", "c", "-o", str(fake), "-"],
                       input=('#include <stdio.h>\n#include <string.h>\n'
                              'int main(void) { char s[4096]; while (fgets(s, sizeof(s), stdin)) { '
                              's[strcspn(s, "\\r\\n")] = 0; printf("\\033]0;%s\\007", s); fflush(stdout); } }\n'),
                       text=True, check=True, capture_output=True)
        for command in ("pi", "claude", "codex", "opencode", "nvim", "node"):
            shutil.copy(fake, self.bin / command)
        self.addCleanup(lambda: subprocess.run(
            [TMUX, "-S", str(self.socket), "kill-server"], env=self.env, capture_output=True))
        self.tm("-f", str(self.conf), "new-session", "-d", "-s", "test", "-c", str(self.cwd), "sleep 300")
        self.window, self.shell = self.tm("display-message", "-p", "#{window_id} #{pane_id}").split()

    def tm(self, *args):
        return subprocess.run([TMUX, "-S", str(self.socket), *args], env=self.env,
                              capture_output=True, text=True, check=True, timeout=10).stdout.strip()

    def wait_for(self, expected, function):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            actual = function()
            if actual == expected:
                return
            time.sleep(0.1)
        self.assertEqual(actual, expected)

    def agent(self, command, title):
        pane = self.tm("split-window", "-d", "-t", self.window, "-c", str(self.cwd), "-P", "-F", "#{pane_id}",
                       str(self.bin / command), "300")
        self.wait_for(command, lambda: self.tm("display-message", "-p", "-t", pane, "#{pane_current_command}"))
        self.set_title(pane, title)
        return pane

    def set_title(self, pane, title):
        # Actual OSC title traffic: select-pane -T itself expands tmux formats
        # and doesn't exercise the terminal-input notification path.
        self.tm("send-keys", "-t", pane, "-l", "--", title)
        self.tm("send-keys", "-t", pane, "Enter")
        # tmux itself neutralizes command substitutions in OSC titles.
        expected = title.replace("#(", "_(")
        self.wait_for(expected, lambda: self.tm("display-message", "-p", "-t", pane, "#{pane_title}"))

    def resolved(self):
        return self.tm("display-message", "-p", "-t", self.window, "#{E:automatic-rename-format}")

    def assert_name(self, name):
        self.assertEqual(self.resolved(), name)
        # Exercise actual automatic renaming too, not only format expansion.
        self.wait_for(name, lambda: self.tm("display-message", "-p", "-t", self.window, "#{window_name}"))

    def test_directory_and_non_agent_commands_ignore_stale_titles(self):
        self.tm("select-pane", "-t", self.shell, "-T", "π Old task")
        self.assert_name(self.cwd.name)
        for command in ("nvim", "node"):
            pane = self.agent(command, "arbitrary application title")
            self.tm("select-pane", "-t", pane)
            self.assert_name(self.cwd.name)
            self.tm("kill-pane", "-t", pane)

    def test_agent_normalization_rename_and_return_to_shell(self):
        for command, raw, title in [
            ("pi", "π Generated task", "Generated task"),
            ("claude", "✳ Generated task", "Generated task"),
            ("claude", "◐ Generated task", "Generated task"),
            ("claude", "◑ Generated task", "Generated task"),
            ("claude", "Undecorated manual title", "Undecorated manual title"),
            ("codex", "Generated task", "Generated task"),
            ("opencode", "○ - Existing convention", "Existing convention"),
        ]:
            with self.subTest(command=command, raw=raw):
                pane = self.agent(command, raw)
                self.tm("select-pane", "-t", pane)
                self.assert_name(title)
                manual = "- Manual /Users/someone/path"
                prefix = {"pi": "π ", "claude": "✳ ", "opencode": "○ "}.get(command, "")
                if command == "pi":
                    self.tm("set-option", "-p", "-t", pane, "@pi_title", manual)
                self.set_title(pane, prefix + manual)
                expected = manual if command != "opencode" else "Manual /Users/someone/path"
                self.assert_name(expected)
                self.tm("kill-pane", "-t", pane)
                self.assert_name(self.cwd.name)

    def test_split_selection_and_empty_title(self):
        first = self.agent("pi", "π First agent")
        second = self.agent("codex", "Second agent")
        self.tm("select-pane", "-t", second)
        self.assert_name("Second agent")
        self.tm("select-pane", "-t", first)
        self.assert_name("First agent")
        self.tm("select-pane", "-t", self.shell)
        self.assert_name("First agent")
        self.set_title(first, "π Renamed while in background")
        self.assert_name("Renamed while in background")
        self.set_title(first, "")
        self.assert_name(self.cwd.name)  # chosen agent has no title yet
        self.tm("kill-pane", "-t", first)
        self.assert_name("Second agent")
        self.tm("kill-pane", "-t", second)
        self.assert_name(self.cwd.name)

    def test_titles_are_data_not_shell_or_tmux_formats(self):
        title = "Manual #{window_index} #[fg=red] #(/bin/false) $(false)"
        pane = self.agent("codex", title)
        self.tm("select-pane", "-t", pane)
        expected = title.replace("#(", "_(")
        self.assert_name(expected)
        status = self.tm("display-message", "-p", "-t", pane, "#{E:window-status-current-format}")
        self.assertIn("##{window_index}", status)
        self.assertIn("##[fg=red]", status)
        self.tm("select-pane", "-t", self.shell)
        self.assert_name(expected)  # pane-loop fallback must not expand title text either

    def test_reload_and_other_sessions_keep_their_own_names(self):
        other, pane = self.tm("new-session", "-d", "-s", "other", "-c", str(self.cwd), "-P", "-F",
                              "#{window_id} #{pane_id}", str(self.bin / "pi")).split()
        self.set_title(pane, "π Other session")
        self.assert_name(self.cwd.name)
        self.wait_for("Other session", lambda: self.tm("display-message", "-p", "-t", other, "#{window_name}"))
        # Reproduce a live reload paused by theme initialization before the
        # @pane_* definitions exist. Rearm automatic naming only at the end.
        self.tm("set-option", "-gu", "@pane_window_name")
        reload = self.home / "reload.conf"
        reload.write_text(self.conf.read_text().replace(
            "# ANSI safety colors", "run-shell 'sleep 0.1'\n# ANSI safety colors"))
        self.tm("source-file", str(reload))
        self.assert_name(self.cwd.name)
        self.wait_for("Other session", lambda: self.tm("display-message", "-p", "-t", other, "#{window_name}"))

    def test_dead_agents_are_not_selected(self):
        pane = self.agent("pi", "π Old task")
        self.tm("set-option", "-p", "-t", pane, "remain-on-exit", "on")
        self.tm("send-keys", "-t", pane, "C-c")
        self.wait_for("1", lambda: self.tm("display-message", "-p", "-t", pane, "#{pane_dead}"))
        self.assert_name(self.cwd.name)

    def test_crashed_background_agent_returns_to_directory_at_bash_prompt(self):
        rc = self.home / "test.bashrc"
        rc.write_text(f'PS1="ready> "\nsource {shlex.quote(str(ROOT / "bash/config/tmux.bash"))}\n')
        pane = self.tm("split-window", "-d", "-t", self.window, "-c", str(self.cwd), "-P", "-F", "#{pane_id}",
                       shutil.which("bash"), "--noprofile", "--rcfile", str(rc), "-i")
        self.wait_for("bash", lambda: self.tm("display-message", "-p", "-t", pane, "#{pane_current_command}"))
        self.tm("send-keys", "-t", pane, "-l", str(self.bin / "pi"))
        self.tm("send-keys", "-t", pane, "Enter")
        self.wait_for("pi", lambda: self.tm("display-message", "-p", "-t", pane, "#{pane_current_command}"))
        self.tm("set-option", "-p", "-t", pane, "@pi_title", "Background task")
        self.set_title(pane, "π Background task")
        self.assert_name("Background task")
        self.tm("send-keys", "-t", pane, "C-c")
        self.wait_for("bash", lambda: self.tm("display-message", "-p", "-t", pane, "#{pane_current_command}"))
        self.assert_name(self.cwd.name)
        self.assertEqual(self.tm("display-message", "-p", "-t", pane, "#{pane_title}"), "")
        self.assertEqual(self.tm("display-message", "-p", "-t", pane, "#{@pi_title}"), "")

    @unittest.skipUnless(shutil.which("pi"), "requires Pi for startup regression test")
    def test_real_pi_startup_rename_reload_and_summary_resume_without_model_calls(self):
        # Only our extension is loaded. Named sessions and empty conversation
        # fixtures never request a model completion; only built-in / commands
        # are sent. HOME and session storage belong to this private server.
        command = [shutil.which("pi"), "-ne", "-e", str(ROOT / "agents/pi/extensions/tmux-attention.ts")]
        pane = self.tm("split-window", "-d", "-t", self.window, "-c", str(self.cwd), "-P", "-F", "#{pane_id}",
                       *command, "--no-session", "--name", "Startup manual")
        self.wait_for("Startup manual", lambda: self.tm("display-message", "-p", "-t", pane, "#{@pi_title}"))
        self.wait_for(f"π - Startup manual - {self.cwd.name}",
                      lambda: self.tm("display-message", "-p", "-t", pane, "#{pane_title}"))
        self.assert_name("Startup manual")
        for name in ("- Manual;", "0"):
            text = f"/name {name}"
            if text.endswith(";"):
                text = text[:-1] + "\\;"
            self.tm("send-keys", "-t", pane, "-l", text)
            self.tm("send-keys", "-t", pane, "Enter")
            self.wait_for(name, lambda: self.tm("display-message", "-p", "-t", pane, "#{@pi_title}"))
            self.assert_name(name)
        self.tm("set-option", "-pqu", "-t", pane, "@pi_title")
        self.tm("send-keys", "-t", pane, "-l", "/reload")
        self.tm("send-keys", "-t", pane, "Enter")
        self.wait_for("0", lambda: self.tm("display-message", "-p", "-t", pane, "#{@pi_title}"))
        self.assert_name("0")
        self.tm("kill-pane", "-t", pane)

        session = self.home / "resume.jsonl"
        session.write_text("\n".join(json.dumps(entry) for entry in [
            {"type": "session", "version": 3, "id": str(uuid.uuid4()), "timestamp": "2026-01-01T00:00:00Z", "cwd": str(self.cwd)},
            {"type": "custom", "id": "summary1", "parentId": None, "timestamp": "2026-01-01T00:00:00Z",
             "customType": "tmux-title-summary", "data": {"title": "Saved summary", "hash": "unused", "updatedAt": 0}},
        ]) + "\n")
        pane = self.tm("split-window", "-d", "-t", self.window, "-c", str(self.cwd), "-P", "-F", "#{pane_id}",
                       *command, "--session", str(session))
        self.wait_for("Saved summary", lambda: self.tm("display-message", "-p", "-t", pane, "#{@pi_title}"))
        self.wait_for(f"π - {self.cwd.name}", lambda: self.tm("display-message", "-p", "-t", pane, "#{pane_title}"))
        self.assert_name("Saved summary")

    def test_explicit_tmux_rename_still_disables_auto_rename(self):
        pane = self.agent("pi", "π Task")
        self.tm("rename-window", "-t", self.window, "Pinned tmux name")
        self.set_title(pane, "π New task")
        self.assertEqual(self.tm("show-options", "-wqv", "-t", self.window, "automatic-rename"), "off")
        time.sleep(1)
        self.assertEqual(self.tm("display-message", "-p", "-t", self.window, "#{window_name}"), "Pinned tmux name")


if __name__ == "__main__":
    unittest.main()
