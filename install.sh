#!/bin/bash

set -e
export DOTFILES=~/.dotfiles
export TOPICS=(homebrew zsh vim tmux git go)

echo "RUNNING git submodule update --init --recursive"
git submodule update --init --recursive

for topic in "${TOPICS[@]}"
  do
    ./$topic/install.sh
  done

echo "DONE"
