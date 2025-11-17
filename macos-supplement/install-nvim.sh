#!/bin/bash

# Install neovim
if ! command -v nvim &>/dev/null; then
  brew install nvim
fi
