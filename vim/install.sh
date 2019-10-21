#! /bin/bash

pkg_mgr_install vim

# symlink .vimrc
rm -f $HOME/.vimrc
ln -s $DOTFILES/vim/config.symlink ~/.vimrc

rm -rf $HOME/.vim
mkdir -p $HOME/.vim/{pack,plugin}/{typescript,git-plugins}/start

echo "SYMLINKING $DOTFILES/vim/src/colors to $HOME/.vim/colors"
ln -s $DOTFILES/vim/src/colors $HOME/.vim/colors

echo "SYMLINKING $DOTFILES/vim/src/typescript-vim to $HOME/.vim/pack/typescript/start/typescript-vim"
ln -s $DOTFILES/vim/src/typescript-vim $HOME/.vim/pack/typescript/start/typescript-vim

echo "SYMLINKING $DOTFILES/vim/src/ale to $HOME/.vim/pack/git-plugins/start/ale"
ln -s $DOTFILES/vim/src/ale $HOME/.vim/pack/git-plugins/start/ale

echo "SYMLINKING $DOTFILES/vim/src/auto-pairs/plugins/auto-pairs.vim to $HOME/.vim/plugin/auto-pairs.vim"
ln -s $DOTFILES/vim/src/auto-pairs/plugin/auto-pairs.vim $HOME/.vim/plugin/

cd $DOTFILES/vim/src/YouCompleteMe
python3 install.py --ts-completer

