# Dotfiles

Dotfiles and tool versions are managed by [mise](https://mise.jdx.dev/), with
configuration in [`mise/config.toml`](mise/config.toml).

## New computer setup

Clone this repository to `~/repos/dotfiles` (or adjust the paths below to match
your checkout), then [install mise](https://mise.jdx.dev/getting-started.html#_1-install-mise-cli).
On macOS or Linux, the installer places the executable at `~/.local/bin/mise`:

```sh
curl https://mise.run | sh
```

Run `mise bootstrap` using the repository's config directly, before the global
config symlink or shell activation exists. This installs the configured system
packages and versioned tools, and applies the dotfiles:

```sh
MISE_GLOBAL_CONFIG_FILE="$HOME/repos/dotfiles/mise/config.toml" \
  "$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" bootstrap
```

Append `--dry-run` to preview the changes. `MISE_GLOBAL_CONFIG_FILE` only applies
to this command; there is no need to export it permanently. After bootstrapping,
start a new Bash session to load the managed shell configuration.

To apply only the dotfiles, replace `bootstrap` with `dot apply` in the command
above.

## Everyday use

With the dotfiles applied and mise available in your shell:

```sh
mise dot status
mise dot apply --dry-run
mise dot apply
```

## Recover after unapplying everything

`mise dot unapply` removes the managed links, including shell startup files and
`~/.config/mise/config.toml`. It leaves the repository's source files and the
installed mise executable at `~/.local/bin/mise` in place.

To restore just the links, use the existing checkout and mise installation:

```sh
MISE_GLOBAL_CONFIG_FILE="$HOME/repos/dotfiles/mise/config.toml" \
  "$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" dot apply
```

Then start a new Bash session to load the managed shell configuration.

For a deliberate full unapply/reapply cycle, run that same command with
`dot unapply` first, then run it again with `dot apply`.

Verified with mise 2026.9.12 using status and apply/unapply dry runs with
`PATH=/usr/bin:/bin` and an empty `MISE_CONFIG_DIR`.

See mise's documentation for
[`mise bootstrap`](https://mise.jdx.dev/bootstrap.html),
[`MISE_GLOBAL_CONFIG_FILE`](https://mise.jdx.dev/configuration.html#mise-global-config-file),
and [dotfiles management](https://mise.jdx.dev/dotfiles.html).
