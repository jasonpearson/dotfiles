#!/bin/bash

echo "RUNNING git install script"

rm -f ~/.gitignore
ln -s $DOTFILES/git/gitignore ~/.gitignore
git config --global core.excludesfiles "/.gitignore"
