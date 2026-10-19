# Agent attention integration

The dotfiles use native agent lifecycle events to write tmux-attention pane
state, while Moshi handles its own phone inbox and remote approvals. Agent hooks
run synchronously for state so a delayed callback cannot reorder blocked and
working. Notifications remain in tmux-attention's optional dispatcher; the
existing macOS `always` sound preference is preserved.

| Event | Claude Code | Pi | Codex |
| --- | --- | --- | --- |
| Work begins | UserPromptSubmit → working | before_agent_start → working | UserPromptSubmit → working |
| Human input | PermissionRequest, AskUserQuestion, ExitPlanMode, Elicitation → blocked | ui_prompt_start → blocked | PermissionRequest → blocked |
| Work resumes | PostToolUse, PostToolUseFailure, PermissionDenied, ElicitationResult → working | ui_prompt_end → working, or clear if idle | PostToolUse → working |
| Work finishes | Stop → done; StopFailure → failed | agent_settled → done, failed after final provider error, idle after abort | Stop → done |
| Interruption | No native interrupt hook | agent_settled.aborted → idle | Interrupt → idle |
| Session lifecycle | SessionEnd → clear | session_shutdown → clear | SessionStart → idle except compact; SessionEnd → clear |

Recoverable tool errors leave an agent working. Pi only reports its final
settled outcome, allowing successful retries to replace intermediate errors.
The CLI's seen rule and unanswered-blocked guard still apply: focusing a
notifying pane acknowledges it, and done/failed cannot replace an unanswered
blocked state. A resumed-working event is therefore essential.

## Deployment

Mise copies `~/.codex/hooks.json` from `agents/codex/hooks.json`, including the
four existing Moshi event handlers. Only `features.hooks` and
`features.daemon_auto_start` merge into machine-local Codex config through
`agents/codex/attention.toml`; the separate terminal-title merge is unchanged.
Model, plugins, computer-use `notify`, and trusted hook hashes remain local.
One hook representation avoids Codex's warning when JSON and inline hooks occur
in the same config layer. Do not also add these handlers to config.toml.

All three agents require a machine-local Moshi opt-in; Codex's commands do not
force-enable it. After pairing your personal computer, run `mise moshi on`.
Use `mise moshi off` to explicitly disable and `mise moshi status` to inspect the
effective preference and service state. The `~/.config/moshi/enabled` and
`disabled` markers, service registration, and pairing data remain local. A fresh
work computer remains off without any marker. Bootstrap does not install Moshi.

An explicit `DOTFILES_MOSHI_DISABLED=1` or `disabled` marker takes precedence over
an opt-in. `DOTFILES_MOSHI_ENABLED` is ignored: only the machine marker enables
hooks, and `on` refuses an environment disable. Reload a running Pi with `/reload`
after enabling, because a disabled extension registers
no handlers. Claude/Codex wrappers reread the marker on every event. Changing a
marker does not change Codex hook definitions or require another trust review.
The shared wrapper retains PATH/common-install fallback; a missing Moshi binary
is a silent no-op.

The controller also starts/enables or stops/disables Moshi's user service, because
its native Codex log watcher operates independently of hooks. It supports known
macOS LaunchAgents and Linux systemd user services. `on` can configure Moshi's
native service if no service exists, but never pairs the computer or runs the
agent-hook installer. `off` writes the disabled marker before stopping services
and disables startup at login. Service failures return a nonzero exit status;
an unmanaged or system daemon must be stopped separately. `status` reports both
the hook preference and actual service state, without contacting Moshi. The
`always_on_discovery` preference controls dev-server/simulator scanning rather
than this enable/disable policy.

Moshi settings, Claude settings, Codex hooks, and Pi's Moshi extension use copy
deployments so Moshi cannot write through symlinks into the repository. Existing
managed symlinks migrate to regular files on apply. Other Pi/Claude files remain
individually symlinked. Reapply these copied files after source edits; do not use
`moshi-hook install` for the managed agents. If an external installer changes the
live copies, reapply them before enabling Moshi again.

Preview `mise dot apply --dry-run`, then apply the intended Codex and agent
targets. Existing unmanaged hooks.json should be reviewed and backed up before
replacing it; preserve unrelated hooks on machines with additional handlers.
Restart Claude Code and Codex; `/reload` loads Pi changes. In Codex run `/hooks`
and trust the new/changed definitions. Codex skips unreviewed commands; deployment
does not manufacture trusted hashes. Session-start behavior takes effect on the
next start/resume after trust. Do not stop a shared daemon serving active work;
start future terminal sessions with `--no-daemon` if one is already running.

These dotfiles target macOS and Linux with mise. Missing/nonzero Claude and Codex state
commands fail silently and cannot decide an approval or inject agent context.
Both Codex Interrupt and SessionEnd use three-second command timeouts. Pi uses
a one-second execution timeout and retries the stable mise shim after a failed
mise invocation.

## Limits

Native hook coverage differs between agents. Codex does not provide a documented
hook for every question/input request or a StopFailure event. Do not claim that
PermissionRequest covers arbitrary questions or that a stopped turn always
proves success. Claude's Stop does not fire on user interruption; stale rendering
or a later prompt/session-end repairs remaining working state. A stale timeout
is optional and is not a heartbeat: enabling one also marks long model/tool
calls unknown.

Pi only writes attention in interactive TUI mode with a pane environment. Claude
and Codex's native tool hooks can also run in inherited child/headless contexts;
their hooks currently do not establish exclusive pane ownership. Avoid launching
headless agent subprocesses with the parent's TMUX/TMUX_PANE environment when
accurate parent-pane status is required. This is a hook-interface limit, not a
reason to add a transcript watcher using unstable internal formats.

Moshi's richer Codex behavior uses native hooks plus daemon log fallback for
interrupts, input, and completion. Reusing its lifecycle ideas is useful;
making tmux-attention depend on its daemon would couple a portable pane CLI to a
separate session/inbox system. Pi's generic UI prompts cannot safely become
Moshi permission actions: they have no permission command, decision, or action ID.

## Evidence

Verified against installed Codex 0.160.0, Pi 1.1.0, and Moshi 0.4.9 on 2026-10-19.
The installed Codex hook registry accepted all eleven configured handlers with
no errors or warnings in an isolated home, without executing hooks or a model.
Tests use fake notifiers and private tmux servers, never real audio or phone pushes.

- [Codex hooks](https://learn.chatgpt.com/docs/hooks): discovery, review/trust,
  event coverage, synchronous/background behavior, tool limits and timeouts.
- [Claude hook reference](https://code.claude.com/docs/en/hooks): question tool
  matching, permissions, elicitation, terminal errors and interruption limits.
- [Pi extension lifecycle](https://github.com/earendil-works/pi/blob/v1.1.0/packages/coding-agent/docs/extensions.md):
  prompt UI events and agent completion. Installed v1.1.0 types and implementation
  additionally verify agent_settled.aborted and resolved ExecResult failures.
- [Moshi per-agent behavior](https://github.com/rjyo/homebrew-moshi/blob/main/docs/hooks.md):
  native Codex hooks with log fallback and Pi settled completion.
- [Moshi Codex background-server guidance](https://github.com/rjyo/homebrew-moshi/blob/main/docs/usage.md#codex-background-server):
  shared server environment can target the wrong terminal pane; disable automatic
  daemon use for terminal hooks.

- [Moshi installation](https://github.com/rjyo/homebrew-moshi/blob/main/README.md):
  package installation, pairing, and service startup are separate steps.
- [Moshi hook settings](https://getmoshi.app/docs/hook-settings):
  always-on discovery concerns dev-server/simulator scanning.
