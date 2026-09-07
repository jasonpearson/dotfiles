#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update

bun_packages=()
if apt-cache show bun >/dev/null 2>&1; then
  bun_packages=(bun)
else
  echo "Skipping bun: no apt package named 'bun' is available from configured repositories" >&2
fi

# Ubuntu's yq package is the Python/jq-wrapper implementation, not Mike Farah's
# Go yq used by Homebrew/Arch.
sudo apt-get install -y \
  build-essential \
  curl \
  fzf \
  git \
  jq \
  neovim \
  ripgrep \
  shellcheck \
  stow \
  tmux \
  unzip \
  wget \
  yq \
  zoxide \
  zsh \
  zsh-autosuggestions \
  "${bun_packages[@]}"
