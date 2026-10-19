"""Exercise editor plugin startup offline, without changing installed plugins."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
NVIM = shutil.which("nvim")
PLUGIN_ROOT = Path(os.environ.get(
    "NVIM_PLUGIN_ROOT", os.environ.get(
        "NVIM_THEME_PLUGIN_ROOT",
        str(Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "nvim/lazy"),
    ),
))


@unittest.skipUnless(NVIM, "requires Neovim")
class NeovimPluginTests(unittest.TestCase):
    def run_lua(self, root, source, **extra_env):
        script = root / "test.lua"
        script.write_text(source)
        env = os.environ.copy()
        for name in ("NVIM_APPNAME", "VIMINIT", "EXINIT", "GVIMINIT", "LUA_PATH", "LUA_CPATH"):
            env.pop(name, None)
        env.update(
            HOME=str(root), XDG_CONFIG_HOME=str(root / "config"),
            XDG_DATA_HOME=str(root / "data"), XDG_STATE_HOME=str(root / "state"),
            XDG_CACHE_HOME=str(root / "cache"), REVIEW_REPO=str(REPO),
            REVIEW_PLUGINS=str(PLUGIN_ROOT), **extra_env,
        )
        result = subprocess.run(
            [NVIM, "--headless", "-i", "NONE", "-u", "NONE", "-l", str(script)],
            env=env, capture_output=True, text=True, timeout=20,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(
        (PLUGIN_ROOT / "nvim-treesitter/lua/nvim-treesitter/init.lua").exists(),
        "requires an installed nvim-treesitter main checkout",
    )
    def test_treesitter_highlights_and_indents_before_and_after_parser_install(self):
        with tempfile.TemporaryDirectory(prefix="nvim-plugins-") as tmp:
            root = Path(tmp)
            # A separate language alias lets the real parser become available
            # after startup, without downloading or compiling a parser.
            for language in ("lua", "review_lua"):
                queries = root / "queries" / language
                queries.mkdir(parents=True)
                (queries / "highlights.scm").write_text("(identifier) @variable\n")
                (queries / "indents.scm").write_text(
                    '(if_statement) @indent.begin\n"end" @indent.branch\n'
                )
            self.run_lua(root, r'''
vim.opt.rtp:prepend(vim.env.REVIEW_PLUGINS .. "/nvim-treesitter")
vim.opt.rtp:prepend(vim.env.HOME)
vim.bo.filetype = "review_lua"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "if true then", "return 42", "end" })
local delayed = vim.api.nvim_get_current_buf()
local treesitter = require("nvim-treesitter")
local install, requested = treesitter.install
treesitter.install = function(languages)
  requested = languages
  -- Exercise the real asynchronous task interface without network activity.
  return install({})
end
dofile(vim.env.REVIEW_REPO .. "/nvim/lua/plugins/treesitter.lua").config()
assert(not vim.treesitter.highlighter.active[delayed], "missing parser should be tolerated")
local parser = assert(vim.api.nvim_get_runtime_file("parser/lua.*", false)[1], "Lua parser required")
vim.treesitter.language.add("review_lua", { path = parser, symbol_name = "lua" })
assert(vim.wait(1000, function() return vim.treesitter.highlighter.active[delayed] ~= nil end),
  "the buffer opened before parser installation must become highlighted")
assert(vim.bo[delayed].indentexpr == "v:lua.require'nvim-treesitter'.indentexpr()")
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.cmd("normal! gg=G")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(delayed, 0, -1, false),
  { "if true then", "  return 42", "end" }),
  "Treesitter indentation must work: " .. vim.inspect(vim.api.nvim_buf_get_lines(delayed, 0, -1, false)))
vim.cmd("enew!")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local answer = 42" })
vim.cmd("setfiletype lua")
assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()],
  "new filetypes must activate highlighting")
for _, language in ipairs({ "lua", "typescript", "markdown", "markdown_inline", "yaml" }) do
  assert(vim.list_contains(requested, language), "missing parser provisioning: " .. language)
end
''')

    @unittest.skipUnless(os.name == "posix", "requires a POSIX shell for the npm fixture")
    def test_markdown_preview_build_runs_npm_without_changing_directory(self):
        with tempfile.TemporaryDirectory(prefix="nvim-markdown-build-") as tmp:
            root = Path(tmp)
            plugin = root / "markdown-preview.nvim"
            (plugin / "app").mkdir(parents=True)
            commands = root / "bin"
            commands.mkdir()
            (commands / "npm").write_text(
                '#!/bin/sh\n[ "$#" = 2 ] && [ "$1" = install ] '
                '&& [ "$2" = --omit=dev ] || exit 98\n'
                '[ "$PWD" -ef "$REVIEW_MARKDOWN/app" ] || exit 97\n'
                'if [ "${REVIEW_NPM_FAIL:-0}" = 1 ]; then\n'
                "printf 'fixture npm failure\\n' >&2\nexit 7\nfi\n"
                'mkdir -p node_modules\nprintf installed > node_modules/installed\n'
            )
            (commands / "yarn").write_text("#!/bin/sh\nexit 99\n")
            for command in commands.iterdir():
                command.chmod(0o755)
            self.run_lua(root, r'''
local spec = dofile(vim.env.REVIEW_REPO .. "/nvim/lua/plugins/markdown.lua")[2]
assert(type(spec.build) == "function", "missing build command")
local function build_preserving_cwd(succeeds)
  for _, command in ipairs({ "cd", "tcd", "lcd" }) do
    local directory = vim.env.HOME .. "/" .. command
    vim.fn.mkdir(directory, "p")
    vim.cmd[command](directory)
    local cwd, scope = vim.fn.getcwd(), vim.fn.haslocaldir()
    local ok, err = pcall(spec.build, { dir = vim.env.REVIEW_MARKDOWN })
    assert(ok == succeeds, "unexpected build result")
    if not succeeds then
      assert(tostring(err):find("fixture npm failure", 1, true), "npm errors must propagate")
    end
    assert(vim.fn.getcwd() == cwd and vim.fn.haslocaldir() == scope,
      "the build must preserve editor cwd and directory scope")
  end
end
build_preserving_cwd(true)
assert(vim.fn.filereadable(vim.env.REVIEW_MARKDOWN .. "/app/node_modules/installed") == 1,
  "the npm build must run from the app directory")
vim.env.REVIEW_NPM_FAIL = "1"
build_preserving_cwd(false)
''', REVIEW_MARKDOWN=str(plugin),
                PATH=str(commands) + os.pathsep + os.environ["PATH"])


if __name__ == "__main__":
    unittest.main()
