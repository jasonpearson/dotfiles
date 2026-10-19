# Repository guidance

## Configuration changes

- Edit tracked sources and deployment mappings in `mise/config.toml`. Before
  touching live files under `$HOME` or `$XDG_CONFIG_HOME`, resolve symlinks and
  check the mappings; not every local configuration file is managed here.
- Manage only the files or keys needed. Preserve unrelated local settings, add
  OS guards where needed, and keep credentials, caches, and generated state out
  of Git.
- Treat live diagnostic edits as temporary. Make fixes reproducible through the
  repository, or identify local-only changes and agree on follow-up. If the user
  asks for a portability plan first, discuss it before applying changes.
- Preview with `mise dot apply --dry-run` and apply only the intended targets.
  Verify deployed files and effective application settings. Report platform
  support, required reloads, and any remaining local-only changes.

## Layout

- App directories contain deployment sources; `mise/config.toml` defines their
  destinations and tool versions.
- `theme/` renders shared palettes into the local cache. Omarchy supplies its
  active palette through `omarchy/themed/` and `omarchy/hooks/theme-set.d/`.
- `agents/` holds agent settings, extensions, shared instructions, and skills.
- `tests/` covers deployment, themes, clipboard behavior, navigation, and hooks.

## Validation

Run relevant checks from the repository root:

```sh
mise exec -- python3 -m unittest discover -s tests -v
mise exec -- node --test tests/*.test.mjs
mise exec -- bash tests/nvim-theme.sh
```

Tests use temporary homes and private tmux servers. Neovim theme tests require
an installed `lazy.nvim`; add `--integration` to exercise installed theme plugins.

### Pi extensions

mise links `agents/pi/` into `~/.pi/agent/` file by file. After adding or renaming
files, preview and apply the `~/.pi/agent` target. Test extensions from their
installed paths, for example:

```sh
pi -p -ne --no-session --model bogus/bogus-model -e ~/.pi/agent/extensions/tmux-attention.ts hi
```

Expect a model-not-found error and no extension load errors. This makes no paid
call. `pi --help -e <file>` does not validate extension loading. Use `/reload` in
Pi to load edits.
