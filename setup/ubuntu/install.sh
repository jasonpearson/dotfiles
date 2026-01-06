#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../setup-common.sh"

# Helper: install apt package if not installed
apt_install() {
  local pkg="$1"
  if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
    echo "Installing $pkg..."
    sudo apt-get install -y "$pkg"
  else
    echo "$pkg already installed"
  fi
}

# Update package lists
echo "Updating package lists..."
sudo apt-get update

# Install core packages
apt_install git
apt_install curl
apt_install wget
apt_install unzip
apt_install build-essential
apt_install zsh
apt_install zsh-autosuggestions
apt_install tmux
apt_install stow
apt_install fzf
apt_install ripgrep

# Install Neovim (latest stable from PPA)
if ! command -v nvim &>/dev/null || [[ $(nvim --version | head -1 | grep -oP '\d+\.\d+') < "0.9" ]]; then
  echo "Installing Neovim..."
  sudo add-apt-repository -y ppa:neovim-ppa/unstable
  sudo apt-get update
  sudo apt-get install -y neovim
else
  echo "Neovim already installed"
fi

# Install starship prompt
if ! command -v starship &>/dev/null; then
  echo "Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- -y
else
  echo "starship already installed"
fi

# Install zoxide
if ! command -v zoxide &>/dev/null; then
  echo "Installing zoxide..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
else
  echo "zoxide already installed"
fi

# Install mise (version manager)
if ! command -v mise &>/dev/null; then
  echo "Installing mise..."
  curl https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
else
  echo "mise already installed"
fi

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

echo ""
echo "Installation complete!"
echo ""
echo "Notes:"
echo "  - Log out and back in for zsh to become your default shell"
echo "  - Run 'tmux' and press 'prefix + I' to install tmux plugins"
echo "  - Open nvim to let lazy.nvim install plugins automatically"
