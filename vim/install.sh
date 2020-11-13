#!/bin/bash

echo "RUNNING vim install script"

rm -f ~/.vimrc
ln -s $DOTFILES/vim/vimrc ~/.vimrc

rm -rf ~/.vim
mkdir -p ~/.vim/pack/custom
ln -s $DOTFILES/vim ~/.vim/pack/custom/start
