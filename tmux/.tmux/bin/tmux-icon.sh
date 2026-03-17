#!/bin/bash
# Output notification icon based on tmux-state files
# Usage:
#   tmux-icon.sh pane <pane_id>      - icon for a specific pane
#   tmux-icon.sh session <session>   - icon if any pane in session has await state
#   tmux-icon.sh global <session>    - icon if any pane outside session has await state

SUBCOMMAND="${1:-}"

case "$SUBCOMMAND" in
    pane)
        PANE_ID="${2:-}"
        [[ -z "$PANE_ID" ]] && exit 0
        STATE_FILE="/tmp/tmux-state${PANE_ID//\//-}"
        [[ ! -f "$STATE_FILE" ]] && exit 0
        STATE=$(cat "$STATE_FILE" 2>/dev/null)
        case "$STATE" in
            await) echo " 🔥" ;;
        esac
        ;;
    session)
        SESSION="${2:-}"
        [[ -z "$SESSION" ]] && exit 0
        for PANE_ID in $(tmux list-panes -s -t "$SESSION" -F '#{pane_id}' 2>/dev/null); do
            STATE_FILE="/tmp/tmux-state${PANE_ID//\//-}"
            [[ ! -f "$STATE_FILE" ]] && continue
            STATE=$(cat "$STATE_FILE" 2>/dev/null)
            [[ "$STATE" == "await" ]] && echo "🔥 " && exit 0
        done
        ;;
    global)
        CURRENT_SESSION="${2:-}"
        for f in /tmp/tmux-state*; do
            [[ ! -f "$f" ]] && continue
            PANE_ID="${f#/tmp/tmux-state}"
            if [[ -n "$CURRENT_SESSION" ]]; then
                PANE_SESSION=$(tmux display-message -t "$PANE_ID" -p '#{session_name}' 2>/dev/null)
                [[ "$PANE_SESSION" == "$CURRENT_SESSION" ]] && continue
            fi
            echo " 🔥" && exit 0
        done
        ;;
esac
