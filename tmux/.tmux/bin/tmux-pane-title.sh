#!/bin/bash
# Format pane border title.
# - SSH pane: title is "remote_path (hostname)" set by _set_title precmd hook
#             -> show remote path + hostname in red
# - Local pane: use pane_current_path (reliable; not affected by app title overrides)
#             -> show tilde-shortened path
pane_id="$1"
[ -z "$pane_id" ] && exit 0

title=$(tmux display-message -p -t "$pane_id" '#{pane_title}' 2>/dev/null)
pane_path=$(tmux display-message -p -t "$pane_id" '#{pane_current_path}' 2>/dev/null)

# SSH pane: title ends with " (hostname)"
if printf '%s' "$title" | grep -qE ' \([^()]+\)$'; then
    path=$(printf '%s' "$title" | sed 's/ ([^()]*)$//')
    host=$(printf '%s' "$title" | sed 's/.*(\([^()]*\))$/\1/' | sed 's/^jason-pearson-//')
    printf '%s #[fg=%s]%s' "$path" "#{@thm_peach}" "$host"
else
    # Local/overridden pane: use tmux-tracked path (unaffected by app title overrides)
    # Note: ~ in replacement string would be tilde-expanded to $HOME (no-op), so use a variable
    tilde='~'
    path="${pane_path/#$HOME/$tilde}"
    # Fall back to cached SSH hostname (set by _set_title precmd) in case title was overridden
    ssh_host=$(tmux display-message -p -t "$pane_id" '#{@ssh_host}' 2>/dev/null)
    if [ -n "$ssh_host" ]; then
        printf '%s #[fg=%s]%s' "$path" "#{@thm_peach}" "$ssh_host"
    else
        printf '%s' "$path"
    fi
fi
