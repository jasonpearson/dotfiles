#!/bin/bash

# Install stow
if ! command -v stow &>/dev/null; then
  brew install stow
fi
