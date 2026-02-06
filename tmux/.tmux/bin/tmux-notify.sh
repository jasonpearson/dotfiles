#!/bin/bash
# Update tmux state for Claude Code instance
# Usage: claude-tmux-notify <state>  (running|complete|clear)

STATE="${1:-}"
[[ -z "${TMUX:-}" ]] && exit 0

# Use pane ID for per-instance state
PANE_ID="${TMUX_PANE:-}"
[[ -z "$PANE_ID" ]] && exit 0

# Sanitize pane ID for filename (replace / with -)
STATE_FILE="/tmp/tmux-state${PANE_ID//\//-}"

case "$STATE" in
    running|complete)
        echo "$STATE" > "$STATE_FILE"
        ;;
    clear)
        rm -f "$STATE_FILE"
        ;;
esac
