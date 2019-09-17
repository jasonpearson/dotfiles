#! /bin/zsh

set -e

# symlink .tmux.conf
rm -f $HOME/.tmux.conf
ln -s $DOTFILES/tmux/config.symlink ~/.tmux.conf
