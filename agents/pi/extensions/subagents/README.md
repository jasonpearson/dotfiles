# Pi subagents

Interactive Pi subagents for delegated work. The parent launches child Pi sessions in a dedicated tmux session named `pi-subagents`, with one child per tmux window. Children can be started from an agent definition (`scout`, `worker`, `reviewer`, `oracle`, or your own) that sets their system prompt, tool allowlist, model, and default workspace mode.

This extension is intentionally conservative:

- child work uses a Git worktree by default
- child success requires an explicit `subagent_report`
- idle or process exit is not treated as task success
- completed successful children are closed only after the parent accepts the report
- failed, blocked, cancelled, crashed, and unreported children remain inspectable
- a child whose Pi process exits without reporting is marked `crashed` and the parent is woken with the pane output
- no automatic commit, merge, push, worktree deletion, or project trust approval
- no recursive subagent spawning in v1

## Installation

This repository's `mise/config.toml` symlinks `agents/pi` to `~/.pi/agent` with `symlink-each`, so this directory is auto-discovered as:

```text
~/.pi/agent/extensions/subagents/index.ts
```

Reload Pi after syncing dotfiles:

```text
/reload
```

## tmux layout

Children run in:

```bash
tmux attach -t pi-subagents
```

The first child creates the `pi-subagents` tmux session. Later children create additional windows in that session.

The launch script turns on `remain-on-exit` for its own pane before starting Pi, so a child that exits (crash, `/quit`, auth or model error) leaves a dead pane behind instead of vanishing. The parent reads the exit status from that pane, saves the last 200 lines to `crash.log`, and marks the child `crashed`. `subagent_resume` replaces the dead pane with a fresh window.

Children launch with the same Pi binary as the parent (recorded in `state.json`), not whatever `pi` resolves to on `PATH` inside the new window.

## Agent definitions

An agent is a folder under `agents/subagents/<name>/` in the dotfiles containing `AGENT.md`: frontmatter on top, the child's system prompt below. mise links each folder into `~/.pi/agent/agents/<name>`, where the extension discovers it. A bare `~/.pi/agent/agents/<name>.md` also works. The folder or file name must match the frontmatter `name`.

```markdown
---
name: scout
description: Fast read-only codebase recon
tools: read, grep, find, ls
model: openai-codex/gpt-5.3-codex-spark
mode: shared-read
---

You are a scout. ...
```

| Key | Effect |
|---|---|
| `name`, `description` | Required. The description is what the parent model sees when choosing an agent. |
| `tools` | Strict `--tools` allowlist. Omitted keeps Pi's default selection (`read`, `bash`, `edit`, `write`); empty means no tools. `subagent_ask` and `subagent_report` are always added. Lists accept `a, b` or a `- item` block. |
| `model` | `provider/id`, optionally with a `:level` thinking suffix. Omitted inherits the parent's model. |
| `thinking` | Thinking level. Wins over a suffix on `model`. |
| `mode` | Default workspace mode, `worktree` or `shared-read`. `subagent_start` can override it. |
| `systemPromptMode` | `replace` (default) swaps Pi's built-in coding prompt for the agent prompt; `append` keeps Pi's prompt and adds the agent's. Tool definitions, skills, and context files such as `AGENTS.md` load either way. |

The subagent contract is appended to the system prompt on every launch, after the agent prompt, so it stays authoritative across resumes. Agent files are read at `subagent_start` time, so prompt edits apply to the next child; adding or renaming an agent needs `/reload` because the agent names are baked into the tool schema.

The four starters: `scout` (read-only recon, `gpt-5.3-codex-spark`), `worker` (implementation in a worktree, `gpt-6.1-sol`), `reviewer` (read-only review with git inspection, `gpt-6-astra`), and `oracle` (second opinion, no edits, `gpt-6-astra`).

## Workspace policy

Default mode is `worktree`:

```text
~/.pi/agent/subagents/worktrees/<repo-hash>/<child-id>
```

The branch name is:

```text
subagent/<slug>/<short-child-id>
```

The worktree starts from committed `HEAD`. Parent checkout dirt is allowed but warned about; it is not copied into the child worktree.

`shared-read` mode launches in the parent checkout. Without an agent it is enforced with a read-only tool set (`read`, `grep`, `find`, `ls` plus the child tools); with an agent, the agent's own `tools` apply, so a reviewer can keep read-only `bash` for `git diff`. It is not a sandbox: a child with `bash` can still mutate.

## Parent tools

- `subagent_start` — launch a child, optionally from an agent definition; a failed launch removes the half-made worktree and branch and records the error
- `subagent_agents` — list agent definitions, or show one in full with its system prompt
- `subagent_status` — list children and reports; defaults to live children plus this session's finished ones, `all: true` for everything
- `subagent_send` — queue a literal mailbox message for a child; `replyTo` answers a question the child asked; warns when the child's process is not running
- `subagent_resume` — reopen a child Pi session in the same cwd/worktree; archives the earlier report into `reports[]` so the child can report again
- `subagent_cancel` — write a cancel marker the child honors, send Escape, and mark cancelled; retains state by default

