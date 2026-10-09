#!/usr/bin/env bash
# Offline, isolated headless tests. Requires Neovim and an existing lazy.nvim.
# --integration additionally exercises locally installed, unmodified themes.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
plugin_root=${NVIM_THEME_PLUGIN_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy}
lazy=${LAZY_NVIM_PATH:-$plugin_root/lazy.nvim}
if [[ ! -f $lazy/lua/lazy/init.lua ]]; then
  printf 'Set LAZY_NVIM_PATH to an existing lazy.nvim checkout (no downloads).\n' >&2
  exit 1
fi
integration=0
if [[ ${1:-} == --integration ]]; then
  integration=1
elif [[ $# != 0 ]]; then
  printf 'Usage: %s [--integration]\n' "$0" >&2
  exit 1
fi
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/bin"
printf '#!/bin/sh\necho "Unexpected git invocation in theme test" >&2\nexit 97\n' > "$scratch/bin/git"
chmod +x "$scratch/bin/git"
for scenario in osaka-jade manual ethereal fallback runtime native invalid; do
  home=$scratch/$scenario
  mkdir -p "$home"/{.config,config/nvim,data,state,cache}
  ln -s "$repo/starship/starship.toml" "$home/.config/starship.toml"
  env -u NVIM_APPNAME -u VIMINIT -u EXINIT -u GVIMINIT \
    HOME="$home" XDG_CONFIG_HOME="$home/config" XDG_DATA_HOME="$home/data" \
    XDG_STATE_HOME="$home/state" XDG_CACHE_HOME="$home/cache" \
    XDG_CONFIG_DIRS="$home/config" XDG_DATA_DIRS="$home/data" \
    NVIM_LOG_FILE="$home/nvim.log" PATH="$scratch/bin:$PATH" \
    NVIM_THEME_REPO="$repo" NVIM_THEME_LAZY="$lazy" \
    NVIM_THEME_PLUGIN_ROOT="$plugin_root" NVIM_THEME_INTEGRATION="$integration" \
    NVIM_THEME_SCENARIO="$scenario" \
    nvim --headless -i NONE -u "$repo/tests/nvim-theme.lua"
done
