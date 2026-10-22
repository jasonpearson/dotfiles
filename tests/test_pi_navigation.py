"""Fullscreen Pi navigation and deployment tests. No model requests or live homes."""

from contextlib import contextmanager
import json
import os
from pathlib import Path
import pty
import re
import shutil
import subprocess
import tempfile
import termios
import threading
import time
import tomllib
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
TMUX = shutil.which("tmux")
PI = shutil.which("pi")
GHOSTTY = shutil.which("ghostty") or "/Applications/Ghostty.app/Contents/MacOS/ghostty"


class NavigationConfigTests(unittest.TestCase):
    def test_custom_navigation_preserves_default_draft_editing(self):
        bindings = json.loads((ROOT / "agents/pi/keybindings.json").read_text())
        self.assertFalse(any(action.startswith(("tui.editor.", "tui.input.")) for action in bindings))
        for action in ("app.editor.external", "tui.altScreen.pageUp", "tui.altScreen.pageDown",
                       "tui.altScreen.previousPrompt", "tui.altScreen.nextPrompt", "tui.altScreen.top"):
            self.assertNotIn(action, bindings)
        for action, keys in {
            "halfPageUp": "ctrl+shift+k", "halfPageDown": "ctrl+shift+j",
            "lineUp": "ctrl+shift+y", "lineDown": "ctrl+shift+e",
            "bottom": ["end", "ctrl+shift+g"],
            "searchNext": ["enter", "ctrl+n"],
            "searchPrevious": ["shift+enter", "ctrl+shift+n"],
        }.items():
            self.assertEqual(bindings[f"tui.altScreen.{action}"], keys)
        self.assertEqual(bindings["app.exit"], [])
        all_keys = {key for keys in bindings.values() for key in ([keys] if isinstance(keys, str) else keys)}
        self.assertNotIn("ctrl+shift+u", all_keys)
        self.assertNotIn("ctrl+shift+d", all_keys)
        self.assertIn("macos-option-as-alt = left", (ROOT / "ghostty/config").read_text())

    @unittest.skipUnless(Path(GHOSTTY).is_file(), "requires Ghostty")
    def test_ghostty_preserves_pi_input_keys(self):
        for linux in (False, True):
            with self.subTest(linux_overrides=linux), tempfile.TemporaryDirectory() as temp:
                config = Path(temp) / ".config/ghostty"
                config.mkdir(parents=True)
                shutil.copy(ROOT / "ghostty/config", config / "config")
                if linux:
                    shutil.copy(ROOT / "ghostty/config-linux", config / "config-linux")
                env = dict(os.environ, HOME=temp, XDG_CONFIG_HOME=str(Path(temp) / ".config"))
                result = subprocess.run([GHOSTTY, "+show-config"], env=env,
                                        capture_output=True, text=True, check=True, timeout=15)
                self.assertNotIn("error", result.stderr.lower())
                # A raw LF mapping loses Shift and triggers tmux's Ctrl+J pane
                # navigation. Let the negotiated keyboard protocol encode Enter.
                self.assertNotRegex(result.stdout, r"(?m)^keybind = (?:ctrl|shift)\+enter=")
                self.assertNotRegex(result.stdout, r"(?m)^keybind = ctrl\+shift\+[jk]=")

    @unittest.skipUnless(Path(GHOSTTY).is_file(), "requires Ghostty")
    def test_linux_ghostty_frees_pi_shortcuts(self):
        mapping = tomllib.loads((ROOT / "mise/config.toml").read_text())["dotfiles"]["~/.config/ghostty/config-linux"]
        self.assertEqual(mapping["variants"], [{"os": "linux"}])
        source = (ROOT / "mise" / mapping["source"]).resolve()
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp) / ".config/ghostty/config"
            config.parent.mkdir(parents=True)
            # Seed Linux defaults explicitly so the test also exercises their
            # removal with a macOS Ghostty build. Never launch a GUI window.
            config.write_text('keybind = ctrl+shift+e=new_split:down\n'
                              'keybind = ctrl+shift+n=new_window\n'
                              f'config-file = "{source}"\n')
            env = dict(os.environ, HOME=temp, XDG_CONFIG_HOME=str(Path(temp) / ".config"))
            result = subprocess.run([GHOSTTY, "+show-config"], env=env,
                                    capture_output=True, text=True, check=True, timeout=15)
            self.assertNotIn("error", result.stderr.lower())
            self.assertNotRegex(result.stdout, r"(?m)^keybind = ctrl\+shift\+[en]=")
            self.assertIn("keybind = shift+insert=paste_from_clipboard", result.stdout)

    def test_linux_fcitx_leaves_unicode_input_at_defaults(self):
        mapping = tomllib.loads((ROOT / "mise/config.toml").read_text())["dotfiles"]["~/.config/fcitx5/conf/unicode.conf"]
        self.assertEqual(mapping, {"mode": "absent", "variants": [{"os": "linux"}]})
        self.assertFalse((ROOT / "fcitx5/conf/unicode.conf").exists())


