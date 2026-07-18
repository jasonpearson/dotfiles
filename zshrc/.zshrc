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

# tmux-attention CLI (pick / new / run)
export PATH="$HOME/.tmux/plugins/tmux-attention/bin:$PATH"

setopt inc_append_history

autoload -U compinit; compinit

bindkey -v
bindkey -M viins 'kj' vi-cmd-mode
bindkey '^y' autosuggest-accept

# fzf shell integration (0.48+ uses --zsh, older versions use separate files)
if fzf --zsh &>/dev/null; then
  source <(fzf --zsh)
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi

alias tf=terraform

function br() { bun run "$@"; }

function cc() { claude "$@"; }

function e() { "$EDITOR" "$@"; }

function ed() {
  if [[ $# -eq 0 ]]; then
    files=$(git diff --name-only)
  else
    files=$(git diff --name-only --diff-filter=$1)
  fi

  nvim ${(f)files}
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
function gaca() { ga "-A" && gc --amend "$@" }
function gc() { git commit "$@"; }
function gco() { git checkout "$@"; }
function gd() { git diff "$@"; }

function glo() {
  git log --color --decorate --pretty=format:"%h %an %Cgreen(%cr)%Creset - %s%C(yellow)%d%Creset" --abbrev-commit "$@"
}

function gb() { git branch "$@"; }
function gs() { git status "$@"; }
function gp() { git push "$@"; }
function gw() { git worktree "$@"; }

function review() {
  if [[ -z "$1" ]]; then
    echo "usage: review <commit-or-branch>" >&2
    return 1
  fi

  local ref="$1"
  local base

  if git show-ref --verify --quiet "refs/heads/$ref" || \
     git show-ref --verify --quiet "refs/remotes/origin/$ref" || \
     git show-ref --verify --quiet "refs/remotes/$ref"; then
    # Branch — find merge-base
    if git rev-parse --verify "origin/main" &>/dev/null; then
      base=$(git merge-base origin/main "$ref")
    elif git rev-parse --verify "origin/master" &>/dev/null; then
      base=$(git merge-base origin/master "$ref")
    else
      echo "error: could not find origin/main or origin/master" >&2
      return 1
    fi
  else
    # Single commit
    base="${ref}^"
  fi

  git checkout "$base" && git diff "$base" "$ref" | git apply && git add -N .
}

function reviewed() {
  git reset HEAD .
  git checkout -- .
  git clean -fd
  git checkout -
}
k() {
  local match="$1"
  if [[ -z "$match" ]]; then
    echo "Usage: k <context-match> <kubectl args...>" >&2
    kubectl config get-contexts -o name >&2
    return 1
  fi
  shift
  local -a matches=(${(f)"$(kubectl config get-contexts -o name | grep "$match")"})
  if (( ${#matches} == 0 )); then
    echo "No context matching '$match'" >&2
    return 1
  elif (( ${#matches} > 1 )); then
    echo "Multiple contexts match '$match':" >&2
    printf '  %s\n' "${matches[@]}" >&2
    return 1
  fi
  kubectl --context="${matches[1]}" "$@"
}

kd() { k "$(basename "$PWD")-development" "$@"; }
ks() { k "$(basename "$PWD")-staging" "$@"; }
kp() { k "$(basename "$PWD")-production" "$@"; }
function ll() { ls -la "$@"; }

function n() {
  [[ $# -eq 0 ]] && echo "Usage: n <command>" && return 1
  tmux-attention run -- "$@"
  local exit_code=$?
  play_sound
  return $exit_code
}

function oc() { opencode "$@"; }

function play_sound() {
  local file="${1:-}"

  # Find a default sound if none provided
  if [[ -z "$file" ]]; then
    if [[ -f /System/Library/Sounds/Pop.aiff ]]; then
      file="/System/Library/Sounds/Pop.aiff"
    else
      printf '\a'  # terminal bell as last resort
      return
    fi
  fi

  # Play the sound
  if command -v afplay &>/dev/null; then
    afplay "$file"
  elif command -v paplay &>/dev/null; then
    paplay "$file"
  elif command -v aplay &>/dev/null; then
    aplay "$file"
  fi
}

# Session management lives in the tmux-attention CLI (also bound to prefix+a /
# prefix+A inside tmux). These work from a bare shell too: inside tmux they
# switch the client, outside they attach.
alias tmc='tmux-attention new "$PWD"'  # session for the current directory
alias tmf='tmux-attention new'         # fuzzy-find a dir; shift-tab -> session picker

function tma() {
  tmux a "$@"
}

function tml() {
  tmux ls "$@"
}

# quick ask
function qa() { claude --model haiku -p "$@"; }

# Set terminal title: hostname when SSH'd, current path when local
function _set_title() {
  if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]]; then
    local host="${${HOST%%.*}#jason-pearson-}"
    print -Pn "\e]0;%~ ($host)\a"
    [[ -n "$TMUX" ]] && tmux set-option -p @ssh_host "$host" 2>/dev/null
  else
    print -Pn "\e]0;%~\a"
  fi
}
precmd_functions+=(_set_title)
