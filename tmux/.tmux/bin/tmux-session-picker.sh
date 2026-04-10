#!/bin/bash
# Pick a tmux session via fzf, excluding the current one.
#   enter: switch-client to the selected session
#   K    : kill the selected session and refresh the list

set -uo pipefail

ICON_SCRIPT="$HOME/.tmux/bin/tmux-icon.sh"

list_sessions() {
  local current
  current=$(tmux display-message -p '#S')
  tmux list-sessions -F '#S' \
    | while read -r s; do
        icon=$("$ICON_SCRIPT" session "$s")
        printf '%s%s\n' "$icon" "$s"
      done \
    | awk -v cur="$current" '
        {
          name = $0
          sub(/^🔥 /, "", name)
          if (name == cur) { c = c $0 "\n"; next }
          if (/🔥/)        { a = a $0 "\n"; next }
          b = b $0 "\n"
        }
        END { printf "%s%s%s", a, b, c }
      '
}

case "${1:-}" in
  --list)
    list_sessions
    exit 0
    ;;
  --kill)
    name="${2:-}"
    name="${name#🔥 }"
    [[ -n "$name" ]] && tmux kill-session -t "$name" 2>/dev/null
    exit 0
    ;;
esac

self="$0"
selection=$(list_sessions | fzf --reverse \
  --header 'enter: switch  |  K: kill' \
  --bind "K:execute-silent($self --kill {})+reload($self --list)") || exit 0

[[ -z "$selection" ]] && exit 0
tmux switch-client -t "${selection#🔥 }"
