# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## What this repo is

Personal dotfiles managed with GNU Stow. Each top-level directory (`zshrc/`, `tmux/`, `nvim/`, `ghostty/`, `gitconfig/`, `starship/`, `opencode/`, `claude/`, `pi/`, `herdr/`, `hypr/`) is a stow package whose internal layout mirrors `$HOME` (e.g. `nvim/.config/nvim/init.lua` symlinks to `~/.config/nvim/init.lua`).

Because files are symlinked into `$HOME`, edits to files in this repo take effect in the live environment immediately — no install step needed for content changes. Only adding/removing files requires a restow.

## Commands

```bash
# Symlink a package into $HOME (run from repo root)
stow <package>

# Restow after adding/removing files in a package
stow -R <package>

# Dry-run to see what stow would do
stow -n -v <package>

# Install packages only; package manager must already be installed/configured
./packages/install-macos.sh     # macOS (Homebrew)
./packages/install-omarchy.sh   # Arch/Omarchy (omarchy pkg)
./packages/install-ubuntu.sh    # Ubuntu (apt)

# Reload tmux config after editing .tmux.conf
tmux source-file ~/.tmux.conf   # or Prefix+r inside tmux
```

There is no build, lint, or test tooling. Verification means restowing and exercising the affected tool (reload tmux, open a new shell, restart nvim).

## Architecture

- **`packages/`** holds intentionally small package install helpers for macOS, Omarchy, and Ubuntu. They assume the package manager already exists and only install listed packages; they do not stow dotfiles, install curl-based tools, clone repos, or change the login shell.
- **`.stow-local-ignore`** files control what a package symlinks. The `claude/` package uses an ignore-everything-then-whitelist pattern so only `~/.claude/CLAUDE.md` and `~/.claude/settings.json` are managed (runtime state like sessions/cache stays out via `claude/.claude/.gitignore`). `gitconfig/` overrides stow's default ignore of `.gitignore` files.
- **tmux plugins** are managed by tpack, which deliberately lives at `~/.tmux/plugins/tpm` for TPM drop-in compatibility (see `install_tpack`). Plugins are declared with `set -g @plugin` in `.tmux.conf`; the Catppuccin theme is hardcoded in `tmux/.tmux/theme.conf` (not a plugin). Helper scripts (smart splits, pane titles, clipboard that works over SSH) live in `tmux/.tmux/bin/`.
- **nvim** uses lazy.nvim; each plugin gets its own file under `nvim/.config/nvim/lua/plugins/` and is auto-imported. Core config is `lua/options.lua`, `lua/keymaps.lua`, `lua/netrw.lua`.
- **zsh**: `zshrc/.zshrc` defines the user's short helper functions (git shortcuts `ga`/`gc`/`gd`..., `tm` tmux session picker, `cc` = claude, `review`/`reviewed` workflow). `zshrc/.env.zsh` holds environment secrets and is sourced from `.zshrc`. It is untracked, but the ignore rule is indirect: `gitconfig/.gitignore` stows to `~/.gitignore`, which is the global `core.excludesfile` — it does not appear in the repo's own `.gitignore`. Never `git add -f` it.
- **`claude/.claude/settings.json`** wires Claude Code hooks into the `tmux-attention` plugin (`working`/`blocked`/`done` pane states) plus sound alerts — relevant if editing hook or tmux-attention behavior, since the two configs cooperate.
- **`.wt/`** is a gitignored directory holding git worktrees for this repo.

## Conventions

- Vi mode and Catppuccin theming are deliberate constants across all tools (zsh, tmux, nvim, ghostty).
- tmux prefix is `Ctrl+a`; pane navigation is shared with nvim via vim-tmux-navigator, so keybinding changes in one often need a matching change in the other.
