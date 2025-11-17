#!/bin/bash

# Install brew
if ! command -v brew &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
fi
