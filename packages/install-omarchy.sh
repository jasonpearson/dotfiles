#!/usr/bin/env bash
set -euo pipefail

omarchy pkg add \
  bun-bin \
  ghostty \
  kind \
  opencode \
  shellcheck \
  stow \
  wget \
  yq

omarchy pkg aur add \
  tpack-bin
