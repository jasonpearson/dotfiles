"""Per-key Codex deployment and Bash prompt tests, using temporary homes only."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TitleDeploymentTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("mise"), "requires mise >= 2026.10.4")
    def test_codex_merge_preserves_local_settings_and_is_idempotent(self):
        mapping = tomllib.loads((ROOT / "mise/config.toml").read_text())["dotfiles"]["~/.codex/config.toml/tmux-title"]
        self.assertTrue(mapping["merge"])
        source = (ROOT / "mise" / mapping["source"]).resolve()
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            target = home / ".codex/config.toml"
            target.parent.mkdir()
            original = '# local comment\nmodel = "local-model"\n\n[tui]\ntheme = "local-theme"\nterminal_title = ["activity"]\n\n[plugins.example]\nenabled = true\n'
            target.write_text(original)
            config = home / "mise.toml"
            config.write_text(f'[dotfiles]\n"~/.codex/config.toml/tmux-title" = {{ source = "{source}", merge = true }}\n')
            env = dict(os.environ, HOME=temp, XDG_CONFIG_HOME=str(home / ".config"),
                       MISE_GLOBAL_CONFIG_FILE=str(config), MISE_TRUSTED_CONFIG_PATHS=temp,
                       MISE_DATA_DIR=str(home / "data"), MISE_CACHE_DIR=str(home / "cache"),
                       MISE_STATE_DIR=str(home / "state"))
            command = [shutil.which("mise"), "-C", temp, "dot", "apply", "--yes", "~/.codex/config.toml/tmux-title"]
            subprocess.run(command, env=env, check=True, text=True, capture_output=True)
            expected = tomllib.loads(original)
            expected["tui"]["terminal_title"] = ["thread-name"]
            self.assertEqual(tomllib.loads(target.read_text()), expected)
            self.assertIn("# local comment", target.read_text())
            first = target.read_bytes()
            subprocess.run(command, env=env, check=True, text=True, capture_output=True)
            self.assertEqual(target.read_bytes(), first)
            # A second machine with no Codex config gets only the portable key.
            target.unlink()
            subprocess.run(command, env=env, check=True, text=True, capture_output=True)
            self.assertEqual(tomllib.loads(target.read_text()), {"tui": {"terminal_title": ["thread-name"]}})

    def test_bash_prompt_hook_preserves_status_and_existing_callbacks(self):
        script = '''
PROMPT_COMMAND='printf old'
source "$TITLE_HOOK"
source "$TITLE_HOOK"
printf 'HOOKS=%s\\n' "${PROMPT_COMMAND[*]}"
(exit 7)
_dotfiles_tmux_prompt_title
printf 'STATUS=%s\\n' "$?"
'''
        result = subprocess.run([shutil.which("bash"), "--noprofile", "--norc", "-ic", script],
                                env=dict(os.environ, TMUX="test", TITLE_HOOK=str(ROOT / "bash/config/tmux.bash")),
                                capture_output=True, check=True)
        self.assertIn(b"HOOKS=printf old _dotfiles_tmux_prompt_title\n", result.stdout)
        self.assertIn(b"\x1b]0;\x07STATUS=7\n", result.stdout)


if __name__ == "__main__":
    unittest.main()
