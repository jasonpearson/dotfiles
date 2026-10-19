#!/bin/sh
# Portable Claude/Codex hook adapter. Keep this policy in sync with moshi-hooks.ts.
# Deliberately use ~/.config, matching mise's explicit deployment paths.
# Explicit disable always wins; otherwise require a machine-local opt-in.
if [ "${DOTFILES_MOSHI_DISABLED:-}" = 1 ] || [ -e "$HOME/.config/moshi/disabled" ]; then
  exit 0
fi
if [ ! -e "$HOME/.config/moshi/enabled" ]; then
  exit 0
fi

# Honor the caller's PATH, then cover non-interactive shells with a minimal PATH.
if command -v moshi-hook >/dev/null 2>&1; then
  exec moshi-hook "$@"
fi
for binary in "$HOME/.local/bin/moshi-hook" /opt/homebrew/bin/moshi-hook \
  /usr/local/bin/moshi-hook /opt/local/bin/moshi-hook "$HOME/bin/moshi-hook"; do
  if [ -x "$binary" ]; then
    exec "$binary" "$@"
  fi
done

# Moshi is optional. Missing binaries must not break ordinary agent use.
exit 0
