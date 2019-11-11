if test "$(uname)" = "Darwin"
then
	. ~/.dotfiles/config.macos.sh
elif test "$(expr substr $(uname -s) 1 5)" = "Linux"
then
	. ~/.dotfiles/config.ubuntu.sh
fi

BASE16_SHELL="$HOME/.config/base16-shell/"
[ -n "$PS1"  ] && \
      [ -s "$BASE16_SHELL/profile_helper.sh"  ] && \
              eval "$("$BASE16_SHELL/profile_helper.sh")"

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
bindkey kj vi-cmd-mode

# zsh-autosuggestions
source $DOTFILES/zsh/src/zsh-autosuggestions/zsh-autosuggestions.zsh

# z jump
source $DOTFILES/zsh/src/z/z.sh


