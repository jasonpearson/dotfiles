eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(mise activate zsh)"

# only used in macos
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

export CONFIG="~/.config"
export EDITOR="nvim"
export SUDO_EDITOR="$EDITOR"
export KEYTIMEOUT=20

# claude
export PATH="$HOME/.local/bin:$PATH"

HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

setopt inc_append_history

autoload -U compinit; compinit

bindkey -M viins 'kj' vi-cmd-mode
bindkey -v
bindkey '^y' autosuggest-accept

source <(fzf --zsh)

function e() { "$EDITOR" "$@"; }

function ed() {
  if [[ $# -eq 0 ]]; then
    files=$(git diff --name-only)
  else
    files=$(git diff --name-only --diff-filter=$1)
  fi

  echo $files | xargs nvim
}

function ef() {
  local file
  file=$(fzf) || return
  [[ -n "$file" ]] || return
  e "$file"
};

function eg() { e $(rg -l $@) };
function egf() { e $(rg -uu --files | rg $@) };
function ga() { git add "$@"; }
function gc() { git commit "$@"; }
function gd() { git diff "$@"; }

function glo() {
  git log  \
    --color=always \
    --date=iso-local \
    --pretty=format:'%C(yellow)%h%Creset  %<(55,trunc)%s  %C(blue)@%<(15,trunc)%al%Creset  %C(magenta)%ad%Creset' "$@"
}

function gs() { git status "$@"; }
function gp() { git push "$@"; }
function k() { kubectl "$@"; }
function ll() { ls -la "$@"; }
function oc() { opencode "$@"; }

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

