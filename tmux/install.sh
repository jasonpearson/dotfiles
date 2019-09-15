#! /bin/zsh

set -e

# symlink .tmux.conf
rm -f ~/.tmux.conf
ln -s ~/.dotfiles/tmux/tmux.conf.symlink ~/.tmux.conf
