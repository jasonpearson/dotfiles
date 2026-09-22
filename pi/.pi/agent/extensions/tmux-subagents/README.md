# Pi tmux subagents

A standalone Pi package: interactive child agents in detached tmux windows, with durable mailboxes and explicit results. Requires Pi 0.84.4-compatible extension APIs, Node 22.18+ (native TypeScript support for the launcher’s shared helper), tmux with direct multi-argument command execution (tested on 3.7c), and Git for writing tasks.

## Install

The source of truth is `pi/.pi/agent/extensions/tmux-subagents/` in the dotfiles repository. Its companion skill is linked from `pi/.pi/agent/skills/subagent-dispatch`. From the dotfiles root:

```bash
stow -R -t "$HOME" pi
```

This exposes the extension under `~/.pi/agent/extensions/tmux-subagents/` and the skill under `~/.pi/agent/skills/subagent-dispatch/`. Directory discovery replaces package registration; do not also add this directory to `settings.json` packages.

Run `/reload` in an existing parent session. The package supplies the `subagent-dispatch` skill and five tools: `subagent_dispatch`, `subagent_resume`, `subagent_status`, `subagent_message`, and `subagent_cancel`. The child gets `subagent_report` instead of dispatch tools. No npm install or build is needed: Pi supplies its core peer dependencies and loads TypeScript.

Example request:

> Use a subagent to investigate this question in a new worktree. Load the research skill, write findings on research/my-question, and report artifact paths without committing or publishing.

Dispatch inherits the parent's current provider, model, and thinking level. Each child starts with a fresh context and normal Pi configuration discovery, plus explicitly supplied skill files. Its task is stored in a private file rather than shell command text. Required skills are instructions to load through `read`; the extension does not implement a separate Skill tool.

## Workspace and ownership

- `worktree`: new branch/worktree from committed HEAD. Parent dirty files are not copied or modified. Choose the branch explicitly or accept `subagent/<UUID>`. Existing branches are never adopted. No automatic commits, merges, deletion, or cleanup.
- `shared-read`: use the source directory with only built-in read/grep/find/ls and child reporting enabled. This is an inspection mode, not a sandbox: extensions still execute with user permissions.
- Four **open child panes** maximum across all parent sessions using this state directory. Successfully completed children close after parent notification, releasing their slot. Failed, human-blocked and idle children remain open.
- Children have normal user filesystem/network/credential access. Worktrees isolate edits, not permissions; they share Git objects/configuration. Use trusted tasks and repositories.
- GitHub claims, dependencies, resolution comments, and research branch publication remain the calling workflow's responsibility.

## Interface

| Interface | Behavior |
| --- | --- |
| `subagent_dispatch` | Start a child; return job UUID, workspace, pane and session paths immediately |
| `subagent_resume` | Reopen a closed/parked child in a new window with the same saved session/worktree and an explicit follow-up task |
| `subagent_status` | List current parent's jobs, or inspect any full job UUID |
| `subagent_message` | Queue literal text for delivery when the child is idle; return acknowledgement path |
| `subagent_cancel` | Cooperative abort; discard undelivered mailbox messages; retain interactive child |
| `/subagents` | List all jobs, including jobs from previous parent sessions |
| `/subagents <UUID>` | Inspect a job |
| `/subagents resume <UUID>` | Reopen the saved child session for direct human interaction, without replaying a task |
| `/subagents close <UUID>` | Human-confirmed termination of only the owned pane; retain files |
| `subagent_report` (child) | Explicit `done`, `failed`, or `needs-human`, summary and artifact paths/URLs; ends that run |
| `/subagent-done <summary>` (child) | Manually mark an idle child complete |

Use normal tmux window navigation to visit the child. Closing does not kill a whole window containing unrelated split panes. The server process ID and per-pane job/launch tags are checked before closure. No tmux configuration changes are needed.

## Status and results

Execution and task outcome are separate. `running`, `idle`, `waiting-ui`, and `unresponsive` are observations; only an explicit `done` report asserts task completion. `needs-human` carries the child's question. `failed` and `cancelled` do not imply rollback. `closed` means the child process/pane is no longer available, regardless of any earlier report.

Reports persist across further conversations. Inspect their timestamp/revision alongside current status: an old report is not proof the latest follow-up finished. An agent that becomes idle without reporting remains `idle`.

After a `done` report is queued to the parent and the notification marker recorded, the parent requests **parking**. This means notification accepted by Pi, not that the parent has finished reviewing the result. The child waits until idle with no pending Pi messages, checks that the same report is still current and the editor has no unsent text, then gracefully shuts down. The launcher closes only its owned pane after Pi exits, including when tmux uses `remain-on-exit`. Session, branch, worktree edits, reports and artifacts remain. Status becomes `parked`. Failed/human-blocked children stay interactive. A missing saved session prevents automatic parking rather than losing resumability.

