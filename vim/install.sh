#! /bin/bash

pkg_mgr_install vim

# symlink .vimrc
rm -f $HOME/.vimrc
ln -s $DOTFILES/vim/config.symlink ~/.vimrc

rm -rf $HOME/.vim
mkdir -p $HOME/.vim/{pack,plugin,bundle}/{typescript,git-plugins,plugins}/start

ln -s $DOTFILES/vim/src/base16-shell $HOME/.config/base16-shell
echo "SYMLINKING $DOTFILES/vim/src/base16/colors/ to $HOME/.vim/colors"
ln -s $DOTFILES/vim/src/base16/colors/ $HOME/.vim/colors

echo "SYMLINKING $DOTFILES/vim/src/typescript-vim to $HOME/.vim/pack/typescript/start/typescript-vim"
ln -s $DOTFILES/vim/src/typescript-vim $HOME/.vim/pack/typescript/start/typescript-vim

echo "SYMLINKING $DOTFILES/vim/src/ale to $HOME/.vim/pack/git-plugins/start/ale"
ln -s $DOTFILES/vim/src/ale $HOME/.vim/pack/git-plugins/start/ale

echo "SYMLINKING $DOTFILES/vim/src/auto-pairs/plugins/auto-pairs.vim to $HOME/.vim/plugin/auto-pairs.vim"
ln -s $DOTFILES/vim/src/auto-pairs/plugin/auto-pairs.vim $HOME/.vim/plugin/

echo "SYMLINKING $DOTFILES/vim/src/vim-solidity to $HOME/.vim/bundle/vim-solidity"
ln -s $DOTFILES/vim/src/vim-solidity $HOME/.vim/bundle/vim-solidity

echo "SYMLINKING $DOTFILES/vim/src/lightline/ to $HOME/.vim/pack/plugins/start/lightline"
ln -s $DOTFILES/vim/src/lightline/ $HOME/.vim/pack/plugins/start/lightline

echo "SYMLINKING $DOTFILES/vim/src/nerdcommenter/ to $HOME/.vim/plugin/nerdcommenter"
ln -s $DOTFILES/vim/src/nerdcommenter/ $HOME/.vim/plugin/nerdcommenter

cd $DOTFILES/vim/src/YouCompleteMe
python3 install.py --ts-completer

