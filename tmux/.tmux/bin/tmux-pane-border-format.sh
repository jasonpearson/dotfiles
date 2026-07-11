#!/bin/bash
# Sets pane-border-format. Shell sets terminal title via _set_title precmd hook:
# - SSH pane: "path (hostname)"  -> rendered with hostname in red
# - Local pane: "path"
tmux set -g pane-border-format "#{?pane_active,#[fg=#{@red}] ● , }#{?pane_active,#[fg=#{@teal}],#[fg=#{@lavender}]}#{attention_pane}#(~/.tmux/bin/tmux-pane-title.sh #{pane_id}) "
