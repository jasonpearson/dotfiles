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
function gaca() { ga "-A" && gc --amend }
function gc() { git commit "$@"; }
function gd() { git diff "$@"; }

function glo() {
  git log --color --decorate --pretty=format:"%h %an %Cgreen(%cr)%Creset - %s%C(yellow)%d%Creset" --abbrev-commit "$@"
}

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
  "$@"
  local exit_code=$?
  ~/.tmux/bin/tmux-notify.sh await
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

# Create or attach to a tmux session for the given directory
function _tm_session() {
  local session_dir="$1"
  # For worktree dirs (.wt/$REPO/$BRANCH), use "$REPO-$BRANCH" as name
  if [[ "$session_dir" == */.wt/*/* ]]; then
    local session_name="$(basename "$(dirname "$session_dir")")-$(basename "$session_dir")"
  else
    local session_name=$(basename "$session_dir")
  fi

  if tmux has-session -t $session_name 2>/dev/null; then
    # Session exists — switch or attach depending on whether we're in tmux
    if [ -n "$TMUX" ]; then
      tmux switch-client -t "$session_name"
    else
      tmux attach -t "$session_name"
    fi
  else
    # New session — create detached with "tools" and "code" windows, then connect
    tmux new-session -d -c "$session_dir" -s "$session_name"
    if [ -n "$TMUX" ]; then
      tmux switch-client -t "$session_name"
    else
      tmux attach -t "$session_name"
    fi
  fi
}

# Pick a project directory via zoxide+fzf and open a tmux session for it
function tm() {
  local session_dir=$(zoxide query --list | fzf --header 'create session') || return
  _tm_session "$session_dir"
}

# Open a tmux session for the current working directory
function tmc() {
  _tm_session "$(pwd)"
}

function tma() {
  tmux a "$@"
}

function tml() {
  tmux ls "$@"
}

# add a git worktree at ../.wt/$REPO/$BRANCH and cd into it
# default creates a new branch; -e checks out an existing one
function wt() {
  local existing=false
  if [ "$1" = "-e" ]; then
    existing=true
    shift
  fi
  if [ -z "$1" ]; then
    echo "usage: wta [-e] <branch-name>" >&2
    return 1
  fi
  local branch="$1"
  local repo=$(basename "$(git rev-parse --show-toplevel)")
  local worktree_path="../.wt/${repo}/${branch}"
  if $existing; then
    git worktree add "$worktree_path" "$branch"
  else
    git worktree add "$worktree_path" -b "$branch"
  fi && _tm_session "$(cd "$worktree_path" && pwd)"
}

# Remove the current git worktree and kill its tmux session
function wtr() {
  local wt_dir=$(git rev-parse --show-toplevel 2>/dev/null)
  # Worktrees have a .git file; main repos have a .git directory
  if [ ! -f "$wt_dir/.git" ]; then
    echo "error: not inside a git worktree" >&2
    return 1
  fi
  local main_dir=$(git rev-parse --git-common-dir | sed 's|/\.git$||')

  # Derive tmux session name using same logic as _tm_session
  if [[ "$wt_dir" == */.wt/*/* ]]; then
    local session_name="$(basename "$(dirname "$wt_dir")")-$(basename "$wt_dir")"
  else
    local session_name=$(basename "$wt_dir")
  fi

  # Confirm with user
  echo "Will remove worktree: $wt_dir"
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Will kill tmux session: $session_name"
  fi
  read -q "reply?Proceed? [y/N] " || { echo; return 1; }
  echo

  # cd to main repo before removing (can't remove while inside the worktree)
  cd "$main_dir"

  # Remove the worktree first (kill-session would terminate this shell)
  git worktree remove "$wt_dir" || return 1

  # Switch to another tmux session before killing, or just kill
  if tmux has-session -t "$session_name" 2>/dev/null; then
    if [ -n "$TMUX" ]; then
      tmux switch-client -n 2>/dev/null
    fi
    tmux kill-session -t "$session_name"
  fi
}

# quick ask
function qa() { claude --model haiku -p "$@"; }
