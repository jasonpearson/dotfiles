if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if [[ -f ~/.env.zsh ]]; then
  source ~/.env.zsh
fi

# only used in macos
# platform-specific zsh-autosuggestions
if [[ -f /opt/homebrew/bin/brew ]]; then
  # macOS with Homebrew
  eval "$(/opt/homebrew/bin/brew shellenv)"
  source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
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
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh &>/dev/null; then
    source <(fzf --zsh)
  elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

alias tf=terraform
alias t='tmux attach || tmux new -s "$PWD"'

function br() { bun run "$@"; }

function cc() { claude "$@"; }

function e() {
  local editor="${EDITOR:-nvim}"
  local -a editor_argv

  editor_argv=(${(z)editor})
  "${editor_argv[@]}" "$@"
}

function ed() {
  local -a files=()

  files=(${(f)"$(git diff --name-only --diff-filter=d -- "$@")"})

  e "${files[@]}"
}

function ef() {
  local file
  file=$(fzf) || return
  [[ -n "$file" ]] || return
  e "$file"
};

function eg() {
  local -a files
  files=(${(f)"$(rg -l "$@")"})
  (( ${#files} )) || return 1
  e "${files[@]}"
}
function egf() {
  local -a files
  files=(${(f)"$(rg -u --files | rg "$@")"})
  (( ${#files} )) || return 1
  e "${files[@]}"
}

# Git helpers. Avoid ga/gd here because Omarchy uses those for worktree helpers.
function gadd() { git add "$@"; }
function gdiff() { git diff "$@"; }
function gac() { git add -A && git commit "$@"; }
function gaca() { git add -A && git commit --amend "$@"; }
function gc() { git commit "$@"; }
function gco() { git checkout "$@"; }

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

for tmux_attention_bin in "$HOME"/.tmux/plugins/tmux-attention*/bin; do
  [[ -d "$tmux_attention_bin" ]] || continue
  case ":$PATH:" in
    *":$tmux_attention_bin:"*) ;;
    *) export PATH="$tmux_attention_bin:$PATH" ;;
  esac
done
unset tmux_attention_bin

if command -v tmux-attention >/dev/null 2>&1; then
  alias ta='tmux-attention'
  alias tac='tmux-attention new "$PWD"'
fi

if [[ -n "${HERDR_PANE_ID:-}" && -z "${TMUX:-}" ]]; then
  _herdr_focus_left() { herdr pane focus --current --direction left >/dev/null 2>&1; zle reset-prompt; }
  _herdr_focus_down() { herdr pane focus --current --direction down >/dev/null 2>&1; zle reset-prompt; }
  _herdr_focus_up() { herdr pane focus --current --direction up >/dev/null 2>&1; zle reset-prompt; }
  _herdr_focus_right() { herdr pane focus --current --direction right >/dev/null 2>&1; zle reset-prompt; }

  zle -N _herdr_focus_left
  zle -N _herdr_focus_down
  zle -N _herdr_focus_up
  zle -N _herdr_focus_right

  bindkey '^H' _herdr_focus_left
  bindkey '^J' _herdr_focus_down
  bindkey '^K' _herdr_focus_up
  bindkey '^L' _herdr_focus_right

  bindkey $'\e[104;5u' _herdr_focus_left
  bindkey $'\e[106;5u' _herdr_focus_down
  bindkey $'\e[107;5u' _herdr_focus_up
  bindkey $'\e[108;5u' _herdr_focus_right
fi

function tl() { tmux list-sessions "$@"; }

# Under SSH, emit "remote_pwd (host)" via the OSC title — the one channel that
# crosses the ssh boundary — so the parent tmux can render the remote path and
# host on the pane border. Locally the border reads pane_current_path directly,
# so there is nothing to do (we no longer set a terminal-tab title at all).
function _set_title() {
  [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] || return
  local host="${${HOST%%.*}#jason-pearson-}"
  print -Pn "\e]0;%~ ($host)\a"
  [[ -n "$TMUX" ]] && tmux set-option -p @ssh_host "$host" 2>/dev/null
}
precmd_functions+=(_set_title)
