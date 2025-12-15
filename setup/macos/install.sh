#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../setup-common.sh"

# Helper: install brew package if command not found
brew_install() {
  local cmd="$1"
  local pkg="${2:-$1}"
  if ! command -v "$cmd" &>/dev/null; then
    echo "Installing $pkg..."
    brew install "$pkg"
  else
    echo "$cmd already installed"
  fi
}

# Helper: install brew cask if not installed
brew_cask_install() {
  local cask="$1"
  if ! brew list --cask "$cask" &>/dev/null; then
    echo "Installing $cask..."
    brew install --cask "$cask"
  else
    echo "$cask already installed"
  fi
}

# Install Homebrew
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew already installed"
fi

# Install packages
brew_install zsh "zsh zsh-autosuggestions"
brew_install zoxide
brew_install starship
brew_install tmux
brew_install fzf
brew_install nvim
brew_install stow
brew_install mise
brew_install opencode
brew_install kind
brew_install fluxcd/tap/flux

# Install cask apps
brew_cask_install ghostty

# Install bun
install_bun

# Install Tmux Plugin Manager
install_tpm

# Install Claude Code
if ! command -v claude &>/dev/null; then
  echo "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
else
  echo "Claude Code already installed"
fi

# Stow dotfiles
stow_dotfiles

# Set zsh as default shell
set_default_shell_zsh

echo "Done!"
