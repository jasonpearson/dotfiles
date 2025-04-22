autoload -U compinit; compinit

bindkey -v
bindkey -M viins 'kj' vi-cmd-mode

source $ZDOTDIR/setup-homebrew.zsh

source $ZDOTDIR/aliases.zsh
source $ZDOTDIR/secrets.zsh
source $ZDOTDIR/setup-fnm.zsh
source $ZDOTDIR/setup-java.zsh
source $ZDOTDIR/setup-pure.zsh
source $ZDOTDIR/setup-python.zsh
source $ZDOTDIR/setup-autosuggestions.zsh
source $ZDOTDIR/setup-z.zsh
