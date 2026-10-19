"""Provision Neovim themes offline with real mise and disposable Git checkouts."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
MISE = shutil.which("mise")
GIT = shutil.which("git")
NVIM = shutil.which("nvim")
PLUGIN_ROOT = Path(os.environ.get(
    "NVIM_PLUGIN_ROOT", os.environ.get(
        "NVIM_THEME_PLUGIN_ROOT",
        str(Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "nvim/lazy"),
    ),
))
LAZY = PLUGIN_ROOT / "lazy.nvim"
THEMES = (
    ("aether", "bjarneo/aether.nvim", "v3"),
    ("miasma", "OldJobobo/miasma.nvim", "main"),
)


@unittest.skipUnless(MISE and GIT, "requires mise >= 2026.10.4 and Git")
class NeovimBootstrapTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim bootstrap ")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.home = self.base / "home"
        self.home.mkdir()
        self.project = self.base / "config"
        self.project.mkdir()
        # Discard inherited mise settings and Git configuration so this never
        # reads or writes the caller's bootstrap state or uses a URL rewrite.
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("MISE_", "GIT_"))
        }
        self.env.update(
            HOME=str(self.home),
            XDG_CONFIG_HOME=str(self.home / "config"),
            XDG_DATA_HOME=str(self.home / "custom-data"),
            XDG_CACHE_HOME=str(self.home / "cache"),
            XDG_STATE_HOME=str(self.home / "state"),
            MISE_CONFIG_DIR=str(self.home / "config/mise"),
            MISE_GLOBAL_CONFIG_FILE=str(self.home / "config/mise/config.toml"),
            MISE_DATA_DIR=str(self.home / "mise-data"),
            MISE_CACHE_DIR=str(self.home / "mise-cache"),
            MISE_STATE_DIR=str(self.home / "mise-state"),
            MISE_TRUSTED_CONFIG_PATHS=str(self.base),
            GIT_CONFIG_NOSYSTEM="1",
            GIT_CONFIG_GLOBAL=os.devnull,
        )
        config = tomllib.loads((ROOT / "mise/config.toml").read_text())
        self.themes = []
        bootstrap_config = ["[bootstrap.repos]"]
        for name, repository, branch in THEMES:
            origin = self.base / f"{name} fixture origin"
            origin.mkdir()
            self.git("init", "--quiet", "--initial-branch=main", cwd=origin)
            (origin / "colors").mkdir()
            source = origin / f"colors/{name}.lua"
            source.write_text(
                f'vim.g.colors_name = "{name}"\n'
                'vim.g.bootstrap_fixture = "main"\n'
            )
            self.git("add", ".", cwd=origin)
            self.commit("Default branch", cwd=origin)
            if branch != "main":
                self.git("checkout", "--quiet", "-b", branch, cwd=origin)
                source.write_text(source.read_text().replace('"main"', json.dumps(branch)))
                self.git("add", ".", cwd=origin)
                self.commit(f"{name} {branch}", cwd=origin)
            theme_source = source.read_text()
            expected_head = self.git("rev-parse", "HEAD", cwd=origin).stdout.strip()
            self.git("checkout", "--quiet", "main", cwd=origin)

            target, entry = next(
                (target, entry.copy()) for target, entry in config["bootstrap"]["repos"].items()
                if entry["url"] == f"https://github.com/{repository}.git"
            )
            self.assertTrue(target.startswith("~/"), f"{name} must install within the user's home")
            self.themes.append({
                "name": name,
                "repository": repository,
                "branch": branch,
                "checkout": str(self.home / target[2:]),
                "source": theme_source,
                "head": expected_head,
            })
            # Exercise production targets and options, substituting only offline
            # Git origins. JSON strings are valid TOML basic strings here.
            entry["url"] = origin.as_uri()
            options = ", ".join(f"{key} = {json.dumps(value)}" for key, value in entry.items())
            bootstrap_config.append(f"{json.dumps(target)} = {{ {options} }}")
        (self.project / "mise.toml").write_text("\n".join(bootstrap_config) + "\n")

    def run_command(self, command, *, cwd=None, succeeds=True):
        result = subprocess.run(
            command, cwd=cwd or self.project, env=self.env,
            capture_output=True, text=True, timeout=30,
        )
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def git(self, *args, cwd):
        return self.run_command([GIT, *args], cwd=cwd)

    def commit(self, message, *, cwd):
        self.git(
            "-c", "user.name=Bootstrap Test", "-c", "user.email=bootstrap@example.invalid",
            "commit", "--quiet", "-m", message, cwd=cwd,
        )

    def bootstrap(self, *args, succeeds=True):
        return self.run_command(
            [MISE, "bootstrap", "--only", "repos", "--yes", *args], succeeds=succeeds,
        )

    def test_preview_install_and_reapply_preserve_local_work(self):
        self.bootstrap("--dry-run")
        for theme in self.themes:
            self.assertFalse(Path(theme["checkout"]).exists(), "preview must not clone a theme")

        self.bootstrap()
        for theme in self.themes:
            with self.subTest(theme=theme["name"], phase="installed"):
                checkout = Path(theme["checkout"])
                self.assertEqual((checkout / f"colors/{theme['name']}.lua").read_text(), theme["source"])
                self.assertEqual(self.git("rev-parse", "HEAD", cwd=checkout).stdout.strip(), theme["head"])
                self.assertEqual(self.git("status", "--porcelain", cwd=checkout).stdout, "")

        self.bootstrap()
        for theme in self.themes:
            checkout = Path(theme["checkout"])
            self.assertEqual(self.git("rev-parse", "HEAD", cwd=checkout).stdout.strip(), theme["head"])
            (checkout / f"colors/{theme['name']}.lua").write_text(theme["source"] + "-- Local customization\n")
        result = self.bootstrap(succeeds=False)
        self.assertIn("has local changes", result.stderr)
        self.bootstrap("--skip-dirty")
        for theme in self.themes:
            with self.subTest(theme=theme["name"], phase="dirty"):
                checkout = Path(theme["checkout"])
                self.assertEqual(
                    (checkout / f"colors/{theme['name']}.lua").read_text(),
                    theme["source"] + "-- Local customization\n",
                )
                self.assertEqual(
                    self.git("status", "--porcelain", cwd=checkout).stdout,
                    f" M colors/{theme['name']}.lua\n",
                )

    @unittest.skipUnless(NVIM and (LAZY / "lua/lazy/init.lua").is_file(), "requires Neovim and installed lazy.nvim")
    def test_neovim_uses_mise_checkout_with_default_and_custom_xdg_data_home(self):
        self.bootstrap()
        self.env.update(TEST_REPO=str(ROOT), TEST_LAZY=str(LAZY), TEST_THEMES=json.dumps(self.themes))
        for name in ("NVIM_APPNAME", "VIMINIT", "EXINIT", "GVIMINIT", "LUA_PATH", "LUA_CPATH"):
            self.env.pop(name, None)
        script = self.base / "test.lua"
        script.write_text(r'''
-- Inspect the real inventory while keeping unrelated themes out of this test.
package.loaded["config.theme"] = { specs = function(specs) return specs end }
local themes = vim.json.decode(vim.env.TEST_THEMES)
local specs = {}
for _, theme in ipairs(themes) do
  local theme_spec
  for _, spec in ipairs(dofile(vim.env.TEST_REPO .. "/nvim/lua/plugins/theme.lua")) do
    if spec[1] == theme.repository then theme_spec = spec end
  end
  assert(theme_spec, theme.name .. " must be in the theme inventory")
  assert(theme_spec.dir == theme.checkout, "Neovim and mise must use the same checkout")
  theme.plugin_name = theme_spec.name or theme.repository:match("[^/]+$")
  table.insert(specs, theme_spec)
  -- Omarchy adds another spec for the active theme; its merge must preserve dir.
  table.insert(specs, { theme.repository, name = theme_spec.name, branch = theme_spec.branch })
end
vim.opt.rtp:prepend(vim.env.TEST_LAZY)
vim.opt.loadplugins = true
require("lazy").setup({
  spec = specs,
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  readme = { enabled = false },
  pkg = { enabled = false },
  rocks = { enabled = false },
})
for _, theme in ipairs(themes) do
  local plugin = require("lazy.core.config").plugins[theme.plugin_name]
  assert(plugin.dir == theme.checkout, "merged specs must preserve the mise checkout")
  assert(plugin._.installed and plugin._.is_local,
    "Lazy must use the mise checkout without managing or cleaning it")
  vim.cmd.colorscheme(theme.name)
  assert(vim.g.colors_name == theme.name and vim.g.bootstrap_fixture == theme.branch,
    "the provisioned " .. theme.name .. " colorscheme must load")
end
''')
        for data_home in (None, str(self.home / "custom-data")):
            with self.subTest(xdg_data_home=data_home or "default"):
                self.env.pop("XDG_DATA_HOME", None)
                if data_home:
                    self.env["XDG_DATA_HOME"] = data_home
                self.run_command([NVIM, "--headless", "-i", "NONE", "-u", "NONE", "-l", str(script)])


if __name__ == "__main__":
    unittest.main()