@unittest.skipUnless(TMUX and PI, "requires tmux and Pi >= 1.0.2")
class PiNavigationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="pi-navigation-")
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name).resolve()
        self.socket = self.home / "tmux.sock"
        agent = self.home / ".pi/agent"
        agent.mkdir(parents=True)
        shutil.copy(ROOT / "agents/pi/keybindings.json", agent / "keybindings.json")
        (agent / "settings.json").write_text(json.dumps({"tuiMode": "fullscreen"}))
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config"),
                        PI_CODING_AGENT_DIR=str(agent), TMUX_TMPDIR=str(self.home),
                        PI_OFFLINE="1", PI_SKIP_VERSION_CHECK="1", PI_TELEMETRY="0")
        for key in ("TMUX", "TMUX_PANE", "PI_SESSION_ID", "PI_SESSION_FILE"):
            self.env.pop(key, None)
        # Use real tmux key and terminal settings, without theme/plugin processes.
        text = (ROOT / "tmux/tmux.conf").read_text().split("# Optional plugins:", 1)[0]
        conf = self.home / "tmux.conf"
        conf.write_text("\n".join(line for line in text.splitlines() if not line.startswith("run-shell ")))
        self.addCleanup(lambda: subprocess.run(
            [TMUX, "-S", str(self.socket), "kill-server"], env=self.env, capture_output=True))
        self.tm("-f", str(conf), "new-session", "-d", "-s", "test", "-x", "100", "-y", "40",
                "-c", str(self.home), "sleep 300")
        session = self.home / "fixture.jsonl"
        entries = [{"type": "session", "version": 3, "id": str(uuid.uuid4()),
                    "timestamp": "2026-01-01T00:00:00Z", "cwd": str(self.home)}]
        parent = None
        for block in range(12):
            messages = [
                {"role": "user", "content": f"PROMPT_{block:02d}", "timestamp": 1},
                {"role": "assistant", "content": [{"type": "text", "text": "\n\n".join(
                    f"ROW_{row:03d}" for row in range(block * 30, (block + 1) * 30))}],
                 "timestamp": 2, "api": "anthropic-messages", "provider": "anthropic",
                 "model": "claude-sonnet-4-5", "stopReason": "stop",
                 "usage": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0,
                           "totalTokens": 0, "cost": {"input": 0, "output": 0,
                                                     "cacheRead": 0, "cacheWrite": 0, "total": 0}}},
            ]
            for message in messages:
                id_ = uuid.uuid4().hex[:8]
                entries.append({"type": "message", "id": id_, "parentId": parent,
                                "timestamp": "2026-01-01T00:00:00Z", "message": message})
                parent = id_
        session.write_text("\n".join(map(json.dumps, entries)) + "\n")
        # No extensions, credentials, project resources, or submitted prompts.
        self.tm("respawn-pane", "-k", "-t", "test:1", PI, "-ne", "--session", str(session))
        self.wait_screen(lambda screen: "ROW_359" in screen)

    def tm(self, *args):
        return subprocess.run([TMUX, "-S", str(self.socket), *args], env=self.env,
                              capture_output=True, text=True, check=True, timeout=10).stdout.strip()

    def screen(self):
        return self.tm("capture-pane", "-p", "-t", "test:1")

    def wait_screen(self, condition):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            screen = self.screen()
            if condition(screen):
                return screen
            time.sleep(0.1)
        self.fail(f"Timed out waiting for Pi screen:\n{screen}")

    @staticmethod
    def rows(screen):
        return [int(row) for row in re.findall(r"ROW_(\d{3})", screen)]

    @contextmanager
    def client_input(self):
        # Unlike send-keys, input through an attached client's PTY passes through
        # tmux's root key table, including Ctrl+J pane navigation. Use a standard
        # terminfo entry and advertise the extended-key support Ghostty provides.
        master, slave = pty.openpty()
        termios.tcsetwinsize(slave, (40, 100))
        client = subprocess.Popen([TMUX, "-S", str(self.socket), "-T", "extkeys", "attach-session", "-t", "test"],
                                  env=dict(self.env, TERM="xterm-256color"),
                                  stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)

        def drain():
            try:
                while os.read(master, 65536):
                    pass
            except OSError:
                pass  # PTY closes when the client detaches.

        reader = threading.Thread(target=drain, daemon=True)
        reader.start()

        def send(data):
            os.write(master, data)
            time.sleep(0.15)
            return self.screen()

        try:
            self.wait_screen(lambda _: self.tm("list-clients", "-F", "#{client_session}") == "test")
            yield send
        finally:
            client.terminate()
            try:
                client.wait(timeout=5)
            except subprocess.TimeoutExpired:
                client.kill()
                client.wait(timeout=5)
            os.close(master)
            reader.join(timeout=1)

    def test_shift_enter_inserts_newlines_without_submitting(self):
        with self.client_input() as send:
            # Raw LF is Ctrl+J: tmux consumes it for pane navigation, not newlines.
            send(b"RAW_ONE\n")
            self.assertIn("RAW_ONERAW_TWO", send(b"RAW_TWO"))
            send(b"\x03")
            # Accept both terminal extended-key encodings; tmux forwards CSI-u
            # to Pi. No Ghostty-specific text mapping is needed.
            for control_enter, shift_enter in [
                (b"\x1b[13;5u", b"\x1b[13;2u"),
                (b"\x1b[27;5;13~", b"\x1b[27;2;13~"),
            ]:
                send(b"INPUT_ONE")
                send(control_enter)  # Intentionally unbound; must not submit.
                screen = send(b"INPUT_TWO")
                self.assertRegex(screen, r"(?m)^INPUT_ONEINPUT_TWO *$")
                send(shift_enter)
                screen = send(b"INPUT_THREE")
                self.assertRegex(screen, r"(?m)^INPUT_ONEINPUT_TWO *\nINPUT_THREE *$")
                send(b"\x03")
            # Plain Enter still executes a built-in command, without a model call.
            send(b"/name Newline regression\r")
            self.assertIn("Newline regression", self.tm("display-message", "-p", "-t", "test:1", "#{pane_title}"))

    def test_shift_jk_scrolls_half_pages_without_changing_tmux_panes(self):
        self.assertEqual(self.tm("show-options", "-gqv", "prefix"), "C-a")
        self.assertEqual(self.tm("show-options", "-gqv", "prefix2"), "None")
        self.assertIn("xterm-ghostty:extkeys", self.tm("show-options", "-g", "terminal-features"))
        pane = self.tm("display-message", "-p", "-t", "test:1", "#{pane_id}")
        lower = self.tm("split-window", "-d", "-v", "-t", pane, "-P", "-F", "#{pane_id}", "sleep", "300")
        with self.client_input() as send:
            send(b"DRAFT_NAVIGATION")
            for previous_key, next_key in [
                (b"\x1b[107;6u", b"\x1b[106;6u"),
                (b"\x1b[27;6;107~", b"\x1b[27;6;106~"),
            ]:
                bottom = send(b"\x1b[103;6u")  # Ctrl+Shift+G
                previous = send(previous_key)
                self.assertLess(self.rows(previous)[0], self.rows(bottom)[0])
                earlier = send(previous_key)
                self.assertNotEqual(earlier, previous)
                returned = send(next_key)
                self.assertEqual(self.rows(returned), self.rows(previous))
                self.assertIn("DRAFT_NAVIGATION", returned)
                self.assertEqual(self.tm("display-message", "-p", "-t", "test:1", "#{pane_id}"), pane)
            # Unshifted Ctrl+J/K still navigate panes rather than reaching Pi.
            send(b"\n")
            self.assertEqual(self.tm("display-message", "-p", "-t", "test:1", "#{pane_id}"), lower)
            send(b"\x0b")
            self.assertEqual(self.tm("display-message", "-p", "-t", "test:1", "#{pane_id}"), pane)


if __name__ == "__main__":
    unittest.main()