`subagent_status`, `subagent_send`, `subagent_resume`, and `subagent_cancel` accept an exact id, an exact name, or an id prefix. Ambiguous or unknown references fail with the list of known children.

Window names are `<agent>-<slug>-<shortid>`, with `pi` as the agent for generic children.

`subagent_start` accepts an optional one-sentence `summary`, displayed as a `Task:` line in the parent chat. If omitted, it displays a single-line preview of the assignment, capped at 240 characters with an ellipsis when truncated. This describes the assigned work, not a live plan generated by the child, and requires no extra model call.

## Child tools

Child processes auto-discover global extensions, but `index.ts` disables parent orchestration tools whenever `PI_SUBAGENT_ID` is set. The launcher explicitly loads `child.ts`, which registers:

- `subagent_ask` — ask a question and end the child's turn; the child idles until the answer arrives as the next user message
- `subagent_report` — record terminal outcome: `done`, `failed`, or `needs-human`

Once the parent has cancelled a child, both tools refuse with an error so a cancelled child cannot report `done` later. Reports written before the cancellation are still delivered.

### Questions

The child never blocks inside `subagent_ask`. It writes the question, marks its pane blocked for tmux-attention, and ends its turn, so a human can answer by typing in the window. The parent scan delivers the question to the parent model as a `subagent-question` message and wakes it. The parent is told to answer with `subagent_send` and `replyTo` only when confident from its own context, and otherwise to tell the human and stop.

Whoever answers first wins. A mailbox reply marks the question answered by the parent before it is injected. Any other turn start in the child marks open questions answered by the window. A later `subagent_send` with `replyTo` for an answered question is refused with a note saying who answered. Unanswered questions are not re-sent; they show in the footer count, in `subagent_status`, and as the blocked pane color.

## Delivery policy

`subagent_send` writes mailbox files under the run directory. The child extension polls while idle and injects accepted messages into the child session with `pi.sendUserMessage`. This avoids tmux paste races and preserves literal message delivery.

The child polls `cancel.json` on the same timer. When it appears the child aborts its current turn, stops accepting mailbox messages, and refuses further `subagent_ask` and `subagent_report` calls.

### Waking the parent

A busy parent receives reports and questions as a follow-up after its current turn. An idle parent gets the notice appended without a turn, followed by one short user message, `Subagent updates above.`, that starts a normal turn. A turn started directly by a custom message skips Pi's `before_agent_start`, which drops extension prompt sections and invalidates the provider's prompt cache; the user-message wake avoids that. One wake covers every notice appended within ten seconds.

When a child reports:

- `done` / `failed` wakes the parent model with a compact report
- `needs-human` notifies the human/UI without asking the parent model to invent an answer
- the child's tmux window stays open after any report, marked `done`, `failed`, or `blocked` for tmux-attention
- a child that exits without reporting wakes the parent with a `subagent-crash` message and the pane tail
- all worktrees, state, and Pi sessions are retained

## tmux-attention

Children auto-load the global `tmux-attention` extension, so their panes show `working` and `done` like any Pi. The child extension adds `blocked` after a question or a `needs-human` report, `failed` after a failed report, and `idle` after a cancel, re-asserting shortly after the agent settles so the more specific state wins. Because the attention picker's `jump` skips the `pi-subagents` session, the parent also marks its own pane `blocked` while a child waits on a human and the parent model is idle, and clears it to `idle` once nothing is pending.

## State layout

```text
~/.pi/agent/subagents/
  runs/<child-id>/
    state.json          parent-owned
    initial-prompt.md   parent-owned: the assignment
    system-prompt.md    parent-owned: agent prompt plus contract, regenerated per launch
    launch.sh           parent-owned
    resume-prompt.md    parent-owned, on resume
    cancel.json         parent-owned, on cancel
    crash.log           parent-owned, on unexpected exit
    child.json          child-owned: pid, cwd, session file
    mailbox/*.json      parent creates, child marks accepted
    questions/*.json    child-owned: created on ask, marked answered by the child
    reports/*.json      child creates, parent marks delivered
  worktrees/<repo-hash>/<child-id>/
```

### File ownership

The parent and child are separate processes with no shared lock, so each file has one writer. `state.json` is written only by the parent; the child never touches it. Facts that originate in the child go into child-owned files or append-only per-event files that the child creates and the parent annotates after handoff. This removes the read-modify-write races an earlier version had when both sides updated `state.json`.

The parent scans only children whose status is not terminal (`done`, `failed`, `cancelled`, `crashed`). Resuming a child makes it `running` again and puts it back in the scan.

## Limitations

- v1 has no cleanup/retire command; remove retained worktrees and state manually after review.
- `subagent_cancel` is cooperative: the child honors the marker within its poll interval, and child-spawned processes are not killed.
- Two parent Pi sessions scanning at once could both deliver the same report; the second delivery is harmless but noisy.
- Child extension/provider discovery is normal Pi discovery, not a security sandbox.
- Window close uses the recorded tmux window id; it does not yet inspect for unsent editor drafts.
