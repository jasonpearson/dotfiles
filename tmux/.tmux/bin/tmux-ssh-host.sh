#!/bin/sh
# Returns " (hostname)" if the pane is running an SSH session
pane_id="$1"
[ -z "$pane_id" ] && exit 0

pane_pid=$(tmux display-message -p -t "$pane_id" '#{pane_pid}' 2>/dev/null)
[ -z "$pane_pid" ] && exit 0

# Find ssh child process
ssh_pid=$(pgrep -P "$pane_pid" -x ssh 2>/dev/null | head -1)
[ -z "$ssh_pid" ] && exit 0

# Extract hostname from ssh command (last non-option argument)
host=$(ps -o args= -p "$ssh_pid" 2>/dev/null | awk '{print $NF}')
[ -z "$host" ] && exit 0

# Remove user@ prefix if present
host=${host##*@}

printf ' (%s)' "$host"
