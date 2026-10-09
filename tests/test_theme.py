"""Isolated theme tests: no live configs, tmux sockets, or desktop switches.

Run: python3 -m unittest discover -s tests -p 'test_theme.py' -v
"""

import concurrent.futures
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ThemeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles theme ")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        # Match mise's real deployment destinations, even when XDG differs.
        self.config = self.home / ".config"
        self.cache = self.home / "cache/dotfiles/theme"
        self.current = self.home / ".local/state/omarchy/current/theme"
        self.current.mkdir(parents=True)
        self.scripts = self.config / "dotfiles/theme"
        shutil.copytree(ROOT / "theme", self.scripts)
        (self.config / "starship.toml").symlink_to(ROOT / "starship/starship.toml")
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / "custom-config"),
                        XDG_CACHE_HOME=str(self.home / "cache"), XDG_STATE_HOME=str(self.home / "state"),
                        TMUX_TMPDIR=str(self.home),
                        STARSHIP_CACHE=str(self.home / "starship-cache"))
        self.env.pop("TMUX", None)
        self.env.pop("STARSHIP_CONFIG", None)
        self.before = (ROOT / "starship/starship.toml").read_bytes()
        self.addCleanup(lambda: self.assertEqual(self.before, (ROOT / "starship/starship.toml").read_bytes()))

    def run_apply(self, *args, check=True):
        return subprocess.run([sys.executable, str(self.scripts / "apply.py"), *args],
                              env=self.env, text=True, capture_output=True, check=check, timeout=15)

    def set_palette(self, accent="#123456", background="#eeeeee", mode="light"):
        text = (self.scripts / "palette.toml").read_text()
        text = text.replace('accent = "#89b4fa"', f'accent = "{accent}"')
        text = text.replace('background = "#1e1e2e"', f'background = "{background}"')
        text = text.replace('mode = "dark"', f'mode = "{mode}"')
        (self.current / "dotfiles-palette.toml").write_text(text)

    def palette(self):
        return tomllib.loads((self.cache / "starship.toml").read_text())["palettes"]["shared"]

    def test_manual_fallback_and_layout_preserved(self):
        self.run_apply("--no-reload")
        expected = tomllib.loads((self.scripts / "palette.toml").read_text())
        self.assertEqual(self.palette()["accent"], expected["accent"])
        self.assertEqual((self.cache / "source").read_text(), "manual\n")
        layout = tomllib.loads((self.config / "starship.toml").read_text())
        actual = tomllib.loads((self.cache / "starship.toml").read_text())
        del layout["palettes"], actual["palettes"]
        self.assertEqual(actual, layout)
        stamp = (self.cache / "colors.sh").stat().st_mtime_ns
        self.run_apply("--no-reload")
        self.assertEqual(stamp, (self.cache / "colors.sh").stat().st_mtime_ns)

    def test_preset_selection_persists_without_editing_sources(self):
        before = {p.name: p.read_bytes() for p in self.scripts.glob("*") if p.is_file()}
        # Status is read-only, even before any render.
        result = self.run_apply("--select")
        self.assertIn("Saved preset: catppuccin", result.stdout)
        self.assertIn("ethereal", result.stdout)
        self.assertIn("osaka-jade", result.stdout)
        self.assertFalse(self.cache.exists())
        state = self.home / "state/dotfiles/theme/selection"
        self.assertFalse(state.exists())
        for name, accent, scheme in [("ethereal", "#7d82d9", "ethereal"),
                                     ("osaka-jade", "#509475", "bamboo"),
                                     ("catppuccin", "#89b4fa", "catppuccin-mocha")]:
            self.run_apply("--select", name, "--no-reload")
            self.assertEqual(state.read_text(), name + "\n")
            self.assertEqual(self.palette()["accent"], accent)
            self.assertEqual(json.loads((self.cache / "neovim.json").read_text())["colorscheme"], scheme)
            self.assertIn(f"Saved preset: {name}", self.run_apply("--select").stdout)
            stamp = (self.cache / "neovim.json").stat().st_mtime_ns
            self.run_apply("--no-reload")
            self.assertEqual(stamp, (self.cache / "neovim.json").stat().st_mtime_ns)
            # Deleting the cache does not lose the saved preference.
            shutil.rmtree(self.cache)
            self.run_apply("--no-reload")
            self.assertEqual(self.palette()["accent"], accent)
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.scripts.glob("*") if p.is_file()})

    def test_bad_selection_or_preset_leaves_previous_outputs_and_preference(self):
        self.run_apply("--select", "catppuccin", "--no-reload")
        before = {p.name: p.read_bytes() for p in self.cache.iterdir() if p.name != ".lock"}
        bad = self.run_apply("--select", "../ethereal", "--no-reload", check=False)
        self.assertNotEqual(bad.returncode, 0)
        ethereal = self.scripts / "ethereal.toml"
        original = ethereal.read_text()
        for text in ["not toml", original.replace('colorscheme = "ethereal"', 'colorscheme = "bad;command"'),
                     original.replace('"#e9bb4f"', '"nope"'), original.replace('mode = "dark"', 'mode = "nope"')]:
            ethereal.write_text(text)
            self.assertNotEqual(self.run_apply("--select", "ethereal", "--no-reload", check=False).returncode, 0)
            self.assertEqual(before, {p.name: p.read_bytes() for p in self.cache.iterdir() if p.name != ".lock"})
            self.assertEqual((self.home / "state/dotfiles/theme/selection").read_text(), "catppuccin\n")

    def test_selector_does_not_override_omarchy(self):
        self.run_apply("--select", "ethereal", "--no-reload")
        self.set_palette()
        for preset in ("catppuccin", "osaka-jade"):
            result = self.run_apply("--select", preset, "--no-reload", check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("omarchy theme set", result.stderr)
        self.assertEqual((self.home / "state/dotfiles/theme/selection").read_text(), "ethereal\n")
        self.run_apply("--no-reload")
        self.assertEqual(self.palette()["accent"], "#123456")
        self.assertEqual(json.loads((self.cache / "neovim.json").read_text()), {"source": "omarchy"})
        self.assertNotIn("palette =", (self.cache / "ghostty.conf").read_text())

    @unittest.skipUnless(shutil.which("ghostty"), "Ghostty not installed")
    def test_ghostty_effective_preset_and_omarchy_precedence(self):
        config = self.config / "ghostty"
        config.mkdir()
        shutil.copy(ROOT / "ghostty/config", config / "config")
        # Equivalent to mise's template output, including a cache path with spaces.
        (config / "config-theme").write_text(f'config-file = ?"{self.cache}/ghostty.conf"\n')
        def effective():
            result = subprocess.run(["ghostty", "+show-config"],
                                    env=dict(self.env, XDG_CONFIG_HOME=str(self.config)),
                                    text=True, capture_output=True, check=True, timeout=15)
            self.assertNotIn("error", result.stderr.lower())
            return result.stdout.lower()
        for preset, background, foreground in [("ethereal", "060b1e", "ffcead"),
                                                ("osaka-jade", "111c18", "c1c497"),
                                                ("catppuccin", "1e1e2e", "cdd6f4")]:
            self.run_apply("--select", preset, "--no-reload")
            actual = effective()
            self.assertIn(f"background = #{background}", actual)
            self.assertIn(f"foreground = #{foreground}", actual)
            self.assertIn("font-size = 15", actual)
            if preset == "osaka-jade":
                self.assertIn("cursor-color = #f7e8b2", actual)
                self.assertIn("selection-background = #32473b", actual)
                self.assertIn("selection-foreground = #f7e8b2", actual)
                self.assertIn("palette = 6=#2dd5b7", actual)
                self.assertIn("palette = 14=#8cd3cb", actual)
        (self.current / "ghostty.conf").write_text("background = #123456\n")
        self.assertIn("background = #123456", effective())

    def test_omarchy_dark_light_and_manual_override(self):
        self.set_palette()
        self.run_apply("--no-reload")
        self.assertEqual(self.palette()["accent"], "#123456")
        self.assertIn("export THEME_BACKGROUND='#eeeeee'", (self.cache / "colors.sh").read_text())
        self.assertIn('set -g @theme_accent "#123456"', (self.cache / "tmux.conf").read_text())
        self.set_palette("#abcdef", "#111111", "dark")
        self.run_apply("--no-reload")
        self.assertEqual(self.palette()["accent"], "#abcdef")
        self.run_apply("--manual", "--no-reload")
        self.assertEqual(self.palette()["accent"], "#89b4fa")

    def test_missing_or_invalid_omarchy_retains_last_good_outputs(self):
        self.set_palette()
        self.run_apply("--no-reload")
        before = {p.name: p.read_bytes() for p in self.cache.iterdir() if p.name != ".lock"}
        for content in [None, 'accent = "#bad"', 'not valid toml', (self.current / "dotfiles-palette.toml").read_text().replace("#123456", '$(touch nope)')]:
            path = self.current / "dotfiles-palette.toml"
            if content is None:
                path.unlink()
            else:
                path.write_text(content)
            result = self.run_apply("--no-reload", check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(before, {p.name: p.read_bytes() for p in self.cache.iterdir() if p.name != ".lock"})

    def test_concurrent_renderers_and_round_trip(self):
        self.set_palette()
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda _: self.run_apply("--no-reload"), range(8)))
        self.assertEqual(self.palette()["accent"], "#123456")
        self.assertFalse(list(self.cache.glob(".theme-*")))
        spec = importlib.util.spec_from_file_location("theme_apply", ROOT / "theme/apply.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        value = {"format": "a\n\"b\"\\c", "key.with.dots": {"array": [True, 42, {"x": "❯"}]}}
        self.assertEqual(tomllib.loads(module.toml_dump(value)), value)

    @unittest.skipUnless(shutil.which("starship"), "starship not installed")
    def test_starship_reads_generated_palette_on_next_invocation(self):
        for color in ("#123456", "#abcdef"):
            self.set_palette(color)
            self.run_apply("--no-reload")
            env = dict(self.env, STARSHIP_CONFIG=str(self.cache / "starship.toml"))
            result = subprocess.run(["starship", "print-config"], env=env, text=True,
                                    capture_output=True, check=True)
            self.assertEqual(tomllib.loads(result.stdout)["palettes"]["shared"]["accent"], color)
            self.assertNotIn("error", result.stderr.lower())

    def test_noninteractive_bash_only_reads_existing_cache(self):
        command = 'source "$TEST_COLORS"; printf "%s" "${THEME_ACCENT:-}"'
        env = dict(self.env, TEST_COLORS=str(ROOT / "bash/config/colors.sh"))
        subprocess.run(["bash", "--noprofile", "--norc", "-c", command],
                       env=env, capture_output=True, text=True, check=True)
        self.assertFalse(self.cache.exists())
        self.set_palette()
        self.run_apply("--no-reload")
        result = subprocess.run(["bash", "--noprofile", "--norc", "-c", command],
                                env=env, capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout, "#123456")

    def test_bash_existing_shell_callback_readline_and_status(self):
        # Start a shell, change its generated file, then invoke its existing
        # callback: no re-source of startup files and no external prompt process.
        script = r'''
source "$TEST_COLORS"
set -o vi
bind 'set show-mode-in-prompt on'
previous() { seen=$?; calls=$((calls + 1)); }
calls=0
starship_precmd_user_func=previous
_dotfiles_theme_install_prompt_hook
_dotfiles_theme_install_prompt_hook
printf "export STARSHIP_PROMPT_ACCENT='#123456'\nexport THEME_ERROR='#abcdef'\n" > "$_dotfiles_theme_cache/colors.sh"
false
_dotfiles_theme_precmd
status=$?
printf 'RESULT %s %s %s %s\n' "$status" "$seen" "$calls" "$STARSHIP_PROMPT_ACCENT"
bind -v | grep 'vi-.*-mode-string'
[[ $STARSHIP_CONFIG == "$_dotfiles_theme_cache/starship.toml" ]] || exit 8
'''
        result = subprocess.run(["bash", "--noprofile", "--norc", "-ic", script],
                                env=dict(self.env, TEST_COLORS=str(ROOT / "bash/config/colors.sh")),
                                capture_output=True, text=True, check=True)
        self.assertIn("RESULT 1 1 1 #123456", result.stdout)
        self.assertIn("38;2;18;52;86m", result.stdout)
        self.assertIn("38;2;171;205;239m", result.stdout)

    @unittest.skipUnless(shutil.which("tmux"), "tmux not installed")
    def test_tmux_startup_named_servers_and_palette_only_reload(self):
        text = (ROOT / "tmux/tmux.conf").read_text()
        # Parse the real config, excluding only tpack's plugin initialization.
        # Bindings are installed, not executed. TMUX_TMPDIR isolates even the
        # default socket, including nested `tmux` commands in run-shell.
        conf = self.home / "tmux.conf"
        conf.write_text(text.split("# Other plugins still use tpack", 1)[0])
        sockets = [self.home / "one", self.home / "two"]
        def tm(socket, *args):
            return subprocess.run(["tmux", "-S", str(socket), *args], env=self.env,
                                  text=True, capture_output=True, check=True, timeout=15).stdout.strip()
        def assert_styles(socket):
            colors = self.palette()
            # Resolve the actual UI formats, not merely their @theme_* inputs.
            # Stale inherited/session environment colors must not win here.
            self.assertEqual(tm(socket, "display-message", "-p", "-t", "probe", "#{E:pane-active-border-style}"),
                             f'fg={colors["accent"]}')
            self.assertEqual(tm(socket, "display-message", "-p", "-t", "probe", "#{E:status-style}"),
                             f'bg={colors["status_background"]},fg={colors["background"]}')
            label = tm(socket, "display-message", "-p", "-t", "probe", "#{E:pane-border-format}")
            self.assertIn(f'#[bg={colors["accent"]}]', label)
            self.assertNotIn("#badbad", label)
            window = tm(socket, "display-message", "-p", "-t", "probe", "#{E:window-status-current-format}")
            self.assertIn(f'fg={colors["git_segment"]},bg={colors["background"]}', window)
            panes = tm(socket, "list-panes", "-t", "probe", "-F", "#{pane_id}").splitlines()
            self.assertEqual(len(panes), 2)
            for focused in panes:
                tm(socket, "select-pane", "-t", focused)
                for pane in panes:
                    label = tm(socket, "display-message", "-p", "-t", pane, "#{E:pane-border-format}")
                    if pane == focused:
                        path = tm(socket, "display-message", "-p", "-t", pane,
                                  "#{=/60/…:#{E:@pane_border_text}}")
                        self.assertIn(f'#[bg={colors["accent"]}]', label)
                        self.assertIn("#[bold]", label)
                        # The entire icon/path label is enclosed, not just the icon.
                        self.assertLess(label.index(""), label.index(path))
                        self.assertLess(label.index(path), label.index(""))
                    else:
                        self.assertIn(f'#[fg={colors["muted"]}]', label)
                        self.assertNotIn("", label)
                        self.assertNotIn("", label)
                        self.assertNotIn("#[bold]", label)
                        self.assertNotIn(f'#[bg={colors["muted"]}]', label)
                        self.assertNotIn(f'#[bg={colors["accent"]}]', label)
        for socket in sockets:
            self.addCleanup(lambda s=socket: subprocess.run(["tmux", "-S", str(s), "kill-server"], env=self.env, capture_output=True))
            tm(socket, "-f", str(conf), "new-session", "-d", "-s", "probe", "sleep 120")
            self.assertEqual(tm(socket, "show-option", "-gqv", "@theme_accent"), "#89b4fa")
            tm(socket, "set", "-g", "status-left", "sentinel-layout")
            tm(socket, "set-environment", "-t", "probe", "THEME_ACCENT", "#badbad")
            tm(socket, "split-window", "-d", "-t", "probe", "sleep 120")
        self.assertEqual(set(json.loads((self.cache / "tmux-sockets.json").read_text())), set(map(str, sockets)))
        for preset, accent in [("ethereal", "#7d82d9"), ("osaka-jade", "#509475"),
                               ("catppuccin", "#89b4fa")]:
            self.run_apply("--select", preset)
            for socket in sockets:
                self.assertEqual(tm(socket, "show-option", "-gqv", "@theme_accent"), accent)
                self.assertEqual(tm(socket, "show-option", "-gqv", "status-left"), "sentinel-layout")
                assert_styles(socket)
        self.set_palette()
        # Real hook, scoped entirely to the fake HOME/cache/socket namespace.
        subprocess.run(["bash", str(ROOT / "omarchy/hooks/theme-set.d/dotfiles-theme.hook"), "stale-name"],
                       env=self.env, check=True, capture_output=True, timeout=15)
        for socket in sockets:
            self.assertEqual(tm(socket, "show-option", "-gqv", "@theme_accent"), "#123456")
            self.assertEqual(tm(socket, "show-option", "-gqv", "status-left"), "sentinel-layout")
            self.assertEqual(tm(socket, "display-message", "-p", "-t", "probe", "#{@theme_accent}"), "#123456")
            assert_styles(socket)

    @unittest.skipUnless(shutil.which("tmux"), "tmux not installed")
    def test_tmux_legacy_styles_warn_until_one_time_config_reload(self):
        # Reproduce an already-running pre-bridge server: new palette options
        # arrive successfully but borders/status still use inherited colors.
        socket = self.home / "legacy socket"
        def tm(*args):
            return subprocess.run(["tmux", "-S", str(socket), *args], env=self.env,
                                  text=True, capture_output=True, check=True, timeout=15).stdout.strip()
        self.addCleanup(lambda: subprocess.run(["tmux", "-S", str(socket), "kill-server"],
                                               env=self.env, capture_output=True))
        tm("-f", "/dev/null", "new-session", "-d", "-s", "probe", "sleep 120")
        tm("set-environment", "-g", "THEME_ACCENT", "#89b4fa")
        tm("set", "-g", "@status_background", "#7c85aa")
        tm("set", "-g", "pane-active-border-style", "fg=#{THEME_ACCENT}")
        tm("set", "-g", "status-style", "bg=#{@status_background}")
        tm("set", "-g", "status-left", "sentinel-layout")
        result = self.run_apply("--select", "osaka-jade", "--tmux-socket", str(socket))
        self.assertIn("legacy color formats", result.stderr)
        self.assertIn("source-file", result.stderr)
        self.assertIn(str(socket), result.stderr)
        self.assertEqual(tm("show-option", "-gqv", "@theme_accent"), "#509475")
        self.assertEqual(tm("display-message", "-p", "#{E:pane-active-border-style}"), "fg=#89b4fa")
        self.assertEqual(tm("show-option", "-gqv", "status-left"), "sentinel-layout")
        # The recommended explicit reload installs the new format references.
        config = self.config / "tmux/tmux.conf"
        config.parent.mkdir(parents=True)
        config.write_text((ROOT / "tmux/tmux.conf").read_text().split("# Other plugins still use tpack", 1)[0])
        tm("source-file", str(config))
        result = self.run_apply("--select", "ethereal")
        self.assertNotIn("legacy color formats", result.stderr)
        self.assertEqual(tm("display-message", "-p", "#{E:pane-active-border-style}"), "fg=#7d82d9")
        self.assertEqual(tm("display-message", "-p", "#{E:status-style}"), "bg=#8f766d,fg=#060b1e")
        # A stale per-window override also gets diagnosed, even in another window.
        tm("new-window", "-d", "-n", "old-style", "sleep 120")
        tm("set", "-w", "-t", "probe:old-style", "pane-active-border-style", "fg=#{THEME_ACCENT}")
        self.assertIn("legacy color formats", self.run_apply("--select", "catppuccin").stderr)

    @unittest.skipUnless(Path("/usr/share/omarchy/bin/omarchy-theme-set-templates").exists(), "Omarchy not installed")
    def test_real_omarchy_templates_without_switching_desktop(self):
        templates = self.home / ".config/omarchy/themed"
        templates.mkdir(parents=True)
        shutil.copy(ROOT / "omarchy/themed/dotfiles-palette.toml.tpl", templates)
        stage = self.current.with_name("next-theme")
        for theme, mode in [("catppuccin", "dark"), ("osaka-jade", "dark"),
                            ("tokyo-night", "dark"), ("catppuccin-latte", "light")]:
            if stage.exists():
                shutil.rmtree(stage)
            stage.mkdir()
            shutil.copy(f"/usr/share/omarchy/themes/{theme}/colors.toml", stage)
            subprocess.run(["/usr/share/omarchy/bin/omarchy-theme-set-templates"],
                           env=dict(self.env, OMARCHY_PATH="/usr/share/omarchy"),
                           check=True, capture_output=True, timeout=15)
            shutil.copy(stage / "dotfiles-palette.toml", self.current)
            self.run_apply("--no-reload")
            rendered = tomllib.loads((stage / "dotfiles-palette.toml").read_text())
            self.assertEqual(rendered["mode"], mode)
            self.assertEqual(self.palette()["accent"], rendered["accent"])
            self.assertNotIn("{{", (self.cache / "starship.toml").read_text())
            if theme == "osaka-jade":
                portable = tomllib.loads((self.scripts / "osaka-jade.toml").read_text())
                self.assertEqual({key: value.lower() for key, value in rendered.items()},
                                 {key: portable[key].lower() for key in rendered})


if __name__ == "__main__":
    unittest.main()
