#!/bin/bash

echo "RUNNING zsh install script"

rm -f ~/.zshrc
ln -s $DOTFILES/zsh/zshrc ~/.zshrc

rm -rf ~/.zsh
ln -s $DOTFILES/zsh ~/.zsh

rm -rf ~/.config
ln -s $DOTFILES/zsh/config ~/.config
