#!/bin/sh
# Claude/Codex hook opt-in policy; keep in sync with agents/pi/extensions/moshi-hooks.ts.
# Paths match mise's ~/.config targets. Explicit disable takes precedence.
if [ "${DOTFILES_MOSHI_DISABLED:-}" = 1 ] || [ -e "$HOME/.config/moshi/disabled" ]; then
  exit 0
fi
if [ ! -e "$HOME/.config/moshi/enabled" ]; then
  exit 0
fi

# Search PATH, then common install locations for noninteractive shells.
if command -v moshi-hook >/dev/null 2>&1; then
  exec moshi-hook "$@"
fi
for binary in "$HOME/.local/bin/moshi-hook" /opt/homebrew/bin/moshi-hook \
  /usr/local/bin/moshi-hook /opt/local/bin/moshi-hook "$HOME/bin/moshi-hook"; do
  if [ -x "$binary" ]; then
    exec "$binary" "$@"
  fi
done

# Missing Moshi is a no-op.
exit 0
