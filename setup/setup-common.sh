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

install_tpm() {
  TPM_DIR="$HOME/.tmux/plugins/tpm"
  if [ ! -d "$TPM_DIR" ]; then
    echo "Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
  else
    echo "TPM already installed"
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
    ~/.config/nvim \
    ~/.config/opencode \
    ~/.config/starship.toml \
    ~/.gitconfig \
    ~/.local/share/nvim/

  cd "$DOTFILES_DIR"
  echo "Stowing dotfiles..."
  stow zshrc ghostty tmux nvim starship gitconfig opencode claude
}

set_default_shell_zsh() {
  ZSH_PATH=$(which zsh)
  if [ "$SHELL" != "$ZSH_PATH" ]; then
    if ! grep -q "^$ZSH_PATH$" /etc/shells; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$ZSH_PATH"
    echo "Default shell changed to zsh. Log out and back in for it to take effect."
  else
    echo "zsh is already the default shell"
  fi
}
