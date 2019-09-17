#! /bin/zsh

# symlink .vimrc
rm -f $HOME/.vimrc
ln -s $DOTFILES/vim/config.symlink ~/.vimrc

# symlink colors
rm -f $HOME/.vim/colors
ln -s $DOTFILES/vim/src/colors $HOME/.vim/colors
