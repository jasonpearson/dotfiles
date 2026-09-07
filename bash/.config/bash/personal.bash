alias tf=terraform
alias t='tmux attach || tmux new -s "$PWD"'

tl() { tmux list-sessions "$@"; }

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

for tmux_attention_bin in "$HOME"/.tmux/plugins/tmux-attention*/bin; do
  [[ -d "$tmux_attention_bin" ]] || continue
  case ":$PATH:" in
    *":$tmux_attention_bin:"*) ;;
    *) export PATH="$tmux_attention_bin:$PATH" ;;
  esac
done
unset tmux_attention_bin

if command -v tmux-attention >/dev/null 2>&1; then
  alias ta='tmux-attention'
  alias tac='tmux-attention new "$PWD"'
fi

if [[ -n "${HERDR_PANE_ID:-}" && -z "${TMUX:-}" ]]; then
  _herdr_focus_left() { herdr pane focus --current --direction left >/dev/null 2>&1; }
  _herdr_focus_down() { herdr pane focus --current --direction down >/dev/null 2>&1; }
  _herdr_focus_up() { herdr pane focus --current --direction up >/dev/null 2>&1; }
  _herdr_focus_right() { herdr pane focus --current --direction right >/dev/null 2>&1; }

  bind -x '"\C-h": _herdr_focus_left'
  bind -x '"\C-j": _herdr_focus_down'
  bind -x '"\C-k": _herdr_focus_up'
  bind -x '"\C-l": _herdr_focus_right'

  bind -x '"\e[104;5u": _herdr_focus_left'
  bind -x '"\e[106;5u": _herdr_focus_down'
  bind -x '"\e[107;5u": _herdr_focus_up'
  bind -x '"\e[108;5u": _herdr_focus_right'
fi
