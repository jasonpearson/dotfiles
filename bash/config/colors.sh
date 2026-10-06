# Shared palette bridge. Only startup/manual apply invokes Python; the prompt
# callback uses Bash builtins and rereads the small, atomically generated file.
# Match mise's explicit ~/.config destinations, even with a custom XDG value.
_dotfiles_theme_config="$HOME/.config/dotfiles/theme"
_dotfiles_theme_cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/theme"

dotfiles_theme_apply() {
  python3 "$_dotfiles_theme_config/apply.py" "$@"
}

_dotfiles_theme_readline() {
  [[ $- == *i* ]] || return 0
  local color="${STARSHIP_PROMPT_ACCENT:-}" arrow
  if [[ $color =~ ^#[0-9a-fA-F]{6}$ ]]; then
    printf -v arrow '\\1\\e[38;2;%d;%d;%dm\\2❯\\1\\e[0m\\2' \
      "0x${color:1:2}" "0x${color:3:2}" "0x${color:5:2}"
  else
    arrow='\1\e[34m\2❯\1\e[0m\2'
  fi
  bind "set vi-ins-mode-string \"$arrow\""
  color="${THEME_ERROR:-}"
  if [[ $color =~ ^#[0-9a-fA-F]{6}$ ]]; then
    printf -v arrow '\\1\\e[38;2;%d;%d;%dm\\2❮\\1\\e[0m\\2' \
      "0x${color:1:2}" "0x${color:3:2}" "0x${color:5:2}"
  else
    arrow='\1\e[31m\2❮\1\e[0m\2'
  fi
  bind "set vi-cmd-mode-string \"$arrow\""
}

_dotfiles_theme_read() {
  local content
  [[ -r "$_dotfiles_theme_cache/colors.sh" ]] || return 0
  content=$(<"$_dotfiles_theme_cache/colors.sh")
  if [[ $content != "${_dotfiles_theme_last_colors:-}" ]]; then
    # This is our validated/generated cache, not a downloaded theme script.
    # shellcheck disable=SC1091
    source "$_dotfiles_theme_cache/colors.sh"
    _dotfiles_theme_last_colors=$content
    _dotfiles_theme_readline
  fi
  [[ ! -r "$_dotfiles_theme_cache/starship.toml" ]] ||
    export STARSHIP_CONFIG="$_dotfiles_theme_cache/starship.toml"
}

_dotfiles_theme_return() { return "$1"; }
_dotfiles_theme_precmd() {
  local status=$?
  _dotfiles_theme_read
  if [[ -n ${_dotfiles_theme_previous_precmd:-} ]]; then
    _dotfiles_theme_return "$status"
    "$_dotfiles_theme_previous_precmd"
  fi
  return "$status"
}

_dotfiles_theme_install_prompt_hook() {
  # Install after local.bash, preserving its callback and avoiding self-chains
  # when .bashrc is sourced again. Starship preserves command/pipeline status.
  if [[ ${starship_precmd_user_func:-} != _dotfiles_theme_precmd ]]; then
    _dotfiles_theme_previous_precmd=${starship_precmd_user_func:-}
    starship_precmd_user_func=_dotfiles_theme_precmd
  fi
}

# A missing/broken renderer must not prevent a shell opening. Existing cache
# remains usable; without one Starship/tmux have ANSI fallbacks.
# Omarchy runs its app hooks in parallel noninteractive login shells. Do not
# render once per app; its single theme-set hook handles that transition.
if [[ $- == *i* && -r "$_dotfiles_theme_config/apply.py" ]]; then
  dotfiles_theme_apply --no-reload || true
fi
_dotfiles_theme_read
