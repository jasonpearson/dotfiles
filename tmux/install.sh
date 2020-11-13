#!/bin/bash

echo "RUNNING tmux install script"

rm -f ~/.tmux.conf
ln -s $DOTFILES/tmux/tmux.conf ~/.tmux.conf
