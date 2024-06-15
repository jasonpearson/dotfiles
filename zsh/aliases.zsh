alias e="$EDITOR $1"
alias rs="$RUN_SCRIPT $1"
alias glo='git log --date=format:"%Y-%m-%d %H:%M %z" --pretty=format:"%h%x09%as%x09%ar%x09%an%x09%s"'
alias gac="git add -A && git commit -m $1"
alias gaca='git add -A && git commit --amend --no-edit'
alias gs='git status'
alias gd="git diff $1"
alias gp='git push'
alias gsu='git submodule update --init --recursive'
alias ll='ls -la'

function ed() {
  if [[ $# -eq 0 ]]; then
    files=$(git diff --name-only)
  else
    files=$(git diff --name-only --diff-filter=$1)
  fi

  echo $files | xargs nvim
}

function eg() { e $(rg -l $@) };
function ef() { e $(rg --files | rg $@) };
