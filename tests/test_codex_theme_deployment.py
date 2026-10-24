"""Keep the shared Codex theme fragment limited to its intended key."""

from pathlib import Path
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "agents/codex/theme.toml"
TARGET = "~/.codex/config.toml/theme"


class CodexThemeDeploymentTests(unittest.TestCase):
    def test_theme_fragment_and_mapping_manage_only_the_theme_key(self):
        self.assertEqual(tomllib.loads(SOURCE.read_text()), {"tui": {"theme": "dotfiles"}})
        mapping = tomllib.loads((ROOT / "mise/config.toml").read_text())["dotfiles"][TARGET]
        self.assertTrue(mapping["merge"])
        self.assertEqual((ROOT / "mise" / mapping["source"]).resolve(), SOURCE)


if __name__ == "__main__":
    unittest.main()
