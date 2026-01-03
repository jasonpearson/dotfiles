# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

| Directory    | Description                                           |
| ------------ | ----------------------------------------------------- |
| `claude/`    | Claude Code AI agent configurations                   |
| `ghostty/`   | Ghostty terminal with Catppuccin Mocha theme          |
| `gitconfig/` | Git aliases and settings                              |
| `nvim/`      | Neovim config with lazy.nvim, LSP, Treesitter, Snacks |
| `opencode/`  | OpenCode AI agent configurations                      |
| `tmux/`      | Tmux with vim-style navigation and Catppuccin theme   |
| `starship/`  | Starship prompt configuration                         |
| `zshrc/`     | Zsh with vi mode, starship prompt, zoxide, mise       |

## Quick Start

### macOS

```bash
cd macos-supplement
./install-all.sh
```

### Linux (Arch/Omarchy)

```bash
cd omarchy-supplement
./install-all.sh
```

## Manual Setup

Install GNU Stow, then symlink configs to your home directory:

```bash
# Install stow (macOS)
brew install stow

# Symlink all configs
stow zshrc ghostty tmux nvim starship gitconfig opencode
```

## Key Bindings

### Nvim

- **Leader key:** Space
- **Escape:** `kj` (insert mode)

### Tmux

- **Prefix:** `Ctrl+a`
- **Split vertical:** `Prefix+v`
- **Split horizontal:** `Prefix+s`
- **Kill pane:** `Prefix+q`
- **Resize:** `Prefix+Ctrl+h/j/k/l`
- **Navigate panes:** `Ctrl+h/j/k/l` (seamless with nvim via vim-tmux-navigator)

### General

- **Vi mode:** Enabled in zsh, tmux, and nvim

## Theme

Catppuccin (Mocha/Macchiato) everywhere.
