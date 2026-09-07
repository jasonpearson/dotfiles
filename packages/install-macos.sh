#!/usr/bin/env bash
set -euo pipefail

brew install \
  curl \
  fluxcd/tap/flux \
  fzf \
  git \
  jq \
  kind \
  mise \
  neovim \
  opencode \
  ripgrep \
  shellcheck \
  starship \
  stow \
  tmux \
  tmuxpack/tpack/tpack \
  unzip \
  wget \
  yq \
  zoxide \
  zsh \
  zsh-autosuggestions

brew install --cask \
  ghostty
