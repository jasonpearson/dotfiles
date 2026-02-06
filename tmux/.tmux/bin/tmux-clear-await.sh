#!/bin/bash
# Clear "await" state when pane receives focus
# Usage: tmux-clear-await.sh <pane_id>

PANE_ID="${1:-}"
[[ -z "$PANE_ID" ]] && exit 0

STATE_FILE="/tmp/tmux-state${PANE_ID//\//-}"
[[ ! -f "$STATE_FILE" ]] && exit 0

rm -f "$STATE_FILE"
tmux refresh-client -S
