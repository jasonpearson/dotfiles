# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

## What this repo is

Personal dotfiles managed with GNU Stow. Each top-level directory (`bash/`, `zshrc/`, `tmux/`, `nvim/`, `ghostty/`, `gitconfig/`, `starship/`, `opencode/`, `claude/`, `pi/`, `herdr/`, `hypr/`) is a stow package whose internal layout mirrors `$HOME` (e.g. `nvim/.config/nvim/init.lua` symlinks to `~/.config/nvim/init.lua`).

Because files are symlinked into `$HOME`, edits to files in this repo take effect in the live environment immediately — no install step needed for content changes. Only adding/removing files requires a restow.

## Commands

```bash
# Symlink a package into $HOME (run from repo root)
stow -t "$HOME" <package>

# Restow after adding/removing files in a package
stow -R -t "$HOME" <package>

# Dry-run to see what stow would do
stow -n -v -t "$HOME" <package>

# Install packages only; package manager must already be installed/configured
./packages/install-macos.sh     # macOS (Homebrew)
./packages/install-omarchy.sh   # Arch/Omarchy (omarchy pkg)
./packages/install-ubuntu.sh    # Ubuntu (apt)

# Reload tmux config after editing ~/.config/tmux/tmux.conf
tmux source-file ~/.config/tmux/tmux.conf   # or Prefix+q inside tmux
```

There is no build, lint, or test tooling. Verification means restowing and exercising the affected tool (reload tmux, open a new shell, restart nvim).

## Architecture

- **`packages/`** holds intentionally small package install helpers for macOS, Omarchy, and Ubuntu. They assume the package manager already exists and only install listed packages; they do not stow dotfiles, install curl-based tools, clone repos, or change the login shell. macOS/Omarchy helpers install `tpack` for tmux plugins.
- **`.stow-local-ignore`** files control what a package symlinks. The `claude/` package uses an ignore-everything-then-whitelist pattern so only `~/.claude/CLAUDE.md` and `~/.claude/settings.json` are managed (runtime state like sessions/cache stays out via `claude/.claude/.gitignore`). Git's global ignore is managed as `gitconfig/.config/git/ignore` and referenced by `core.excludesFile`.
- **`bash/`** provides a minimal Bash startup for Omarchy/Arch and Ubuntu. It sources Omarchy's packaged Bash defaults when present, then `~/.config/bash/personal.bash`, then optional untracked `~/.config/bash/local.bash`.
- **tmux** uses the Omarchy-style config path `tmux/.config/tmux/tmux.conf`, stowed to `~/.config/tmux/tmux.conf`. Plugins are declared with TPM-compatible `@plugin` lines but loaded by `tpack`, so tmux starts cleanly before plugins are installed. The tmux package also stows `~/.local/bin/tmux-attention` and `tmux-attention-sync` to resolve tpack's hashed plugin install directories.
- **nvim** uses LazyVim/lazy.nvim; each local plugin override gets its own file under `nvim/.config/nvim/lua/plugins/` and is auto-imported. Core config is `lua/options.lua`, `lua/keymaps.lua`, `lua/autocmds.lua`, `lua/netrw.lua`. Omarchy theme integration and hot reload support live in `lua/plugins/theme.lua`.
- **zsh**: `zshrc/.zshrc` is primarily used on macOS but should remain portable; guard optional tools with `command -v` checks. Keep common aliases/functions aligned with `bash/.config/bash/personal.bash` where practical (`t` for tmux attach-or-new, `tl` for listing tmux sessions, `ta`/`tac` for tmux-attention, `cc`, `oc`, editor helpers, git helpers). `zshrc/.env.zsh` holds environment secrets and is sourced from `.zshrc`; never add it.
- **`claude/.claude/settings.json`** wires Claude Code hooks into the `tmux-attention` plugin (`working`/`blocked`/`done` pane states) plus sound alerts — relevant if editing hook or tmux-attention behavior, since the two configs cooperate.
- **`.wt/`** is a gitignored directory holding git worktrees for this repo.

## Conventions

- Vi mode and a Catppuccin/Omarchy-style terminal palette are deliberate constants across tools.
- tmux prefix is `Ctrl+a`; pane navigation is shared across nvim, tmux, and Herdr via coordinated `Ctrl+h/j/k/l` bindings, so keybinding changes in one often need matching changes in the others.
