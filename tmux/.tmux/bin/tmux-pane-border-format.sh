#!/bin/bash
# Sets pane-border-format as a pure format expression — no #() job. Job output
# is cached a redraw behind and refresh-client -S never repaints borders (see
# tmux-attention), so the old tmux-pane-title.sh job lagged a `cd` by a redraw;
# a format renders the current path on every border repaint.
#
# Left:  path inside a pill, plus an ssh host rendered OUTSIDE the pill.
#        - ssh pane whose title is "remote_path (host)" (set across the ssh
#          boundary by the remote _set_title precmd): split title into path + host.
#        - otherwise: pane_current_path (~-shortened), and @ssh_host (set by
#          _set_title when tmux itself runs on a remote box) as the host.
# Right: #{pane_title} when a program set it to something the shell would not
#        (e.g. claude code's task summary).

# Powerline pill caps and the truncation ellipsis, by octal so this file stays
# pure ASCII (bash 3.2 has no $'\uXXXX').
LCAP=$(printf '\356\202\266')   # U+E0B6
RCAP=$(printf '\356\202\264')   # U+E0B4
ELL=$(printf '\342\200\246')    # U+2026

# An ssh pane whose title carries "remote_path (host)".
ssh_t='#{&&:#{==:#{pane_current_command},ssh},#{m:* (*),#{pane_title}}}'
# Path in the pill: the ssh title minus " (host)", else the ~-shortened cwd.
path='#{?'"$ssh_t"',#{s| \([^()]*\)$||:pane_title},#{s|'"$HOME"'|~|:pane_current_path}}'
# Host outside the pill: the ssh title's "(host)", else the @ssh_host fallback;
# the jason-pearson- prefix stripped either way.
host='#{s|jason-pearson-||:#{?'"$ssh_t"',#{s|^.*\(([^()]*)\)$|\1|:pane_title},#{@ssh_host}}}'

# A title is interesting on the right only when it is not tmux's default (the
# hostname), not the shell-set path, and not an ssh pane (whose title belongs on
# the left). The trimmed _set_title no longer writes the local path into the
# title, so the path clause is a harmless guard for panes whose shells predate
# that change — it keeps them from showing the path on both sides.
tilde_path='#{s|'"$HOME"'|~|:pane_current_path}'
interesting='#{&&:#{!=:#{pane_title},#{host}},#{&&:#{!=:#{pane_title},'"$tilde_path"'},#{!=:#{pane_current_command},ssh}}}'

# Active pane: path in a teal pill (crust text) closed by the cap; inactive: a
# plain lavender path. The host, when present, follows outside the pill.
left="#{attention_pane}#{?pane_active,#[default]#[fg=#{@teal}]#[bg=default]${LCAP}#[fg=#{@crust}]#[bg=#{@teal}] ${path} #[default]#[fg=#{@teal}]${RCAP},#[fg=#{@lavender}]${path}}#{?${host}, #[fg=#{@red}]${host},}"
right="#[align=right]#[default]#{?${interesting}, #[fg=#{@lavender}]#{=/40/${ELL}:pane_title} ,}"

tmux set -g pane-border-format " $left $right"