If the parent is offline, completion stays open until that dispatcher resumes and receives the report. Follow-ups queued before parking take priority; stale park requests cannot close a subsequent conversation. An already-parked or closing child rejects messages: use `subagent_resume` once closed. Informational parked/closed updates never wake the parent again.

The parent polls structured files, not terminal output. New `done` and `failed` notifications wake an idle dispatcher to review the result, or queue a follow-up when it is busy; this can incur model usage. `needs-human` and `waiting-ui` alert the human directly without starting a model turn. Other status updates remain passive and enter model context on its next turn, without queuing a continuation. Notifications are deduplicated using persisted parent-session entries, including across reload. Previously delivered reports are not replayed just because the extension was upgraded. A per-job delivery or parking failure is shown in the status footer and retried; it does not prevent later jobs from delivering their reports. No transcript or reasoning is automatically copied to the parent. Tool/notification output is capped at 30KB/1000 lines; full records remain in the job directory.

## Recovery and limitations

Job files live under `~/.pi/agent/subagents/<UUID>/`, or under `PI_CODING_AGENT_DIR/subagents`. `PI_SUBAGENTS_DIR` overrides the job root. Directories must be owned by the current user with mode 0700; records are written atomically with mode 0600. Tasks, reports, and full Pi sessions may contain sensitive project context: keep this directory private and do not put credentials in reports.

`job.json` is original assignment/workspace metadata; `current.json` selects the current launch. Each `runs/<launch-UUID>/` retains its own launch metadata, task, status/heartbeat, pane identity, exit record, inbox and acknowledgements. `report.json` holds the last result; `session.jsonl` remains the same resumable Pi conversation across launches. Worktrees remain below the job directory. Legacy jobs without `current.json` retain their root-level runtime files until explicitly resumed; old records are not deleted or replayed.

No background daemon is required. Child polling continues if the parent quits. `/reload` restarts polling; a parent resumed with the same session ID rediscovers its children. `/new` and `/fork` do not automatically adopt jobs; inspect them with `/subagents`. Explicitly resuming an old job assigns its future reports to the new dispatcher.

Mailbox delivery has **at-most-once intent, not exactly-once execution**. An acknowledgement stuck at `accepting` means delivery was interrupted at an ambiguous point: inspect the child session before resending. `accepted` means Pi accepted the input, not that the task succeeded. Cancellation takes priority over queued messages but does not retract prompts already accepted by Pi or undo their effects.

An interactive child can pause before its extension starts on project trust or authentication. A missing heartbeat appears as `unresponsive` after 15 seconds; visit the window before diagnosing it as a crash. Trust is never automatically approved. The child uses the tmux server/session environment plus the parent's PATH and Pi configuration directory. API keys existing only in the parent process environment are **not copied**: authenticate through Pi's normal credential store or explicitly arrange the tmux environment yourself. Credentials are never serialized by the dispatcher.

Resume is explicit, not automatic retry: `subagent_resume` supplies a bounded follow-up; `/subagents resume <UUID>` opens the same session for you. It keeps prior context, model/thinking, workspace mode, branch and edits, with a fresh launch/mailbox in a new window. It does not rerun the original assignment or deliver old inbox entries. A live child, missing session/workdir, changed worktree branch, or still-existing recorded child PID blocks resume rather than risking concurrent session writers or silently creating a replacement. Inspect ambiguous/stale PID ownership manually. Required skill paths must still exist. Active managed children block `/new`, `/resume`, `/fork`, and `/clone` to keep their mailbox tied to one session.

After upgrading, reload the parent. The shared helper is `lib/jobs.ts`, intentionally loaded through Pi's TypeScript reload path: Pi 0.84.4 can retain stale `.mjs` imports across `/reload`, producing missing-export errors and mixing old job handling with new extension code. The Node launcher imports that same file natively. Existing child processes also need `/reload` for the parking protocol; old launcher processes cannot acquire new shutdown behavior until relaunched. You can explicitly close an old child and use resume to start it with the new launcher. A manual done command before Pi has persisted any model conversation may leave no session file yet; such a child stays open rather than being parked without resumable context.

Launches are serialized by an empty `.dispatch-lock` directory. A process crash while launching may leave it behind. Verify no dispatch is in progress before manually removing that empty directory. Partial worktrees/job directories are deliberately retained for inspection, even when launch fails. Cancellation and closing never remove branches or worktrees; retire them with ordinary Git commands only after reviewing/preserving changes.

The open-window limit and disabled recursive tool registration are workflow guardrails, not defenses against arbitrary shell commands, other extensions, or a hostile agent. No filesystem sandbox, spending quota, or OS process-tree isolation is provided.

## Validation

See [VALIDATION.md](VALIDATION.md) for checks performed and remaining acceptance work.
