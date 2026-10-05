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

Run `mise bootstrap` from the repository root, before the global config symlink
or shell activation exists. Mise discovers [`mise/config.toml`](mise/config.toml)
there. This installs the configured system packages and versioned tools, and
applies the dotfiles:

```sh
"$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" bootstrap
```

Append `--dry-run` to preview the changes. `-C` takes the checkout directory, not
the config file path. After bootstrapping, start a new Bash session to load the
managed shell configuration.

To apply only the dotfiles, replace `bootstrap` with `dot apply` in the command
above.

## Everyday use

To add or update agent skills, see [Agent skills](#agent-skills).

With the dotfiles applied and mise available in your shell:

```sh
mise dot status
mise dot apply --dry-run
mise dot apply
```

To reapply just one target, pass its configured path. For example:

```sh
mise dot unapply '~/.agents/skills/hunk-review'
mise dot apply '~/.agents/skills/hunk-review'
```

## Personal agent instructions

[`agents/global-instructions.md`](agents/global-instructions.md) is the shared
personal policy, including host-specific browser tool selection. Mise links it to
`~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, and `~/.pi/agent/AGENTS.md`.
Edit that one source rather than maintaining separate host copies. Its neutral
filename avoids making it nested repository instructions under `agents/`;
root `AGENTS.md` remains specific to this repository.

## Agent skills

Run the commands below from the dotfiles repository root. CLI imports live in
Git-ignored `.agents/skills/`, separate from the curated skills deployed by mise
from `agents/`. The root `skills-lock.json` records local import metadata and is
also Git-ignored.

Some agents may discover `.agents/skills/` while working in this repository even
though it is Git-ignored; importing a skill can make it available locally before
you choose to deploy it globally.

### Add or update a skill

1. Ensure the Skills CLI is installed:

   ```sh
   mise install npm:skills
   ```

2. Import a skill. For example:

   ```sh
   skills add mattpocock/skills --skill tdd --agent universal --yes
   ```

   This downloads it into `.agents/skills/` and updates `skills-lock.json`. Run
   the same command to refresh it later. Use `--agent universal` and omit
   `--global` to keep imports here; prefer repeating `skills add` for updates
   because `skills update` automatically selects agent destinations.

3. Copy the skill folder you want to keep into one of these directories:

   - `agents/skills/` — shared by Codex, Claude, and Pi.
   - `agents/pi/skills/` — Pi only.

   For example:

   ```sh
   cp -R .agents/skills/tdd agents/skills/
   ```

   When updating, save local customizations and remove the old destination folder
   before copying; reapply them afterward.

4. For a new shared skill, add two entries to [mise/config.toml](mise/config.toml):

   ```toml
   "~/.agents/skills/tdd" = { source = "../agents/skills/tdd", mode = "symlink" }
   "~/.claude/skills/tdd" = { source = "../agents/skills/tdd", mode = "symlink" }
   ```

   These source paths are relative to `mise/config.toml`, not the shell's working
   directory. Pi-only skills already use the `~/.pi/agent` mapping. Pin any
   required CLIs in the same config, then run `mise dot apply` and reload your
   agent.

Review `git diff` and `git status`, then commit the chosen skills and mise changes.

### Customizations and local skills

`agent-browser`, `playwright-cli`, and `web-search` are automatically discoverable
in Pi and explicit-invocation-only in Codex and Claude. Browser preferences live
in the [personal instructions](agents/global-instructions.md); `web-search` keeps
its existing built-in-first search/text retrieval policy.

When updating imported skills, preserve the curated descriptions and policy
references, direct use of mise-pinned CLIs, and task-owned session cleanup. Keep
each skill's `agents/openai.yaml` policy file and `skillOverrides` in
[Claude settings](agents/claude/settings.json). Leave `disable-model-invocation`
unset in these shared skills so Pi can discover them.

`playwright-cli` is imported from `microsoft/playwright-cli`. Its references cover
browser engineering and Playwright test workflows. The global `@playwright/cli`
pin is separate from each project's Playwright test-runner dependency; CLI debug
features require a compatible project version. Install the pinned CLI with
`mise install npm:@playwright/cli` before using it.

`web-search` is a local skill backed by [DDGS](https://github.com/deedy5/ddgs).
Update its instructions directly and keep the DDGS version pinned in mise.

`recommit` is a local, explicit-invocation-only shared skill for reorganizing a
finished branch in place. See its [workflow](agents/skills/recommit/SKILL.md).
Update it directly; it is not a CLI import.

## Recover after unapplying everything

`mise dot unapply` removes the managed links, including shell startup files and
`~/.config/mise/config.toml`. It leaves the repository's source files and the
installed mise executable at `~/.local/bin/mise` in place.

To restore just the links, use the existing checkout and mise installation:

```sh
"$HOME/.local/bin/mise" -C "$HOME/repos/dotfiles" dot apply
```

Then start a new Bash session to load the managed shell configuration.

For a deliberate full unapply/reapply cycle, run that same command with
`dot unapply` first, then run it again with `dot apply`.

Verified with mise 2026.9.12 using status and apply/unapply dry runs with
`PATH=/usr/bin:/bin` and an empty `MISE_CONFIG_DIR`.

See mise's documentation for
[`mise bootstrap`](https://mise.jdx.dev/bootstrap.html) and
[dotfiles management](https://mise.jdx.dev/dotfiles.html).
