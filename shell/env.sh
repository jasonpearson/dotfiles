# Shared Bash/Zsh environment. Activate mise in the calling shell.
for brew_bin in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done
unset brew_bin

[ ! -x "$HOME/.local/bin/mise" ] || export PATH="$HOME/.local/bin:$PATH"
case ":$PATH:" in
  *":$HOME/repos/k8s-start/bin:"*) ;;
  *) export PATH="$HOME/repos/k8s-start/bin:$PATH" ;;
esac

export EDITOR=nvim
