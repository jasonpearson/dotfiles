#!/bin/bash

set -e
export DOTFILES=~/.dotfiles
export TOPICS=(homebrew zsh vim tmux git go)

echo "RUNNING git submodule update --init --recursive --remote"
git submodule update --init --recursive --remote

for topic in "${TOPICS[@]}"
  do
    ./$topic/install.sh
  done

echo "DONE"
