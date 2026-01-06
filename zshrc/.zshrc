eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(mise activate zsh)"

if [[ -f ~/.env.zsh ]]; then
  source ~/.env.zsh
fi

# only used in macos
# platform-specific zsh-autosuggestions
if [[ -f /opt/homebrew/bin/brew ]]; then
  # macOS with Homebrew
  eval "$(/opt/homebrew/bin/brew shellenv)"
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  # Ubuntu/Debian
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

export CONFIG="~/.config"
export EDITOR="nvim"
export KEYTIMEOUT=20
export SUDO_EDITOR="$EDITOR"

HISTFILE=~/.history
HISTSIZE=10000
SAVEHIST=50000
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# claude
export PATH="$HOME/.local/bin:$PATH"

setopt inc_append_history

autoload -U compinit; compinit

bindkey -M viins 'kj' vi-cmd-mode
bindkey -v
bindkey '^y' autosuggest-accept

# fzf shell integration (0.48+ uses --zsh, older versions use separate files)
if fzf --zsh &>/dev/null; then
  source <(fzf --zsh)
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi

function cc() { claude "$@"; }

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
function egf() { e $(rg -u --files | rg $@) };
function ga() { git add "$@"; }
function gac() { ga "-A" && gc "$@" }
function gaca() { ga "-A" && gc --amend }
function gc() { git commit "$@"; }
function gd() { git diff "$@"; }

function glo() {
  git log --color --decorate --pretty=format:"%h %an %Cgreen(%cr)%Creset - %s%C(yellow)%d%Creset" --abbrev-commit "$@"
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

# quick ask
function qa() { claude --model haiku -p "$@"; }
