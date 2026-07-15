#!/bin/bash
# Current git branch for the tmux status line. Fed the active pane's path from
# status-right, so it reflects the focused pane. Prints nothing outside a repo,
# and falls back to a short SHA for detached HEAD so it never blanks mid-rebase.
# Literal  glyph (U+E0A0) rather than printf \u — macOS ships bash 3.2.
dir="$1"
[ -z "$dir" ] && exit 0

branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null) \
  || branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null) \
  || exit 0

[ -n "$branch" ] && printf '  %s ' "$branch"
