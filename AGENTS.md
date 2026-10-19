## Persistent configuration changes

- Treat this repository and `mise/config.toml` as the source of truth. Before editing live configuration under `$HOME` or `$XDG_CONFIG_HOME`, resolve symlinks and inspect the mise dotfile mappings; a file under `~/.config` is not necessarily repository-managed.
- Make persistent fixes in tracked source files and include the deployment mapping. For previously unmanaged configuration, manage the smallest necessary file, use appropriate OS guards, and preserve unrelated local settings. Do not bring caches, credentials, or generated application state into Git.
- Live edits made during diagnosis are temporary until accounted for in the repository and deployment. Before calling a fix complete, either make it reproducible on another machine or explicitly identify the remaining machine-local changes and agree on follow-up. If the user asks to discuss portability first, present the plan rather than applying it.
- Preview deployment with `mise dot apply --dry-run`; scope any actual apply to the intended targets. Verify both the deployed files and the application's effective settings. Report supported platforms, required reloads, and any remaining local-only changes.

## Agent skills

### Issue tracker

Issues and specs live as local Markdown under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage roles. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` and `docs/adr/`. Before exploring the codebase, read `docs/agents/domain.md`.
