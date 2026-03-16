#!/bin/sh
# Sets pane-border-format with $HOME expanded for ~ substitution
tmux set -g pane-border-format "#{?pane_active,#[fg=#{@thm_red}] ● , }#{?pane_active,#[fg=#{@thm_teal}],#[fg=#{@thm_lavender}]}#{s|$HOME|~|:pane_current_path}#[fg=#{@thm_red}]#(~/.tmux/bin/tmux-ssh-host.sh #{pane_id}) "
