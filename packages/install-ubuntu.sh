#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update

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
  zsh-autosuggestions
