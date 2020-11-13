#!/bin/bash
if ! command -v brew &> /dev/null
then
  echo "RUNNING homebrew install script"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  xargs brew install < $DOTFILES/homebrew/homebrew.txt
else
  echo "SKIPPING homebrew (already installed)"
fi
