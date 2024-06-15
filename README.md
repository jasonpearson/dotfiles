# dotfiles

## setup
1. cd to home directory and run `git clone https://github.com/jasonpearson/dotfiles.git ~/.config`
2. run `git submodule update --init --recursive --remote`
3. install homebrew (https://brew.sh/)
4. run `xargs brew tap < ~/.config/homebrew-taps.txt`
5. run `xargs brew install < ~/.config/homebrew-formulae.txt`
6. run `ln -sf ~/.config/tmux/tmux.conf ~/.tmux.conf`
7. run `ln -sf ~/.config/zsh/.zshenv ~/.zshenv`
