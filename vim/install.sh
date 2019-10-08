#! /bin/bash

pkg_mgr_install vim

# symlink .vimrc
rm -f $HOME/.vimrc
ln -s $DOTFILES/vim/config.symlink ~/.vimrc

# symlink colors
echo "SYMLINKING $DOTFILES/vim/src/colors to $HOME/.vim/colors"
rm -f $HOME/.vim/colors
ln -s $DOTFILES/vim/src/colors $HOME/.vim/colors

