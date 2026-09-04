# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells.
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else.
[[ $- != *i* ]] && return

if [[ -n "${OMARCHY_PATH:-}" && -r "$OMARCHY_PATH/default/bash/rc" ]]; then
  # Keep Omarchy's default Bash experience on Omarchy/Arch.
  source "$OMARCHY_PATH/default/bash/rc"
else
  # Portable non-Omarchy Bash defaults for Ubuntu or other Linux systems.
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
  fi

  if [[ ${TERM:-} != "dumb" ]] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
  fi

  if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
  fi

  if command -v fzf >/dev/null 2>&1; then
    [[ -r /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [[ -r /usr/share/doc/fzf/examples/completion.bash ]] && source /usr/share/doc/fzf/examples/completion.bash
    [[ -r /usr/share/fzf/key-bindings.bash ]] && source /usr/share/fzf/key-bindings.bash
    [[ -r /usr/share/fzf/completion.bash ]] && source /usr/share/fzf/completion.bash
  fi
fi

# Tracked personal Bash customizations.
[[ -r ~/.config/bash/personal.bash ]] && source ~/.config/bash/personal.bash

# Machine-local Bash customizations. Keep this file out of git if it contains
# local settings or secrets.
[[ -r ~/.config/bash/local.bash ]] && source ~/.config/bash/local.bash
