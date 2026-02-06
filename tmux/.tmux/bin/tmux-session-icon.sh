#!/bin/bash
# Aggregate Claude Code state across all panes in a session
# Usage: tmux-session-icon.sh <session_name>

SESSION="${1:-}"
[[ -z "$SESSION" ]] && exit 0

HAS_AWAIT=false

for PANE_ID in $(tmux list-panes -s -t "$SESSION" -F '#{pane_id}'); do
    STATE_FILE="/tmp/tmux-state${PANE_ID//\//-}"
    [[ ! -f "$STATE_FILE" ]] && continue
    STATE=$(cat "$STATE_FILE" 2>/dev/null)
    case "$STATE" in
        await) HAS_AWAIT=true ;;
    esac
    $HAS_AWAIT && break
done

if $HAS_AWAIT; then
    echo " 🟠"
fi
