#!/bin/bash

# Install opencode
if ! command -v opencode &>/dev/null; then
  brew install opencode
fi
