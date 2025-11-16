eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

export CONFIG="~/.config"
export EDITOR="nvim"
export SUDO_EDITOR="$EDITOR"
export KEYTIMEOUT=20
HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000

setopt inc_append_history

eval "$(~/.local/bin/mise activate zsh)"

autoload -U compinit; compinit

bindkey -v
bindkey -M viins 'kj' vi-cmd-mode

source <(fzf --zsh)

alias e="$EDITOR $1"
alias glo='git log --date=format:"%Y-%m-%d %H:%M %z" --pretty=format:"%h%x09%as%x09%ar%x09%an%x09%s"'
alias gac="git add -A && git commit -m $1"
alias gaca='git add -A && git commit --amend --no-edit'
alias gs='git status'
alias gd="git diff $1"
alias gp='git push'
alias ll='ls -la'

function ed() {
  if [[ $# -eq 0 ]]; then
    files=$(git diff --name-only)
  else
    files=$(git diff --name-only --diff-filter=$1)
  fi

  echo $files | xargs nvim
}

function eg() { e $(rg -l $@) };

function ef() { e $(rg --files | rg $@) };

function tm() {
  session_dir=$(zoxide query --list | fzf)
  session_name=$(basename "$session_dir")

  if tmux has-session -t $session_name 2>/dev/null; then
    if [ -n "$TMUX" ]; then
      tmux switch-client -t "$session_name"
    else
      tmux attach -t "$session_name"
    fi
    notification="tmux attached to $session_name"
  else
    if [ -n "$TMUX" ]; then
      tmux new-session -d -c "$session_dir" -s "$session_name" && tmux switch-client -t "$session_name"
      notification="new tmux session INSIDE TMUX: $session_name"
    else
      tmux new-session -c "$session_dir" -s "$session_name"
      notification="new tmux session: $session_name"
    fi
  fi

  if [-s "$session_name" ]; then
    notify-send "$notification"
  fi
}

