#! /bin/zsh

export DOTFILES=~/.dotfiles
export EDITOR=vim

# source path.zsh files
for file in $DOTFILES/**/path.zsh(.); do source $file; done

# source alias.zsh files
for file in $DOTFILES/**/alias.zsh(.); do source $file; done

# source config.zsh files
for file in $DOTFILES/**/config.zsh(.); do source $file; done

# pure prompt
fpath+=("$DOTFILES/zsh/src/pure" "$DOTFILES/fzf")
autoload -U promptinit; promptinit
prompt pure

# vi-style command line
bindkey -v

# zsh-autosuggestions
source $DOTFILES/zsh/src/zsh-autosuggestions/zsh-autosuggestions.zsh

# z jump
source $DOTFILES/zsh/src/z/z.sh
