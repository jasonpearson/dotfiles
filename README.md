# Dotfiles

With this repo checked out at `~/repos/dotfiles`, link its mise configuration:

```sh
mkdir -p ~/.config
ln -s ~/repos/dotfiles/mise ~/.config/mise
```

From your home directory, bootstrap with the environment for your OS:

```sh
mise -E arch bootstrap    # Arch / Omarchy
mise -E macos bootstrap   # macOS
```

mise always loads `mise/config.toml`, plus `mise/config.<env>.toml` for each explicitly selected environment. It does not select the OS environment automatically.

The base config renders `~/.claude/settings.json` and `~/.codex/hooks.json` from the [tmux-attention hook fragments](tmux/) and, for Claude, [its base settings](agents/claude/settings.json). Pi gets its standalone tmux-attention extension. The renderer uses mise's configured Python; no separate Python install is needed.

## Bash and Zsh

Bash and macOS Zsh load the same [shell aliases and helpers](shell/). Bootstrap installs `eza` and `fzf` on both platforms. `ls` uses eza's icons and directory-first listing, and **Ctrl+R** opens fzf's history picker. Use `command ls` for the system listing. tmux still starts Bash.

On macOS, back up any existing `~/.zshrc` before deploying the repo's [Zsh config](zsh/zshrc). It activates mise, Starship, and zoxide natively without sourcing Bash.


## Moshi (optional, per machine)

On computers where you want Moshi, add its environment to bootstrap:

```sh
mise -E arch,moshi bootstrap
mise -E macos,moshi bootstrap
```

Selecting [`mise/config.moshi.toml`](mise/config.moshi.toml) tells the same templates to append the [Moshi hook fragments](moshi/) after the tmux-attention hooks, and deploys the optional Pi extension. It does not install the Moshi binary, pair the machine, or start the service. On a machine you intend to pair, [install and pair `moshi-hook`](https://getmoshi.app/docs/hooks), but skip `moshi-hook install`: mise manages the agent hooks.

After bootstrap, only the Moshi environment is needed for the task:

```sh
mise -E moshi run moshi status
mise -E moshi run moshi on
mise -E moshi run moshi off
```

The hooks are off by default. `on` starts the service and enables the hooks; `off` disables the hooks and stops the managed service without removing the integration. Restart Claude or Codex after deploying hook changes, or run `/reload` in Pi. Reload a running Pi after turning Moshi on.
