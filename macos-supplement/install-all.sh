#!/bin/bash

# Install all packages in order
./install-brew.sh
./install-zsh.sh
./install-zsh.sh
./install-zoxide.sh
./install-starship.sh
./install-tmux.sh
./install-fzf.sh
./install-nvim.sh
./install-stow.sh
./install-ghostty.sh
./install-mise.sh
./install-claude-code.sh
./install-open-code.sh
./install-dotfiles.sh

./set-shell.sh
