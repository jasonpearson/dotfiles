# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).
Each top-level directory is a stow package whose internal layout mirrors `$HOME`.

## What's Included

| Directory    | Description                                             |
| ------------ | ------------------------------------------------------- |
| `bash/`      | Bash config for Omarchy/Arch and Ubuntu                 |
| `claude/`    | Claude Code AI agent configuration                      |
| `ghostty/`   | Ghostty terminal configuration                          |
| `gitconfig/` | XDG Git config and global ignore                        |
| `herdr/`     | Herdr terminal workspace manager configuration          |
| `hypr/`      | Hyprland/Omarchy user configuration                     |
| `nvim/`      | Neovim config using LazyVim/lazy.nvim                   |
| `opencode/`  | OpenCode AI agent configuration                         |
| `pi/`        | Pi coding-agent settings, keybindings, and extensions   |
| `starship/`  | Starship prompt configuration                           |
| `tmux/`      | Tmux config with tpack plugins and vim-style navigation |
| `zshrc/`     | Portable Zsh config, primarily used on macOS            |

## Package Helpers

These scripts assume the OS package manager is already installed and configured.
They only install packages; they do not clone this repo, stow configs, change the
login shell, or install tools from curl scripts.

```bash
./packages/install-macos.sh     # Homebrew
./packages/install-omarchy.sh   # omarchy pkg / AUR helpers
./packages/install-ubuntu.sh    # apt
```

macOS and Omarchy helpers install `tpack` for tmux plugin management. The tmux
config also starts cleanly when `tpack` is not installed yet.

## Stow Setup

Install GNU Stow, then symlink the package set for the current OS:

```bash
# macOS: all except bash and hypr
stow -R -t "$HOME" zshrc ghostty tmux nvim starship gitconfig opencode claude pi herdr

# Omarchy: all except starship and zshrc
stow -R -t "$HOME" bash ghostty tmux nvim gitconfig opencode claude pi herdr hypr

# Ubuntu: all except hypr, zshrc, and ghostty
stow -R -t "$HOME" bash tmux nvim starship gitconfig opencode claude pi herdr
```

If a package conflicts with an existing real config file, back up or remove the
file before stowing it.

Restow a package after adding or removing files:

```bash
stow -R -t "$HOME" <package>
```

## Key Bindings

### Nvim

- **Leader key:** Space
- **Escape:** `kj` (insert mode)
- **Pane navigation:** `Ctrl+h/j/k/l` crosses nvim, tmux, and Herdr panes
- **Copy path:** `<leader>yp` relative path, `<leader>yP` absolute path
- **Markdown preview:** `<leader>mp`
- **Lazy plugin manager:** `<leader>pl`

### Tmux / Herdr

- **Prefix:** `Ctrl+a`
- **Split vertical:** `Prefix+s` (`Alt+Enter`)
- **Split horizontal:** `Prefix+v` (`Alt+Shift+Enter`)
- **Kill pane:** `Prefix+x` (`Alt+Esc`)
- **Resize:** `Prefix+Ctrl+h/j/k/l`
- **Navigate panes:** `Ctrl+h/j/k/l` (seamless with nvim and Herdr)
- **Reload config:** `Prefix+q`
- **Toggle pane attention flag:** `Prefix+h`

Use shell command `t` to attach to tmux or create a session for the current
working directory, and `tl` to list tmux sessions. The attention flag comes from
[tmux-attention](https://github.com/jasonpearson/tmux-attention); the tmux package
stows a stable `~/.local/bin/tmux-attention` wrapper (`ta` / `tac` in shell
configs) and refreshes the tpack compatibility symlink when tmux reloads.

### General

- **Vi mode:** Enabled in zsh, tmux, and nvim
- **Theme:** Catppuccin/Omarchy-style terminal palette across tools
