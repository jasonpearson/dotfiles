"""Bash title callback behavior without launching an agent."""

import os
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TitleDeploymentTests(unittest.TestCase):
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
