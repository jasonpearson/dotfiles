#!/bin/bash

# Shared setup functions

install_bun() {
  if ! command -v bun &>/dev/null; then
    echo "Installing bun..."
    curl -fsSL https://bun.sh/install | bash
  else
    echo "bun already installed"
  fi
}

install_tpack() {
  # tpack keeps TPM's directory for drop-in compatibility
  TPACK_DIR="$HOME/.tmux/plugins/tpm"
  if [ -d "$TPACK_DIR" ] && ! git -C "$TPACK_DIR" remote get-url origin 2>/dev/null | grep -q "tmuxpack/tpack"; then
    echo "Migrating TPM -> tpack..."
    rm -rf "$TPACK_DIR"
  fi
  if [ ! -d "$TPACK_DIR" ]; then
    echo "Installing tpack (tmux plugin manager)..."
    git clone https://github.com/tmuxpack/tpack "$TPACK_DIR"
  else
    echo "tpack already installed"
  fi
}

stow_dotfiles() {
  DOTFILES_DIR="$HOME/dotfiles"
  if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Cloning dotfiles..."
    git clone https://github.com/jasonpearson/dotfiles "$DOTFILES_DIR"
  fi

  echo "Removing old configs..."
  rm -rf \
    ~/.cache/nvim/ \
    ~/.config/ghostty/config \
    ~/.config/herdr/config.toml \
    ~/.config/nvim \
    ~/.config/opencode \
    ~/.config/starship.toml \
    ~/.gitconfig \
    ~/.local/share/nvim/

  cd "$DOTFILES_DIR"
  echo "Stowing dotfiles..."
  stow zshrc ghostty tmux nvim starship gitconfig opencode claude herdr
}

set_default_shell_zsh() {
  ZSH_PATH=$(which zsh)
  if [ "$SHELL" != "$ZSH_PATH" ]; then
    if ! grep -q "^$ZSH_PATH$" /etc/shells; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    sudo chsh -s "$ZSH_PATH"
    echo "Default shell changed to zsh. Log out and back in for it to take effect."
  else
    echo "zsh is already the default shell"
  fi
}
