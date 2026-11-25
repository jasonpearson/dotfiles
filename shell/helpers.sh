# Interactive aliases and functions shared by Bash and Zsh.
if command -v eza >/dev/null 2>&1; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias ll='ls -a'
else
  alias ll='ls -lah'
fi

alias t='tmux-attention'
tl() { tmux list-sessions "$@"; }

br() { bun run "$@"; }
alias cc='claude'
alias cl='mise exec -- claude'
alias co='mise exec -- codex'
alias hd='hunk diff'
alias ks='k8s-start'
oc() { opencode "$@"; }

# Git helpers
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
