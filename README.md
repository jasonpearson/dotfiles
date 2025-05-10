# dotfiles

## setup

1. cd to home directory and run `git clone https://github.com/jasonpearson/dotfiles.git ~/.config`
2. run `git submodule update --init --recursive --remote`
3. install homebrew (https://brew.sh/)
4. run `xargs brew install < ~/.config/homebrew-formulae.txt`
5. run `ln -sf ~/.config/tmux/tmux.conf ~/.tmux.conf`
6. run `ln -sf ~/.config/zsh/.zshenv ~/.zshenv`
7. run `ln -sf ~/.config/.gitconfig ~/.gitconfig`
