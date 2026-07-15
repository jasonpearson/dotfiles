#!/bin/bash
# Format pane border title (left side).
# - SSH pane (pane command is ssh): title is "remote_path (hostname)" set by
#   the remote _set_title precmd hook — the OSC title escape is the only
#   channel that crosses the ssh boundary -> show remote path + hostname
# - Anything else: use pane_current_path (reliable; apps like claude code
#   override pane_title for their own status, which the border format
#   renders right-aligned instead)
#
# The path is the pill content; any ssh hostname renders OUTSIDE the pill. The
# pill's closing cap normally sits after this output in the border format,
# which would trap the host inside the pill, so for the active pane this script
# emits that closing cap itself and prints the host after it.
pane_id="$1"
pane_cmd="$2"
pane_active="$3"
[ -z "$pane_id" ] && exit 0

title=$(tmux display-message -p -t "$pane_id" '#{pane_title}' 2>/dev/null)
pane_path=$(tmux display-message -p -t "$pane_id" '#{pane_current_path}' 2>/dev/null)

# SSH pane whose title carries "remote_path (hostname)" from the remote precmd
if [ "$pane_cmd" = "ssh" ] && printf '%s' "$title" | grep -qE ' \([^()]+\)$'; then
    path=$(printf '%s' "$title" | sed 's/ ([^()]*)$//')
    host=$(printf '%s' "$title" | sed 's/.*(\([^()]*\))$/\1/' | sed 's/^jason-pearson-//')
else
    # Local/overridden pane: use tmux-tracked path (unaffected by app title overrides)
    # Note: ~ in replacement string would be tilde-expanded to $HOME (no-op), so use a variable
    tilde='~'
    path="${pane_path/#$HOME/$tilde}"
    # Fall back to cached SSH hostname (set by _set_title precmd) for tmux
    # servers running on a remote host
    host=$(tmux display-message -p -t "$pane_id" '#{@ssh_host}' 2>/dev/null)
fi

# Path = pill content. For the active pane, close the pill with its right cap
# ( in @lavender) so the host lands outside; inactive panes have no pill,
# so the border format renders this as plain overlay_2 text (no cap emitted).
printf '%s' "$path"
[ "$pane_active" = "1" ] && printf ' #[default]#[fg=%s]' "#{@lavender}"
[ -n "$host" ] && printf ' #[fg=%s]%s' "#{@peach}" "$host"
