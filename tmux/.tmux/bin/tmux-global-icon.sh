#!/bin/bash
# Show notification icon only for panes outside the current session
CURRENT_SESSION="${1:-}"

for f in /tmp/tmux-state*; do
    [[ ! -f "$f" ]] && continue
    PANE_ID="${f#/tmp/tmux-state}"
    if [[ -n "$CURRENT_SESSION" ]]; then
        PANE_SESSION=$(tmux display-message -t "$PANE_ID" -p '#{session_name}' 2>/dev/null)
        [[ "$PANE_SESSION" == "$CURRENT_SESSION" ]] && continue
    fi
    echo " 🟠" && exit 0
done
