"""Per-key Codex theme deployment tests, using temporary homes only."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "agents/codex/theme.toml"
TARGET = "~/.codex/config.toml/theme"
MISE = shutil.which("mise")


class CodexThemeDeploymentTests(unittest.TestCase):
    def test_theme_fragment_and_mapping_manage_only_the_theme_key(self):
        self.assertEqual(tomllib.loads(SOURCE.read_text()), {"tui": {"theme": "dotfiles"}})
        mapping = tomllib.loads((ROOT / "mise/config.toml").read_text())["dotfiles"][TARGET]
        self.assertTrue(mapping["merge"])
        self.assertEqual((ROOT / "mise" / mapping["source"]).resolve(), SOURCE)

    @unittest.skipUnless(MISE, "requires mise >= 2026.10.4")
    def test_merge_preserves_local_settings_and_is_idempotent(self):
        with tempfile.TemporaryDirectory(prefix="codex theme ") as temp:
            home = Path(temp)
            target = home / ".codex/config.toml"
            target.parent.mkdir()
            original = '''# local model and plugin settings
model = "local-model"
notify = ["computer-use-client", "turn-ended"]

[tui]
# personal terminal preferences
theme = "local-theme"
terminal_title = ["thread-name"]
notifications = ["agent-turn-complete"]
notification_method = "osc9"
alternate_screen = "never"

[plugins.example]
enabled = true
'''
            target.write_text(original)
            config = home / "mise.toml"
            config.write_text(
                '[dotfiles]\n'
                f'{json.dumps(TARGET)} = {{ source = {json.dumps(str(SOURCE))}, merge = true }}\n'
            )
            env = {key: value for key, value in os.environ.items() if not key.startswith("MISE_")}
            env.update(
                HOME=temp,
                XDG_CONFIG_HOME=str(home / ".config"),
                MISE_CONFIG_DIR=str(home / ".config/mise"),
                MISE_GLOBAL_CONFIG_FILE=str(config),
                MISE_TRUSTED_CONFIG_PATHS=temp,
                MISE_DATA_DIR=str(home / "data"),
                MISE_CACHE_DIR=str(home / "cache"),
                MISE_STATE_DIR=str(home / "state"),
            )
            command = [MISE, "-C", temp, "dot", "apply", "--yes", TARGET]

            def apply(*args):
                subprocess.run(
                    [*command, *args], env=env, check=True,
                    text=True, capture_output=True, timeout=30,
                )

            apply("--dry-run")
            self.assertEqual(target.read_text(), original)
            apply()
            expected = tomllib.loads(original)
            expected["tui"]["theme"] = "dotfiles"
            self.assertEqual(tomllib.loads(target.read_text()), expected)
            self.assertIn("# local model and plugin settings", target.read_text())
            self.assertIn("# personal terminal preferences", target.read_text())
            first = target.read_bytes()
            apply()
            self.assertEqual(target.read_bytes(), first)

            # A machine without local Codex configuration gets only the theme key.
            target.unlink()
            apply()
            self.assertEqual(tomllib.loads(target.read_text()), {"tui": {"theme": "dotfiles"}})


if __name__ == "__main__":
    unittest.main()
