. ~/.dotfiles/config.sh

# source path.zsh, alias.zsh, and config.zsh files
for topic in $TOPICS; do
	if [ -e $DOTFILES/$topic/path.zsh ]; then
		echo "RUNNING source $DOTFILES/$topic/path.zsh"
		source $DOTFILES/$topic/path.zsh
	fi

	if [ -e $DOTFILES/$topic/alias.zsh ]; then
		echo "RUNNING source $DOTFILES/$topic/alias.zsh"
		source $DOTFILES/$topic/alias.zsh
	fi

	if [ -e $DOTFILES/$topic/config.zsh ]; then
		echo "RUNNING source $DOTFILES/$topic/config.zsh"
		source $DOTFILES/$topic/config.zsh
	fi
done

# pure prompt
fpath+=("$DOTFILES/zsh/src/pure")
autoload -U promptinit; promptinit
prompt pure

# vi-style command line
bindkey -v

# zsh-autosuggestions
source $DOTFILES/zsh/src/zsh-autosuggestions/zsh-autosuggestions.zsh

# z jump
source $DOTFILES/zsh/src/z/z.sh

