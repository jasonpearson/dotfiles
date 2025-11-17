#!/bin/bash

# Install mise
if ! command -v mise &>/dev/null; then
  brew install mise
fi
