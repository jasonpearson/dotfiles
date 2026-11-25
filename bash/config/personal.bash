[[ -r ~/.config/dotfiles/shell/env.sh ]] && source ~/.config/dotfiles/shell/env.sh
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
if [[ -r ~/.config/dotfiles/theme/colors.bash ]]; then
  source ~/.config/dotfiles/theme/colors.bash
elif [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/starship-omarchy.toml" ]]; then
  export STARSHIP_CONFIG="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/starship-omarchy.toml"
elif [[ ${STARSHIP_CONFIG:-} == "${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/theme/starship.toml" ]]; then
  # Drop a generated config inherited from a shell using the old deployment.
  unset STARSHIP_CONFIG
fi
eval "$(starship init bash)"
eval "$(zoxide init bash)"
if [[ $- == *i* ]]; then
  shopt -s histappend
  HISTCONTROL=ignoreboth
  HISTSIZE=32768
  HISTFILESIZE=$HISTSIZE

  # Vi-style prompt editing.
  set -o vi
  bind -m vi-insert '"kj": vi-movement-mode'
  bind 'set keyseq-timeout 200'

  # Readline redraws the mode arrow without rerunning Starship.
  bind 'set show-mode-in-prompt on'
  if declare -F _dotfiles_theme_readline >/dev/null; then
    _dotfiles_theme_readline
  else
    bind 'set vi-ins-mode-string "\1\e[34m\2❯\1\e[0m\2"'
    bind 'set vi-cmd-mode-string "\1\e[31m\2❮\1\e[0m\2"'
  fi

  # fzf supplies Ctrl+R in both Readline vi modes.
  if command -v fzf >/dev/null 2>&1; then
    FZF_CTRL_T_COMMAND= FZF_ALT_C_COMMAND= source <(fzf --bash)
  fi

  [[ -r ~/.config/dotfiles/shell/helpers.sh ]] && source ~/.config/dotfiles/shell/helpers.sh
fi

# Bash-specific editor helpers
e() {
  local editor="${EDITOR:-nvim}"
  local -a editor_argv

  read -r -a editor_argv <<<"$editor"
  "${editor_argv[@]}" "$@"
}

ed() {
  local -a files=()

  mapfile -t files < <(git diff --name-only --diff-filter=d -- "$@")

  e "${files[@]}"
}

ef() {
  local file
  file=$(fzf) || return
  [[ -n "$file" ]] || return
  e "$file"
}

eg() {
  local -a files=()
  mapfile -t files < <(rg -l "$@")
  ((${#files[@]})) || return 1
  e "${files[@]}"
}

egf() {
  local -a files=()
  mapfile -t files < <(rg -u --files | rg "$@")
  ((${#files[@]})) || return 1
  e "${files[@]}"
}
