#!/bin/bash
# Update tmux state for Claude Code instance
# Usage: tmux-notify.sh <state>  (await|clear)

STATE="${1:-}"
[[ -z "${TMUX:-}" ]] && exit 0

PANE_ID="${TMUX_PANE:-}"
[[ -z "$PANE_ID" ]] && exit 0

STATE_FILE="/tmp/tmux-state${PANE_ID//\//-}"

case "$STATE" in
    await)
        # Skip if pane is currently focused
        ACTIVE=$(tmux display-message -t "$PANE_ID" -p '#{&&:#{pane_active},#{&&:#{window_active},#{session_attached}}}' 2>/dev/null)
        [[ "$ACTIVE" = "1" ]] && exit 0
        echo "$STATE" > "$STATE_FILE"
        ;;
    clear)
        rm -f "$STATE_FILE"
        ;;
esac

# Refresh all clients' status bars so other sessions see the change immediately
tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r client; do
    tmux refresh-client -t "$client" -S 2>/dev/null
done
