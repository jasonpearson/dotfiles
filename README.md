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

## Codex config

Bootstrap runs `codex:config` after installing tools. The task updates only the keys in [`agents/codex/`](agents/codex/), preserving other settings and comments in `~/.codex/config.toml` (or `$CODEX_HOME/config.toml`). This also works on mise 2026.9.10, which doesn't support dotfile merge entries.

To reapply just those settings:

```sh
mise run codex:config           # tmux title and attention settings
mise -E macos run codex:config  # also select the generated Codex theme
```

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
