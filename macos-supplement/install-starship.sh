#!/bin/bash

# Install starship
if ! command -v starship &>/dev/null; then
  brew install starship
fi
