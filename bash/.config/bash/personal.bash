# Shared personal Bash helpers.

alias tf=terraform

br() { bun run "$@"; }
cc() { claude "$@"; }
oc() { opencode "$@"; }

# Editor helpers
e() {
  local editor="${EDITOR:-nvim}"
  local -a editor_argv

  read -r -a editor_argv <<<"$editor"
  "${editor_argv[@]}" "$@"
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

# Git helpers. Avoid ga/gd here because Omarchy uses those for worktree helpers.
gadd() { git add "$@"; }
gdiff() { git diff "$@"; }
gac() { git add -A && git commit "$@"; }
gaca() { git add -A && git commit --amend "$@"; }
gb() { git branch "$@"; }
gc() { git commit "$@"; }
gco() { git checkout "$@"; }
glo() {
  git log --color --decorate --pretty=format:"%h %an %Cgreen(%cr)%Creset - %s%C(yellow)%d%Creset" --abbrev-commit "$@"
}
gp() { git push "$@"; }
gs() { git status "$@"; }
gw() { git worktree "$@"; }

ll() { ls -la "$@"; }

play_sound() {
  local file="${1:-}"

  if [[ -z "$file" ]]; then
    if [[ -f /System/Library/Sounds/Pop.aiff ]]; then
      file="/System/Library/Sounds/Pop.aiff"
    else
      printf '\a'
      return
    fi
  fi

  if command -v afplay >/dev/null 2>&1; then
    afplay "$file"
  elif command -v paplay >/dev/null 2>&1; then
    paplay "$file"
  elif command -v aplay >/dev/null 2>&1; then
    aplay "$file"
  fi
}

tma() { tmux attach "$@"; }
tml() { tmux list-sessions "$@"; }
