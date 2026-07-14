#!/bin/bash
# Sets pane-border-format.
# Left:  path + optional ssh host from tmux-pane-title.sh (the shell sets the
#        terminal title via the _set_title precmd hook)
# Right: #{pane_title} when a program in the pane set it to something the
#        shell would not (e.g. claude code's task summary). Pure format, no
#        #() job: job output is cached a redraw behind (see tmux-attention).

# pane_current_path with $HOME shortened to ~ (mirrors _set_title's %~)
tilde_path='#{s|'"$HOME"'|~|:pane_current_path}'

# A title is interesting when it is not tmux's default (the local hostname),
# not the shell-set path, and not from an ssh pane (there the title is the
# remote "path (host)" and belongs to the left side).
interesting='#{&&:#{!=:#{pane_title},#{host}},#{&&:#{!=:#{pane_title},'"$tilde_path"'},#{!=:#{pane_current_command},ssh}}}'

left="#{attention_pane}#{?pane_active,#[default]#[fg=#{@lavender}]#[bg=default]#[fg=#{@crust}]#[bg=#{@lavender}] ,#[fg=#{@overlay_2}]}#(~/.tmux/bin/tmux-pane-title.sh '#{pane_id}' '#{pane_current_command}')#{?pane_active, #[default]#[fg=#{@lavender}],}"
right='#[align=right]#[default]#{?'"$interesting"', #[fg=#{@overlay_1}]#{=/40/…:pane_title} ,}'

tmux set -g pane-border-format " $left $right"
