#!/bin/sh
# Hides pane border status if single pane and no Claude Code running
# Usage: tmux-pane-border.sh <window_id>
sleep 0.2
win="$1"
panes=$(tmux list-panes -t "$win" 2>/dev/null | wc -l)
claude=$(tmux list-panes -t "$win" -F '#{@claude_pane}' 2>/dev/null | grep -c 1)
[ "$panes" -le 1 ] && [ "$claude" -eq 0 ] && tmux set -t "$win" pane-border-status off
exit 0
