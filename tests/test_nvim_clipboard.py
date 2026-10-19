"""Test real Neovim path mappings in isolated tmux, with a fake Wayland clipboard."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


REPO = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
TMUX = shutil.which("tmux")

INIT = r'''
local function finish(result)
  vim.fn.writefile({ vim.json.encode(result) }, vim.env.CLIPBOARD_TEST_RESULT)
  vim.cmd("qa!")
end
local ok, err = xpcall(function()
  -- Exercise the real startup and mappings without loading/downloading plugins.
  package.preload["config.lazy"] = function()
    assert(vim.g.clipboard, "Clipboard setup must run before plugins")
    return {}
  end
  vim.opt.rtp:prepend(vim.env.CLIPBOARD_TEST_REPO .. "/nvim")
  dofile(vim.env.CLIPBOARD_TEST_REPO .. "/nvim/init.lua")
  vim.cmd.cd(vim.env.CLIPBOARD_TEST_PROJECT)
  vim.api.nvim_buf_set_name(0, vim.env.CLIPBOARD_TEST_PROJECT .. "/nested/a file.lua")
  vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function()
    vim.schedule(function()
      vim.api.nvim_feedkeys(" " .. vim.env.CLIPBOARD_TEST_KEY, "mx", false)
      -- Allow async clipboard jobs and terminal output to reach the test server.
      vim.defer_fn(function()
        finish({ provider = vim.fn["provider#clipboard#Executable"](), error = vim.v.errmsg })
      end, 500)
    end)
  end })
end, debug.traceback)
if not ok then finish({ error = err }) end
'''


@unittest.skipUnless(NVIM and TMUX, "requires Neovim and tmux")
@unittest.skipUnless(os.name == "posix" and os.uname().sysname == "Linux", "Linux clipboard integration")
class NeovimClipboardTests(unittest.TestCase):
    def test_path_mappings_update_the_terminal_clipboard(self):
        with tempfile.TemporaryDirectory(prefix="nvim-clipboard-test-") as tmp:
            root = Path(tmp)
            project = root / "project with spaces"
            project.mkdir()
            bin_dir = root / "bin"
            bin_dir.mkdir()
            # Never read or replace the desktop clipboard, even on failure.
            (bin_dir / "wl-copy").write_text('#!/bin/sh\ncat > "$CLIPBOARD_TEST_WAYLAND"\n')
            (bin_dir / "wl-paste").write_text('#!/bin/sh\ncat "$CLIPBOARD_TEST_WAYLAND"\n')
            for path in bin_dir.iterdir():
                path.chmod(0o755)
            init = root / "init.lua"
            init.write_text(INIT)
            env = os.environ.copy()
            for name in (
                "TMUX", "TMUX_PANE", "NVIM", "NVIM_APPNAME", "NVIM_LOG_FILE",
                "VIMINIT", "EXINIT", "GVIMINIT", "SSH_TTY", "SSH_CONNECTION", "HERDR_PANE_ID",
            ):
                env.pop(name, None)
            env.update(
                HOME=str(root), XDG_CONFIG_HOME=str(root / "config"),
                XDG_DATA_HOME=str(root / "data"), XDG_STATE_HOME=str(root / "state"),
                XDG_CACHE_HOME=str(root / "cache"), WAYLAND_DISPLAY="wayland-test",
                PATH=str(bin_dir) + ":" + env["PATH"],
            )
            tmux = [TMUX, "-S", str(root / "tmux.sock"), "-f", "/dev/null"]

            def run(*args, check=True):
                return subprocess.run(
                    tmux + list(args), env=env, capture_output=True, text=True,
                    check=check, timeout=10,
                )

            try:
                run("new-session", "-d", "-s", "clipboard-test", "-x", "100", "-y", "30", "sleep", "120")
                run("set-option", "-s", "set-clipboard", "on")
                for wayland in (True, False):
                    for key in ("y", "Y"):
                        with self.subTest(wayland=wayland, mapping=f"<leader>{key}"):
                            run("delete-buffer", check=False)
                            label = f"wayland-{int(wayland)}-{key}"
                            result = root / (label + ".json")
                            clipboard = root / (label + ".clipboard")
                            child_env = {
                                "CLIPBOARD_TEST_REPO": str(REPO),
                                "CLIPBOARD_TEST_PROJECT": str(project),
                                "CLIPBOARD_TEST_KEY": key,
                                "CLIPBOARD_TEST_RESULT": str(result),
                                "CLIPBOARD_TEST_WAYLAND": str(clipboard),
                            }
                            args = ["new-window", "-d", "-n", label]
                            for name, value in child_env.items():
                                args.extend(["-e", f"{name}={value}"])
                            command = [NVIM, "-i", "NONE", "-u", str(init)]
                            if not wayland:
                                command = ["env", "-u", "WAYLAND_DISPLAY", "-u", "DISPLAY"] + command
                            run(*args, *command)
                            deadline = time.monotonic() + 10
                            while not result.exists() and time.monotonic() < deadline:
                                time.sleep(0.05)
                            self.assertTrue(result.exists(), f"{label}: Neovim did not finish")
                            report = json.loads(result.read_text())
                            self.assertFalse(report.get("error"), report)
                            self.assertEqual(
                                report["provider"],
                                "WaylandClipboard" if wayland else "OmarchyRemoteClipboard",
                            )
                            expected = "nested/a file.lua" if key == "y" else str(project / "nested/a file.lua")
                            if wayland:
                                self.assertEqual(clipboard.read_text().rstrip("\n"), expected)
                            else:
                                self.assertFalse(clipboard.exists())
                            self.assertEqual(run("save-buffer", "-").stdout, expected)
            finally:
                run("kill-server", check=False)


if __name__ == "__main__":
    unittest.main()
