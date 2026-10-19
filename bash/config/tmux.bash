# Clear an agent's OSC title on return to the shell, even after a crash or
# Ctrl+Z. The tmux pane-title-changed hook then rechecks all panes in the window.
# No subprocesses and no directory/title quoting needed: tmux reads cwd itself.
_dotfiles_tmux_prompt_title() {
  local status=$?
  printf '\033]0;\007'
  return "$status"
}

if [[ $- == *i* && -n ${TMUX:-} ]]; then
  # Append after Starship; preserve string or array PROMPT_COMMAND and avoid
  # installing twice when .bashrc is sourced again. Managed Bash supports arrays.
  if [[ " ${PROMPT_COMMAND[*]} " != *" _dotfiles_tmux_prompt_title "* ]]; then
    PROMPT_COMMAND+=("_dotfiles_tmux_prompt_title")
  fi
fi
