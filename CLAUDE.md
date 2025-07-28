# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for macOS/Unix system configuration management. It uses XDG Base Directory specification (`XDG_CONFIG_HOME`) and contains comprehensive development environment configurations.

## Architecture

### Core Configuration Structure

- **`/zsh/`** - Modular ZSH shell configuration with `.zshrc`, `.zshenv`, and setup files for individual tools
- **`/nvim/`** - Neovim configuration using Lazy.nvim plugin manager with Lua-based modular setup
- **`/tmux/`** - Terminal multiplexer configuration with vim-tmux navigation integration
- **`/ghostty/`** - Ghostty terminal emulator configuration
- **`/git/`** - Git configuration and global gitignore patterns
- **`/ai/`** - AI tools configuration including MCP servers
- **`/claude/`** - Claude AI tool data and project configurations

### Key Dependencies

- Git submodules: `pure` (ZSH prompt), `zsh-autosuggestions`, `zsh-z` (directory jumping)
- Homebrew packages listed in `homebrew-formulae.txt`
- Node.js via `fnm`, Python via `uv`, package management via `pnpm`

## Common Commands

### Repository Management

```bash
# Update git submodules (ZSH plugins/themes)
git submodule update --init --recursive --remote
# or use alias:
gsu

# Install/update Homebrew packages
xargs brew install < homebrew-formulae.txt
```

### Development Workflow

```bash
# Edit files containing pattern
eg <pattern>        # Edit files containing search pattern
ef <pattern>        # Edit files matching filename pattern
ed                  # Edit all modified files (git diff --name-only)
ed <filter>         # Edit files with specific git diff filter

# Git shortcuts
gs                  # git status
gd <file>          # git diff
glo                # formatted git log
gac "message"      # git add -A && git commit -m
gaca               # git add -A && git commit --amend --no-edit
```

### Setup Requirements

The repository requires specific symlink setup for core files:

1. `ln -sf ~/.config/tmux/tmux.conf ~/.tmux.conf`
2. `ln -sf ~/.config/zsh/.zshenv ~/.zshenv`
3. `ln -sf ~/.config/.gitconfig ~/.gitconfig`

## Configuration Patterns

### ZSH Setup Files

Each tool has its own `setup-<tool>.zsh` file in `/zsh/` that gets sourced by `.zshrc`. When adding new tool configurations, follow this modular pattern.

### Neovim Plugin Architecture

Plugins are configured individually in `/nvim/lua/plugins/` with lazy loading via Lazy.nvim. Core settings are in `/nvim/lua/options.lua`, `/nvim/lua/keymaps.lua`.

### Sensitive Data Handling

- `zsh/secrets.zsh` for private shell configurations (gitignored)
- `github-copilot/` directory is gitignored
- Global gitignore includes Claude settings and common development artifacts

## Development Tools Integration

- **Search**: Uses `ripgrep` (`rg`) for fast file content search
- **Node.js**: Managed via `fnm` (Fast Node Manager)
- **Python**: Managed via `uv` package manager
- **Package Management**: Uses `pnpm` for Node.js projects
- **Editor**: Neovim with comprehensive LSP, treesitter, and development plugins
- **AI Tools**: Integrated Claude CLI and GitHub Copilot support

