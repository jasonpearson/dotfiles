# Dotfiles

Personal configuration for macOS and Linux: Bash, Git, Ghostty, tmux, Neovim,
Starship, and coding agents.

[mise](https://mise.jdx.dev/) manages tool versions, system packages, and dotfile
deployment through [`mise/config.toml`](mise/config.toml).

## Setup

Requires mise **2026.10.4 or newer**. Package installation uses Homebrew on macOS
and pacman on Arch Linux.

Install mise using a [method for your platform](https://mise.jdx.dev/installing-mise.html)
and ensure it is on `PATH`. If it is not already installed, the official script
uses `~/.local/bin/mise` by default:

```sh
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
```

Then clone and bootstrap:

```sh
git clone https://github.com/jasonpearson/dotfiles.git "$HOME/repos/dotfiles"
mise -C "$HOME/repos/dotfiles" bootstrap --dry-run
mise -C "$HOME/repos/dotfiles" bootstrap
```

Start a new Bash session afterward. To deploy only configuration, use `dot apply`
in place of `bootstrap`. Review conflicting files before using `--force`.

## Editing configuration

Edit files in this repository. Add tools and deployment mappings in
[`mise/config.toml`](mise/config.toml).

Most files are symlinked; content edits are visible immediately. Run `dot apply`
after adding or renaming files, or to refresh templates and merged settings.
Codex's configuration is merged per key so unrelated local settings stay intact.
The global mise config is rendered with source paths anchored to this checkout,
so deployment commands also work outside the repository. Run `mise dot apply`
after changing tool versions or deployment mappings to refresh that file.

```sh
mise dot status
mise dot apply --dry-run
mise dot apply
```

To deploy one target:

```sh
mise dot apply --dry-run '~/.config/tmux/tmux.conf'
mise dot apply '~/.config/tmux/tmux.conf'
```

Reload the affected application. In tmux, use **Ctrl+A, q**. Machine-specific
Bash settings belong in the untracked `~/.config/bash/local.bash`.

To deploy from any directory, select the checkout explicitly. Shell activation
is optional; mise only needs to be on `PATH`. Use `command -v mise` to check its
location, or invoke your installation's full path if it is not on `PATH`.

```sh
mise -C "$HOME/repos/dotfiles" dot apply
```

To refresh the global mise config directly from the checkout, including when
migrating from its old symlink:

```sh
mise -C "$HOME/repos/dotfiles" dot apply '~/.config/mise/config.toml'
```

## Themes

```sh
mise theme                 # show the saved selection and available presets
mise theme catppuccin
mise theme ethereal
mise theme osaka-jade
```

Themes coordinate Ghostty, Neovim, Bash/Starship, and tmux. The selection and
generated files stay local to each machine; tracked configuration is not rewritten.

Reload Ghostty with **Cmd+Shift+,** on macOS or **Ctrl+Shift+,** on Linux.
Bash/Starship, Neovim, and tmux update automatically after initial setup.
On Omarchy, select themes with `omarchy theme set <name>`.

## Agents and tmux

[`agents/`](agents/) contains Claude Code, Codex, and Pi configuration,
[shared instructions](agents/global-instructions.md), and skills.

[tmux-attention](https://github.com/jasonpearson/tmux-attention) provides pane and
session pickers, agent status, and notifications. Its
[configuration](tmux/tmux-attention-config) uses zoxide for directory discovery.
With the **Ctrl+A** prefix, use **a** for panes, **A** for sessions and directories,
and **O** to jump to the highest-attention pane.

All three agents report pane state through their native lifecycle events.
Claude Code includes questions, plan approval, MCP input, and terminal API
failures. Pi waits until the agent settles, reporting cancellation as idle and
terminal provider errors as failed. Codex uses managed
[hooks](agents/codex/hooks.json) for prompts, permission requests, tool completion,
stop, interrupt, and session end. Its shared background server is disabled so
hooks inherit the invoking terminal's pane environment.

Moshi is optional and is not installed by bootstrap. The agent integrations are supplied by these dotfiles;
do not run `moshi-hook install` for Claude Code, Codex, or Pi. Moshi stays off until you explicitly enable it on that computer:

```sh
mise moshi on      # start/enable the background service and agent hooks
mise moshi off     # revoke hooks and stop/disable the background service
mise moshi status  # show hook preference and actual service state
```

The preference uses local `~/.config/moshi/enabled` or `disabled` markers;
these and pairing data stay out of Git. `DOTFILES_MOSHI_ENABLED` cannot enable it.
`DOTFILES_MOSHI_DISABLED=1` remains an additional hook opt-out and prevents `on`.

The command manages macOS user LaunchAgents and Linux systemd user services.
`on` can configure Moshi's native service if none exists; it never pairs the
computer or installs agent hooks. `off` also disables startup at login because
the daemon's native Codex log watcher operates independently of hooks. A daemon
started manually or as a system service must be stopped separately; the command
reports remaining processes rather than claiming they stopped.

Moshi settings, Claude settings, Codex hooks, and Pi's Moshi extension are deployed
as copies so Moshi cannot rewrite their repository sources. Apply those targets
after editing them. If an external installer replaces the live integrations,
reapply the managed files before enabling Moshi again. Restart Claude Code and
Codex, or `/reload` Pi, after deployment. Keep work computers unpaired.
Moshi phone notifications remain separate from tmux-attention's macOS local sound.
