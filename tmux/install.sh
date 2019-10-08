#! /bin/bash

pkg_mgr_install tmux

# symlink .tmux.conf
echo "SYMLINKING $DOTFILES/tmux/config.symlink to $HOME/.tmux.conf"
rm -f $HOME/.tmux.conf
ln -s $DOTFILES/tmux/config.symlink $HOME/.tmux.conf

