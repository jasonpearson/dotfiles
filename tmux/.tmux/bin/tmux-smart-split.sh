#!/bin/bash
# Open a new pane or window; if the current pane is running ssh, start the new
# one with the same ssh command (and remote cwd) instead of a local shell.
# Usage: tmux-smart-split.sh <-h|-v|-w> <pane_id>   (-w = new window)
direction="$1"
pane_id="$2"
[ -z "$pane_id" ] && exit 0

# new-window's -t only accepts a window target, not a pane id
case "$direction" in
    -w) open=(new-window -a)
        target=$(tmux display-message -p -t "$pane_id" '#{window_id}') ;;
    *)  open=(split-window "$direction")
        target="$pane_id" ;;
esac

# Walk the pane's process tree looking for an ssh process; print its full
# command line (user, host, port, flags all preserved).
find_ssh() {
    local pid="$1" cmd child
    cmd=$(ps -o command= -p "$pid" 2>/dev/null)
    case "$cmd" in
        ssh\ *|*/ssh\ *) printf '%s' "$cmd"; return 0 ;;
    esac
    for child in $(pgrep -P "$pid" 2>/dev/null); do
        find_ssh "$child" && return 0
    done
    return 1
}

pane_pid=$(tmux display-message -p -t "$pane_id" '#{pane_pid}')
pane_cmd=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')
pane_path=$(tmux display-message -p -t "$pane_id" '#{pane_current_path}')

if [ "$pane_cmd" = "ssh" ] && ssh_cmd=$(find_ssh "$pane_pid"); then
    # Follow the remote cwd: _set_title on the remote sets pane_title to
    # "remote_path (hostname)". ssh stops option parsing at the hostname, so
    # -t must be injected after "ssh", not appended.
    title=$(tmux display-message -p -t "$pane_id" '#{pane_title}')
    if printf '%s' "$title" | grep -qE ' \([^()]+\)$'; then
        rpath=$(printf '%s' "$title" | sed 's/ ([^()]*)$//')
        rpath="${rpath/#\~/\$HOME}"
        tmux "${open[@]}" -t "$target" \
            "${ssh_cmd/ssh /ssh -t } 'cd \"$rpath\" 2>/dev/null; exec \"\$SHELL\" -l'"
    else
        tmux "${open[@]}" -t "$target" "$ssh_cmd"
    fi
elif [ "$direction" = "-w" ]; then
    # local new-window keeps its original behavior: session start directory
    tmux "${open[@]}" -t "$target"
else
    tmux "${open[@]}" -t "$target" -c "$pane_path"
fi
