# Dotfiles

Dotfiles and tool versions are managed by [mise](https://mise.jdx.dev/), with
configuration in [`mise/config.toml`](mise/config.toml).

## New computer setup

Clone this repository to `~/repos/dotfiles` (or adjust the paths below to match
your checkout), then [install mise](https://mise.jdx.dev/getting-started.html#_1-install-mise-cli).
On macOS or Linux, the installer places the executable at `~/.local/bin/mise`:

```sh
curl https://mise.run | sh
```

Run `mise bootstrap` from the repository root, before the global config symlink
or shell activation exists. Mise discovers [`mise/config.toml`](mise/config.toml)
there. This installs the configured system packages and versioned tools, and
applies the dotfiles:

```sh
"$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" bootstrap
```

Append `--dry-run` to preview the changes. `-C` takes the checkout directory, not
the config file path. After bootstrapping, start a new Bash session to load the
managed shell configuration.

To apply only the dotfiles, replace `bootstrap` with `dot apply` in the command
above.

## Everyday use

To add or update agent skills, see [Agent skills](#agent-skills).

With the dotfiles applied and mise available in your shell:

```sh
mise dot status
mise dot apply --dry-run
mise dot apply
```

To reapply just one target, pass its configured path. For example:

```sh
mise dot unapply '~/.agents/skills/hunk-review'
mise dot apply '~/.agents/skills/hunk-review'
```

## tmux-attention preferences

[`tmux/tmux-attention-config`](tmux/tmux-attention-config) is a trusted Bash file,
linked to `~/.config/tmux-attention/config` on macOS and Linux. It keeps the
`pi`/`claude`/`codex` agent commands, `*subagents*` session pattern, zoxide directory
source, and existing picker keys explicit and customizable. Other settings use
tmux-attention's built-in defaults; environment variables override the file.

```sh
mise dot apply --dry-run '~/.config/tmux/tmux.conf' '~/.config/tmux-attention/config'
mise dot apply '~/.config/tmux/tmux.conf' '~/.config/tmux-attention/config'
```

Reopen pickers after editing; no tmux configuration reload is needed. The pinned
`0.3.0` release does not read this file yet. Until a config-aware release is
installed, the existing mise `TMUX_ATTENTION_DIR_COMMAND` setting preserves
zoxide navigation; remove that compatibility setting when upgrading.

## tmux pane focus

The active pane has a **bold, accent-filled pill around its icon and path/title**.
Inactive pane labels are plain muted text, without a pill. Focus therefore differs
by shape and emphasis, not just hue—even when a theme's accent and muted colors
are similar. The same layout works on macOS and Linux with every theme.

This lives in [`tmux/tmux.conf`](tmux/tmux.conf), deployed by its existing mise
mapping. After updating the layout, reload tmux once with prefix + `q` (or
`tmux source-file ~/.config/tmux/tmux.conf`). No panes need restarting, and
subsequent palette changes still update automatically.

## Coding-agent window names

On macOS and Linux, tmux names a window after its focused coding-agent pane.
When a shell or other command is focused, it uses the first agent in pane order;
with no agents, it uses the focused pane's directory basename. Claude, Codex,
Pi, and the existing OpenCode title convention are recognized. Empty agent
names temporarily fall back to that agent's directory. Dead panes are ignored.

- **Claude:** `/rename` (or `--name`) wins over its native generated title.
- **Codex:** `/rename` wins over its native generated title. Only `thread-name`
  is included in the terminal title; activity badges stay separate.
- **Pi:** `/name` wins immediately. Unnamed sessions get a 2–6-word task summary
  after conversation changes, at most once every two minutes. This uses an
  additional request to the current model. Summaries are saved as separate Pi
  extension metadata for resume/reload, never as explicit session names.
  Failed requests retain the previous title, and late results cannot overwrite
  a manual rename or a different session. Print/JSON/RPC runs don't touch titles.

[`tmux/tmux.conf`](tmux/tmux.conf) selects and normalizes pane titles using native
formats and hooks: no daemon, screen scraping, or periodic shell process. Pi
publishes its chosen name in the pane-local `@pi_title` option so Pi's later
native terminal-title writes during startup/resume cannot overwrite it.
[`bash/config/tmux.bash`](bash/config/tmux.bash) clears old agent titles at the
shell prompt, including after crashes and suspended commands. Explicitly
renaming a **tmux window** with prefix + `r` still disables automatic naming for
that window; use `tmux setw automatic-rename on` there to resume it.

Deployment requires **mise >= 2026.10.4** for per-key merging. Upgrade older mise
with `mise self-update --no-plugins 2026.10.4`. The source
[`agents/codex/tmux.toml`](agents/codex/tmux.toml) owns only
`tui.terminal_title`; mise preserves all unrelated local Codex configuration,
comments, plugins, and credentials. The rest of `~/.codex` remains unmanaged.

```sh
mise dot apply --dry-run '~/.config/tmux/tmux.conf' '~/.bashrc' '~/.config/bash' '~/.pi/agent' '~/.claude' '~/.codex/config.toml/tmux-title'
mise dot apply '~/.config/tmux/tmux.conf' '~/.bashrc' '~/.config/bash' '~/.pi/agent' '~/.claude' '~/.codex/config.toml/tmux-title'
```

Reload tmux with prefix + `q`, run `/reload` in existing Pi sessions, restart
Claude/Codex sessions, and open a new Bash shell (or `source ~/.bashrc`).

Tests use private tmux servers, fake agent processes, and mocked model calls:

```sh
python3 -m unittest discover -s tests -p 'test_tmux_naming.py' -v
python3 -m unittest discover -s tests -p 'test_agent_title_deployment.py' -v
node --test tests/pi-tmux-attention.test.mjs
```

The tmux tests require a C compiler for fake agent executables. When Pi is
installed, they also exercise real Pi startup, rename, reload, and summary
resume using named or empty sessions. The mocked Pi tests require Node 24 or
newer. No real model requests are made by the tests.

## Terminal defaults and Pi scrolling

Pi starts in fullscreen mode. Navigate the conversation directly in Pi, without
tmux copy mode or physical PageUp/PageDown keys:

| Keys | Action |
| --- | --- |
| **Ctrl+U / Ctrl+D** | Half-page up/down |
| **Ctrl+B / Ctrl+F** | Full-page up/down |
| **Ctrl+Y / Ctrl+E** | One line up/down |
| **Alt+K / Alt+J** | Previous/next message marker |
| **Ctrl+G / Ctrl+Shift+G** | Beginning/end; end resumes following new output |
| **Ctrl+Shift+E** | Open the input in the external editor |
| **Ctrl+Shift+F** | Search the transcript (Pi's default) |
| **Ctrl+N / Ctrl+Shift+N** | Next/previous match while searching |
| **Enter / Shift+Enter** | Alternate next/previous search match |
| **Escape** | Close transcript search |
| **Ctrl+O** | Collapse/expand tool output |

Bindings live in [`agents/pi/keybindings.json`](agents/pi/keybindings.json),
deployed on Linux and macOS through the existing `~/.pi/agent` mise mapping.
PageUp/PageDown, Home/End, and the default message-jump shortcuts remain available.
Search navigation is scoped to an open search; Ctrl+N still toggles named-only
sessions in the session picker.

The navigation keys no longer double as editor shortcuts: use **Alt+U** to cut
to the start of the input line, **Alt+E** to move to its end, **Alt+Y** to yank,
and **Alt+Shift+Y** to cycle the kill ring. Arrow keys still move the input
cursor; Delete still deletes forward. **Ctrl+D never exits Pi**; use `/quit`
or the existing Ctrl+C exit sequence instead. These are fullscreen-first bindings;
regular mode does not turn those control keys back into editor shortcuts.

**Ctrl+A** is tmux's sole prefix; the secondary Ctrl+B prefix is disabled so
Pi receives full-page-up. Ctrl+H/J/K/L still navigate tmux panes. Ghostty sends
left **Option** as Alt on macOS; right Option remains available for Unicode
characters. Ghostty's own Cmd+U/D shortcuts scroll terminal history, not Pi's
fullscreen transcript. On Linux, [`ghostty/config-linux`](ghostty/config-linux)
unbinds Ghostty's Ctrl+Shift+E split-down and Ctrl+Shift+N new-window shortcuts
so Pi receives them; the other split/window controls remain available.

The former Ctrl+Shift+U/D bindings and `fcitx5/conf/unicode.conf` workaround are
removed. A Linux-only mise `absent` entry removes that previously managed
Unicode-addon override, including stale symlinks, restoring Fcitx5's defaults.
It removes only that file, not other Fcitx preferences, profiles, or caches;
inspect it first if you have since replaced it with unrelated local settings.
The cleanup is skipped on macOS and does not install or require Fcitx5.

To deploy just these changes from the repository root:

```sh
mise dot apply --dry-run '~/.pi/agent' '~/.config/tmux/tmux.conf' '~/.config/ghostty/config' '~/.config/ghostty/config-linux' '~/.config/fcitx5/conf/unicode.conf'
mise dot apply '~/.pi/agent' '~/.config/tmux/tmux.conf' '~/.config/ghostty/config' '~/.config/ghostty/config-linux' '~/.config/fcitx5/conf/unicode.conf'
tmux source-file ~/.config/tmux/tmux.conf
```

Select Pi's `symlink-each` mapping by `~/.pi/agent`, not an individual child path.
Inspect and back up conflicting files before considering `--force`. Run
`/reload` in existing Pi sessions and reload Ghostty's configuration
(**Cmd+Shift+,** on macOS, **Ctrl+Shift+,** on Linux). tmux declares Ghostty's
extended-key support, which preserves Shift in Ctrl+Shift+G/N/E/F. Existing tmux clients need
a detach/re-attach (**Ctrl+A**, then **d**; `tmux attach`) to pick up that terminal
feature. Pi sessions keep running; do not kill the tmux server.

On Linux, if Fcitx5 is running, reload its Unicode addon after removing the override:

```sh
busctl --user call org.fcitx.Fcitx5 /controller \
  org.fcitx.Fcitx.Controller1 ReloadAddonConfig s unicode
```

[`xdg/xdg-terminals.list`](xdg/xdg-terminals.list) independently selects Ghostty
for Linux `xdg-terminal-exec`, including Omarchy's **Super+Return** launcher.
This affects new terminal windows; no Hyprland reload is needed.

`tests/test_pi_navigation.py` checks the bindings in a real Pi TUI on a private
tmux server and exercises deployment cleanup in a temporary home. It makes no
model requests.

## Neovim clipboard

[`nvim/init.lua`](nvim/init.lua) initializes
[`remote_clipboard`](nvim/lua/remote_clipboard.lua) before plugins load. macOS uses
`pbcopy`/`pbpaste`; local Wayland uses `wl-copy`/`wl-paste`. Linux tmux, SSH, and
Herdr sessions also send OSC 52 clipboard writes to the attaching terminal.
Without that extra write, Wayland can have the new text while tmux's clipboard
buffer still contains an older copy.

The existing **Space+y** and **Space+Shift+y** normal-mode mappings copy the
current file's relative and absolute paths respectively. Restart Neovim after
changing its clipboard startup configuration. The existing `~/.config/nvim`
mise mapping deploys this on both Linux and macOS; no desktop settings change.

The Linux integration test uses a private tmux server and fake Wayland tools,
without reading or replacing the desktop clipboard or downloading plugins:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_nvim_clipboard.py' -v
```

## Ghostty Linux overrides

[`ghostty/config`](ghostty/config) keeps the shared font size at 15. It optionally
includes [`ghostty/config-linux`](ghostty/config-linux), deployed only on Linux.
Mise maps the two files individually rather than deploying the whole `ghostty/`
directory, keeping the override off macOS.

The Linux size of 11 is tuned for Linux's 96-DPI baseline and this desktop's
1.1818 GTK text scale. It is a starting point, not an automatic DPI adjustment;
edit `ghostty/config-linux` if another desktop needs a different size.
Monitor and desktop-wide text scaling are unchanged. Mise bootstrap installs
BlexMono via Homebrew on macOS and pacman on Arch Linux.

Omarchy's **Super+V** universal paste sends **Shift+Insert** to terminals. The
Linux override maps that chord to `paste_from_clipboard`, matching Neovim's `+`
register and Ghostty's **Ctrl+Shift+V**. This replaces Ghostty's default
**Shift+Insert** behavior of pasting the separate primary selection (`*`).
macOS bindings are unchanged.

```sh
mise dot apply --dry-run '~/.config/ghostty/config' '~/.config/ghostty/config-linux'
mise dot apply '~/.config/ghostty/config' '~/.config/ghostty/config-linux'
```

Reload Ghostty with **Ctrl+Shift+,** on Linux or **Cmd+Shift+,** on macOS.
If a terminal has been manually zoomed, reset its font size with **Ctrl+0** on
Linux or **Cmd+0** on macOS after reloading, or open a fresh window.

## Themes: Omarchy and macOS

### Switch on macOS (or Linux without Omarchy)

One selection now coordinates Ghostty, Neovim, Bash/Starship, and tmux:

```sh
mise theme ethereal
mise theme osaka-jade
mise theme catppuccin       # Catppuccin Mocha, the original default
mise theme                 # show the saved selection and available presets
```

Then reload Ghostty with **Cmd+Shift+,** on macOS (**Ctrl+Shift+,** on Linux).
Bash/Starship update at the next prompt, registered tmux servers refresh
immediately, and Neovim switches automatically within about a second. No app
config editing, Omarchy commands, daemon, or downloads are needed to switch.
On a fresh install, let Neovim's normal Lazy setup install its theme plugins once.

Presets are checked in: [`theme/palette.toml`](theme/palette.toml) preserves the
existing Catppuccin shell colors, and [`theme/ethereal.toml`](theme/ethereal.toml)
bundles native Ethereal's terminal and shell palette. Neovim uses the native
`ethereal.nvim` plugin. [`theme/osaka-jade.toml`](theme/osaka-jade.toml) matches
Omarchy's Osaka Jade terminal palette and shell blends; Neovim uses **Bamboo**,
just as Omarchy does (there is no `osaka-jade` Neovim colorscheme to install).
Fonts, layouts, keybindings, and other settings stay put.

The choice is intentionally **per machine**, saved under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/theme/selection`; switching does not
dirty Git or rewrite config symlinks. It survives restarts and cache cleanup.
A new machine defaults to Catppuccin; run the same command there to select
Ethereal or Osaka Jade. To customize a preset, edit its repository TOML and rerun
the command.

On Omarchy, keep using `omarchy theme set`: its rendered palette takes precedence.
`mise theme <name>` refuses to compete with it. The layouts remain shared.
For manual comparisons, use these commands one at a time on your Omarchy machine:

```sh
omarchy theme set catppuccin
omarchy theme set ethereal
omarchy theme set osaka-jade
```

On macOS, use the corresponding `mise theme <name>` command above and press
**Cmd+Shift+,** in Ghostty after each switch. Check a fresh prompt, tmux's active
pane/status bar, and the same file in Neovim; `:colorscheme` should report
`catppuccin-mocha`, `ethereal`, or `bamboo` respectively.

### Enable after updating the dotfiles

From your **permanent checkout** (not a worktree you plan to delete):

```sh
mise dot apply --dry-run
mise dot apply
```

The mappings deploy `theme/ethereal.toml`, `theme/osaka-jade.toml`, and a small Ghostty include,
[`ghostty/config-theme.tera`](ghostty/config-theme.tera), on both macOS and Linux.
The include is rendered by mise so Ghostty can find the generated palette even
with a custom `XDG_CACHE_HOME`. Reapply `~/.config/ghostty/config-theme` if that
environment variable changes; use the same cache environment when switching.

On Omarchy, reapply the selected theme once so it renders the new user template
and runs the new hook:

```sh
omarchy theme set "$(omarchy theme current)"
```

Off Omarchy, initialize with `mise theme catppuccin`, `mise theme ethereal`,
or `mise theme osaka-jade`.
`mise run theme:apply` regenerates the saved selection without changing it.

Start a new Bash session once to install its pre-prompt callback. For tmux
servers that were already running before these changes, reload the configuration
once with prefix + `q` (or `tmux source-file ~/.config/tmux/tmux.conf`). Restart
Neovim once to load its new adapter; subsequent switches need no restart.
Reload Ghostty once to load its new include. Ordinary Omarchy theme changes still
update all four apps automatically; portable preset changes need only Ghostty's
reload shortcut. Theme reloads do not re-source tmux keybindings/plugins or all
of `.bashrc`.

Use Homebrew Bash (already in the bootstrap packages), not Apple's old `/bin/bash`.
The renderer needs Python 3.11+, provided by the mise Python pin.

### If tmux stays blue while the prompt changes

A long-running server may still have the old configuration loaded: its palette
options update, but its border/status formats read stale environment colors.
Reload once **inside each affected server**, without restarting any panes:

```sh
tmux source-file ~/.config/tmux/tmux.conf
```

Theme switching now warns when it detects those legacy formats and prints a
socket-specific reload command. It does not automatically re-source keybindings,
plugins, or layouts. If the warning persists after reloading, check for old
session/window-local style overrides that shadow the managed global settings.
To inspect the effective colors in the current pane:

```sh
tmux display-message -p 'accent=#{@theme_accent} border=#{E:pane-active-border-style} status=#{E:status-style}'
```

### How it works

- [`omarchy/themed/dotfiles-palette.toml.tpl`](omarchy/themed/dotfiles-palette.toml.tpl)
  maps Omarchy's semantic colors to the shared roles, including blended prompt
  segments and a softer tmux status background. It works with light and dark
  themes and is deployed only on Linux.
- [`theme/apply.py`](theme/apply.py) validates the palette and combines it with
  the single Starship layout in [`starship/starship.toml`](starship/starship.toml).
  It validates the preset, including terminal colors and the Neovim selector,
  before publishing generated files under `${XDG_CACHE_HOME:-~/.cache}/dotfiles/theme/`.
  Only explicit `mise theme <name>` also writes the selection state; managed config
  symlinks are never written. Ghostty includes its generated fragment before the
  Omarchy override; Neovim watches the generated JSON when Omarchy is absent.
  Input paths match mise's explicit `~/.config/` destinations, even if
  `XDG_CONFIG_HOME` differs. Bash exports `STARSHIP_CONFIG` to the generated file.
  Bare Starship invocations outside managed Bash have an ANSI safety palette.
- Interactive Bash initialization renders the palette; the Omarchy `theme-set.d` hook renders
  it again on changes. The Bash prompt callback itself uses only shell builtins
  to read the generated colors and rebind Readline's vi arrows.
- tmux uses user options, not inherited color environment variables. Each server
  registers its socket at configuration load, so named servers are updated too.
  Only servers running this config on this machine participate; remote SSH hosts
  keep their own theme. The default server is also checked without starting one.
- Invalid generated palettes leave the last working files untouched. A transient
  missing Omarchy file retains the previous palette rather than flashing back to
  the manual theme. If deliberately removing Omarchy integration, use
  `python3 ~/.config/dotfiles/theme/apply.py --manual` to reset that cached choice.
  `--manual` is a one-time override; a later Omarchy hook selects Omarchy again.
- Neovim consumes the selected theme's plugin options/colorscheme without
  importing the LazyVim distribution. One intentional preference lives in
  [`nvim/lua/config/theme.lua`](nvim/lua/config/theme.lua): when Omarchy selects
  Ethereal using a generated Aether palette, Neovim loads native `ethereal.nvim`
  instead, matching `:colorscheme ethereal`. Explicit native theme specs and
  other Omarchy themes are unchanged. The adapter reads `current/theme.name`
  along with the generated files; it never rewrites `~/.local/state/omarchy`.
  It detects theme-name changes, directory replacement, and same-colorscheme
  palette changes, retaining the last good theme on read errors. The existing
  `~/.config/nvim` mise mapping deploys this preference; restart Neovim once to
  load the updated adapter. No Omarchy theme reapplication is needed for this
  preference. Off Omarchy, the adapter follows the saved portable preset, with
  Catppuccin Mocha as its safe default before the first render.

### Theme tests

Tests use temporary homes, caches, and tmux sockets; they do not apply dotfiles or
switch the desktop theme:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_theme.py' -v
tests/nvim-theme.sh
tests/nvim-theme.sh --integration
```

Neovim tests use an existing local lazy.nvim checkout and do not download plugins.
They cover saved presets at startup, switching among all three presets in an
existing instance, matching portable/Omarchy Osaka Jade highlights, native
Ethereal on Omarchy, name-only updates, and matching manual Ethereal highlights. `--integration` additionally exercises
installed theme plugins; set
`LAZY_NVIM_PATH` / `NVIM_THEME_PLUGIN_ROOT` if they live outside the usual Neovim
lazy data directory.

Installed tmux/Starship enable their integration tests. Tmux tests check resolved
border labels and status styles through preset changes, plus the warning and
one-time reload for a pre-switcher server—not just the stored palette values.
Installed Ghostty enables
an effective-config check for all three presets and Omarchy precedence. Installed
Omarchy enables real template-rendering tests for three dark palettes and one light
palette, including a comparison of Osaka Jade's portable and rendered shell colors. Preset switching and installed theme plugins are also tested on macOS.

## Personal agent instructions

[`agents/global-instructions.md`](agents/global-instructions.md) is the shared
personal policy, including host-specific browser tool selection. Mise links it to
`~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, and `~/.pi/agent/AGENTS.md`.
Edit that one source rather than maintaining separate host copies. Its neutral
filename avoids making it nested repository instructions under `agents/`;
root `AGENTS.md` remains specific to this repository.

## Agent skills

Run the commands below from the dotfiles repository root. CLI imports live in
Git-ignored `.agents/skills/`, separate from the curated skills deployed by mise
from `agents/`. The root `skills-lock.json` records local import metadata and is
also Git-ignored.

Some agents may discover `.agents/skills/` while working in this repository even
though it is Git-ignored; importing a skill can make it available locally before
you choose to deploy it globally.

### Add or update a skill

1. Ensure the Skills CLI is installed:

   ```sh
   mise install npm:skills
   ```

2. Import a skill. For example:

   ```sh
   skills add mattpocock/skills --skill tdd --agent universal --yes
   ```

   This downloads it into `.agents/skills/` and updates `skills-lock.json`. Run
   the same command to refresh it later. Use `--agent universal` and omit
   `--global` to keep imports here; prefer repeating `skills add` for updates
   because `skills update` automatically selects agent destinations.

3. Copy the skill folder you want to keep into one of these directories:

   - `agents/skills/` — shared by Codex, Claude, and Pi.
   - `agents/pi/skills/` — Pi only.

   For example:

   ```sh
   cp -R .agents/skills/tdd agents/skills/
   ```

   When updating, save local customizations and remove the old destination folder
   before copying; reapply them afterward.

4. For a new shared skill, add two entries to [mise/config.toml](mise/config.toml):

   ```toml
   "~/.agents/skills/tdd" = { source = "../agents/skills/tdd", mode = "symlink" }
   "~/.claude/skills/tdd" = { source = "../agents/skills/tdd", mode = "symlink" }
   ```

   These source paths are relative to `mise/config.toml`, not the shell's working
   directory. Pi-only skills already use the `~/.pi/agent` mapping. Pin any
   required CLIs in the same config, then run `mise dot apply` and reload your
   agent.

Review `git diff` and `git status`, then commit the chosen skills and mise changes.

### Customizations and local skills

`agent-browser`, `playwright-cli`, and `web-search` are automatically discoverable
in Pi and explicit-invocation-only in Codex and Claude. Browser preferences live
in the [personal instructions](agents/global-instructions.md); `web-search` keeps
its existing built-in-first search/text retrieval policy.

When updating imported skills, preserve the curated descriptions and policy
references, direct use of mise-pinned CLIs, and task-owned session cleanup. Keep
each skill's `agents/openai.yaml` policy file and `skillOverrides` in
[Claude settings](agents/claude/settings.json). Leave `disable-model-invocation`
unset in these shared skills so Pi can discover them.

`playwright-cli` is imported from `microsoft/playwright-cli`. Its references cover
browser engineering and Playwright test workflows. The global `@playwright/cli`
pin is separate from each project's Playwright test-runner dependency; CLI debug
features require a compatible project version. Install the pinned CLI with
`mise install npm:@playwright/cli` before using it.

`web-search` is a local skill backed by [DDGS](https://github.com/deedy5/ddgs).
Update its instructions directly and keep the DDGS version pinned in mise.

`recommit` is a local, explicit-invocation-only shared skill for reorganizing a
finished branch in place. See its [workflow](agents/skills/recommit/SKILL.md).
Update it directly; it is not a CLI import.

## Recover after unapplying everything

`mise dot unapply` removes the managed links, including shell startup files and
`~/.config/mise/config.toml`. It leaves the repository's source files and the
installed mise executable at `~/.local/bin/mise` in place.

To restore just the links, use the existing checkout and mise installation:

```sh
"$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" dot apply
```

Then start a new Bash session to load the managed shell configuration.

For a deliberate full unapply/reapply cycle, run that same command with
`dot unapply` first, then run it again with `dot apply`.

Verified with mise 2026.9.12 using status and apply/unapply dry runs with
`PATH=/usr/bin:/bin` and an empty `MISE_CONFIG_DIR`.

See mise's documentation for
[`mise bootstrap`](https://mise.jdx.dev/bootstrap.html) and
[dotfiles management](https://mise.jdx.dev/dotfiles.html).
