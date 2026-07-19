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
./setup/macos/install.sh
```

### Linux (Arch/Omarchy)

```bash
./setup/omarchy/install.sh
```

### Ubuntu

```bash
./setup/ubuntu/install.sh
```

## Manual Setup

Install GNU Stow, then symlink configs to your home directory:

```bash
# Install stow (macOS)
brew install stow

# Symlink all configs
stow zshrc ghostty tmux nvim starship gitconfig opencode claude
```

## Key Bindings

### Nvim

- **Leader key:** Space
- **Escape:** `kj` (insert mode)

### Tmux

- **Prefix:** `Ctrl+a`
- **Split vertical:** `Prefix+v` (`Prefix+V` splits along the longer edge)
- **Split horizontal:** `Prefix+s` (`Prefix+S` splits along the longer edge)
- **Kill pane:** `Prefix+q`
- **Kill server:** `Prefix+Ctrl+x`
- **Resize:** `Prefix+Ctrl+h/j/k/l`
- **Navigate panes:** `Ctrl+h/j/k/l` (seamless with nvim via vim-tmux-navigator)
- **Reload config:** `Prefix+r`
- **Set pane title:** `Prefix+P` (empty input clears it)
- **Session picker:** `Prefix+a` (Shift+Tab toggles sessions/directories)
- **New session from a directory:** `Prefix+A`
- **Toggle pane attention flag:** `Prefix+h`

Session pickers and the attention flag come from
[tmux-attention](https://github.com/jasonpearson/tmux-attention); its CLI is also
on `$PATH` as `tmux-attention` (`tm` / `tmc` in zsh).

### General

- **Vi mode:** Enabled in zsh, tmux, and nvim

## Theme

Catppuccin (Mocha/Macchiato) everywhere.
