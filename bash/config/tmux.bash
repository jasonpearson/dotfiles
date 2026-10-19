# Clear the terminal title at each prompt so tmux names the pane by directory.
_dotfiles_tmux_prompt_title() {
  local status=$?
  printf '\033]0;\007'
  return "$status"
}

if [[ $- == *i* && -n ${TMUX:-} ]]; then
  # Append after Starship, preserving existing hooks and avoiding duplicates.
  if [[ " ${PROMPT_COMMAND[*]} " != *" _dotfiles_tmux_prompt_title "* ]]; then
    PROMPT_COMMAND+=("_dotfiles_tmux_prompt_title")
  fi
fi
