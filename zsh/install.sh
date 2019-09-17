#! /bin/bash

set -e

if ! [ -x "$(command -v zsh)" ];
then
	sudo apt-get install zsh
fi


if ! [ $SHELL = $(which zsh) ];
then
	echo "RUN chsh -s $(which zsh)"
	chsh -s $(which zsh)
	echo SHELL HAS BEEN CHANGED TO ZSH. LOGOUT AND RUN INSTALL AGAIN.
	exit 1
fi

# symlink .zshrc
rm -f $HOME/.zshrc
ln -s $DOTFILES/zsh/config.symlink.zsh $HOME/.zshrc

# source $HOME/.zshrc
exec zsh
