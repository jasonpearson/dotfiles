#!/bin/bash
# Output icon based state for given pane
# Usage: tmux-icon <pane_id>

PANE_ID="${1:-}"
[[ -z "$PANE_ID" ]] && exit 0

STATE_FILE="/tmp/tmux-state${PANE_ID//\//-}"
[[ ! -f "$STATE_FILE" ]] && exit 0

STATE=$(cat "$STATE_FILE" 2>/dev/null)

case "$STATE" in
    running) echo " 🟡" ;;
    complete) echo " 🟢" ;;
esac
