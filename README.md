# Dotfiles

Personal configuration for macOS and Linux: Bash, Ghostty, tmux, Neovim,
Starship, and coding agents.

[mise](https://mise.jdx.dev/) manages tool versions, system packages, and dotfile
links. [`mise/config.toml`](mise/config.toml) is the source of truth.

## Setup

Requires mise **2026.10.4 or newer**. System packages are configured for Homebrew
on macOS and pacman on Arch Linux.

```sh
git clone https://github.com/jasonpearson/dotfiles.git "$HOME/repos/dotfiles"
curl https://mise.run | sh
```

tmux-attention is pinned to the published **0.5.0** release. No local checkout
is required; its managed config supplies directory discovery and picker keys.

Preview, then install packages, tools, and dotfile links:

```sh
"$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" bootstrap --dry-run
"$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" bootstrap
```

Start a new Bash session afterward. To apply only dotfiles, replace `bootstrap`
with `dot apply`. Review conflicting files before using `--force`.

## Everyday use

Edit files in this repository, not their deployed copies. Add new tools and
file mappings in [`mise/config.toml`](mise/config.toml).

```sh
mise dot status
mise dot apply --dry-run
mise dot apply
```

To apply one target:

```sh
mise dot apply --dry-run '~/.config/tmux/tmux.conf'
mise dot apply '~/.config/tmux/tmux.conf'
```

Reload the affected application after changing its configuration.

## Themes

```sh
mise theme                 # show the selection and available presets
mise theme catppuccin
mise theme ethereal
mise theme osaka-jade
```

Themes coordinate Ghostty, Neovim, Bash/Starship, and tmux. Reload Ghostty with
**Cmd+Shift+,** on macOS or **Ctrl+Shift+,** on Linux; the other apps update
automatically after initial setup. The selection stays local to each machine.

On Omarchy, use `omarchy theme set <name>` instead.

## Restore dotfile links

If you unapplied the dotfiles, restore them without relying on shell setup:

```sh
"$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" dot apply
```

Then start a new Bash session.

## Details

- [Shared agent instructions](agents/global-instructions.md)
