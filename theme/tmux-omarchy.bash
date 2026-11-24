#!/usr/bin/env bash

tmux_command=(tmux)
if [[ ${1:-} == --socket ]]; then
  tmux_command+=(-S "$2")
else
  [[ -n $("${tmux_command[@]}" show-options -gqv @theme_accent 2>/dev/null) ]] || exit 0
fi

accent=$(omarchy-theme-color --file "$HOME/.local/state/omarchy/current/theme/colors.toml" accent) || exit 1
[[ $accent =~ ^#[[:xdigit:]]{6}$ ]] || exit 1
"${tmux_command[@]}" set-option -g @theme_accent "$accent"
