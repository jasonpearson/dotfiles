ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=6"
source $ZDOTDIR/zsh-autosuggestions/zsh-autosuggestions.zsh
bindkey '^y' autosuggest-accept
