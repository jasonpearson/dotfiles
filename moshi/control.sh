#!/bin/sh
# Machine-local preference and existing background service. Never pair or install hooks.
set -eu

usage() {
  printf 'Usage: mise moshi [on|off|status]\n' >&2
  exit 2
}

[ "$#" -le 1 ] || usage
preference_dir="$HOME/.config/moshi"
service_script="$preference_dir/service.py"

service() {
  python3 "$service_script" "$1"
}

show_status() {
  if [ "${DOTFILES_MOSHI_DISABLED:-}" = 1 ]; then
    printf 'Moshi hooks: off (DOTFILES_MOSHI_DISABLED=1).\n'
  elif [ -e "$preference_dir/disabled" ]; then
    printf 'Moshi hooks: off (machine preference).\n'
  elif [ -e "$preference_dir/enabled" ]; then
    printf 'Moshi hooks: on (machine preference).\n'
  else
    printf 'Moshi hooks: off (default).\n'
  fi
  service status
}

case "${1-status}" in
  on)
    if [ "${DOTFILES_MOSHI_DISABLED:-}" = 1 ]; then
      printf 'Cannot enable Moshi while DOTFILES_MOSHI_DISABLED=1.\n' >&2
      exit 1
    fi
    umask 077
    mkdir -p "$preference_dir"
    # Keep hooks closed if service startup or the final preference write fails.
    touch "$preference_dir/disabled"
    rm -f "$preference_dir/enabled"
    service on
    if ! { touch "$preference_dir/enabled" && rm -f "$preference_dir/disabled"; }; then
      service off
      exit 1
    fi
    show_status
    printf 'Reload a running Pi with /reload to register its Moshi hooks.\n'
    ;;
  off)
    umask 077
    mkdir -p "$preference_dir"
    touch "$preference_dir/disabled"
    rm -f "$preference_dir/enabled"
    service off
    show_status
    ;;
  status)
    show_status
    ;;
  *) usage ;;
esac
