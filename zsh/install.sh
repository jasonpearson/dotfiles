#! /bin/bash

pkg_mgr_install zsh

if ! [ $SHELL = $(which zsh) ];
then
	if ! grep -q "$(which zsh)" /etc/shells;
	then
		echo "ADDING $(which zsh) to /etc/shells"
		echo $(which zsh) | sudo tee -a /etc/shells
	fi
	echo "RUNNING chsh -s $(which zsh)"
	chsh -s $(which zsh)
	echo "SHELL CHANGED. LOGOUT AND RUN $DOTFILES/install.sh AGAIN."
	exit 1
fi

# symlink .zshrc
echo "SYMLINKING $DOTFILES/zsh/config.symlink.zsh to $HOME/.zshrc"
rm -f $HOME/.zshrc
ln -s $DOTFILES/zsh/config.symlink.zsh $HOME/.zshrc

