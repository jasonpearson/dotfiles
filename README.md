# dotfiles

## setup
1. cd to home directory and run `git clone https://github.com/jasonpearson/dotfiles.git ~/.config`
2. install homebrew (https://brew.sh/) and run `xargs brew install < ~/.config/homebrew.txt`
3. run `ln -sf ~/.config/zsh/.zshenv ~/.zshenv`

## upgrade dependencies
1. `git submodule update --init --recursive --remote`
