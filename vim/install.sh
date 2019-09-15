#! /bin/zsh

# symlink .vimrc
rm -f ~/.vimrc
ln -s $DOTFILES/vim/vimrc.symlink ~/.vimrc

# symlink colors
rm -f ~/.vim/colors
ln -s $DOTFILES/vim/src/colors $HOME/.vim/colors
