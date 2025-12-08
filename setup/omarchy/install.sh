#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../setup-common.sh"

# Helper: install package with yay if not installed
yay_install() {
  local pkg="$1"
  if ! pacman -Qi "$pkg" &>/dev/null; then
    echo "Installing $pkg..."
    yay -S --noconfirm --needed "$pkg"
  else
    echo "$pkg already installed"
  fi
}

# 1. Install packages
yay_install zsh
yay_install ghostty
yay_install tmux
yay_install stow

# 2. Install Tmux Plugin Manager
install_tpm

# 3. Stow dotfiles
stow_dotfiles

# 4. Setup Hyprland overrides
HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.conf"
OVERRIDES_CONFIG="$SCRIPT_DIR/hyprland-overrides.conf"
SOURCE_LINE="source = $OVERRIDES_CONFIG"

if [ -f "$HYPRLAND_CONFIG" ] && [ -f "$OVERRIDES_CONFIG" ]; then
  if ! grep -Fxq "$SOURCE_LINE" "$HYPRLAND_CONFIG"; then
    echo "Adding Hyprland overrides..."
    echo "" >> "$HYPRLAND_CONFIG"
    echo "$SOURCE_LINE" >> "$HYPRLAND_CONFIG"
  else
    echo "Hyprland overrides already configured"
  fi
else
  echo "Skipping Hyprland overrides (config not found)"
fi

# 5. Set zsh as default shell
set_default_shell_zsh

echo "Done!"
