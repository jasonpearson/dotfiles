"""Portable Codex hook deployment and command tests; no agents or notifications."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "agents/codex/attention.toml"
HOOK_SOURCE = ROOT / "agents/codex/hooks.json"
STATES = {
    "SessionStart": "idle",
    "UserPromptSubmit": "working",
    "PermissionRequest": "blocked",
    "PostToolUse": "working",
    "Stop": "done",
    "Interrupt": "idle",
    "SessionEnd": "clear",
}


class CodexAttentionTests(unittest.TestCase):
    def setUp(self):
        self.config = tomllib.loads(SOURCE.read_text())
        self.all_hooks = json.loads(HOOK_SOURCE.read_text())["hooks"]
        # Installers may append their own hooks. Select attention by content,
        # never by array position, so a raw Moshi helper cannot be executed here.
        self.hooks = {}
        for event, groups in self.all_hooks.items():
            selected = []
            for group in groups:
                handlers = [hook for hook in group["hooks"]
                            if "tmux-attention" in hook.get("command", "")]
                if handlers:
                    selected.append({**group, "hooks": handlers})
            self.hooks[event] = selected

    def attention_command(self, event):
        group, = self.hooks[event]
        handler, = group["hooks"]
        expected = f"mise exec -- tmux-attention {STATES[event]} >/dev/null 2>&1 || :"
        # Validate the entire command before any subprocess can execute it.
        self.assertEqual(handler["command"], expected)
        return expected

    def test_local_server_and_hooks_are_enabled(self):
        self.assertEqual(self.config, {"features": {"hooks": True, "daemon_auto_start": False}})

    def test_moshi_keeps_its_existing_events_and_precedes_attention(self):
        moshi_events = {"PermissionRequest", "SessionStart", "UserPromptSubmit", "Stop"}
        for event, groups in self.all_hooks.items():
            with self.subTest(event=event):
                if event in moshi_events:
                    self.assertEqual(len(groups), 2)
                    handler, = groups[0]["hooks"]
                    self.assertEqual(handler, {
                        "type": "command",
                        "command": 'sh "$HOME/.config/moshi/agent-hook.sh" codex-hook',
                    })
                    self.assertNotIn("matcher", groups[0])
                else:
                    self.assertEqual(len(groups), 1)

    def test_state_lifecycle_and_synchronous_timeouts(self):
        self.assertEqual(set(self.hooks), set(STATES))
        for event, state in STATES.items():
            with self.subTest(event=event):
                group, = self.hooks[event]
                handler, = group["hooks"]
                self.assertEqual(handler["type"], "command")
                self.attention_command(event)
                self.assertFalse(handler.get("async", False))
                self.assertGreater(handler["timeout"], 0)
                self.assertLessEqual(handler["timeout"], 3)

    def test_compaction_preserves_active_work(self):
        matcher = self.hooks["SessionStart"][0]["matcher"]
        for source in ("startup", "resume", "clear", "fork"):
            self.assertIsNotNone(re.search(matcher, source), source)
        self.assertIsNone(re.search(matcher, "compact"))

    def test_commands_are_silent_and_fail_open(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            fake_mise = home / "mise"
            fake_mise.write_text(
                '#!/bin/sh\n'
                'printf "%s\\n" "$*" >> "$ATTENTION_TEST_LOG"\n'
                'printf "unexpected stdout\\n"\n'
                'printf "unexpected stderr\\n" >&2\n'
                'exit "${ATTENTION_TEST_EXIT:-0}"\n'
            )
            fake_mise.chmod(0o755)
            log = home / "calls"
            for exit_code in (0, 17):
                for event, state in STATES.items():
                    with self.subTest(event=event, exit_code=exit_code):
                        command = self.attention_command(event)
                        result = subprocess.run(
                            ["/bin/sh", "-c", command],
                            input=json.dumps({"hook_event_name": event}),
                            env=dict(os.environ, PATH=str(home),
                                     ATTENTION_TEST_LOG=str(log),
                                     ATTENTION_TEST_EXIT=str(exit_code)),
                            capture_output=True, text=True, timeout=5,
                        )
                        self.assertEqual(result.returncode, 0)
                        self.assertEqual(result.stdout, "")
                        self.assertEqual(result.stderr, "")
                        self.assertEqual(log.read_text().splitlines()[-1],
                                         f"exec -- tmux-attention {state}")
            # A missing mise must be equally harmless.
            result = subprocess.run(
                ["/bin/sh", "-c", self.attention_command("Stop")],
                env=dict(os.environ, PATH=str(home / "missing")),
                capture_output=True, text=True, timeout=5,
            )
            self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))


if __name__ == "__main__":
    unittest.main()
