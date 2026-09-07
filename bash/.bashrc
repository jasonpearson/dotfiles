# Omarchy defaults.
[[ -r /usr/share/omarchy/default/bash/rc ]] && source /usr/share/omarchy/default/bash/rc

# If not running interactively, don't do anything else.
[[ $- != *i* ]] && return

# Tracked personal Bash customizations.
[[ -r ~/.config/bash/personal.bash ]] && source ~/.config/bash/personal.bash

# Machine-local Bash customizations. Keep this file out of git if it contains
# local settings or secrets.
[[ -r ~/.config/bash/local.bash ]] && source ~/.config/bash/local.bash
