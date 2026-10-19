for brew_bin in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew /usr/local/bin/brew; do
  if [[ -x "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done
unset brew_bin

[[ -x "$HOME/.local/bin/mise" ]] && export PATH="$HOME/.local/bin:$PATH"
case ":$PATH:" in
  *":$HOME/repos/k8s-start/bin:"*) ;;
  *) export PATH="$HOME/repos/k8s-start/bin:$PATH" ;;
esac
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
eval "$(starship init bash)"
eval "$(zoxide init bash)"
export EDITOR=nvim

# Vi-style prompt editing.
if [[ $- == *i* ]]; then
  set -o vi
  bind -m vi-insert '"kj": vi-movement-mode'
  bind 'set keyseq-timeout 200'
fi

br() { bun run "$@"; }
alias cc='claude'
alias cl='mise exec -- claude'
alias co='mise exec -- codex'
alias hd='hunk diff'
alias ks='k8s-start'
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
ga() { git add "$@"; }
gd() { git diff "$@"; }
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

ll() { ls -lah "$@"; }
