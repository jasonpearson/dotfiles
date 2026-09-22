---
name: subagent-dispatch
description: Dispatch independent tasks to Pi subagents in tmux, collect results, or resume a completed/closed delegated session. Use when another skill calls for research/review subagents or parallel agent work.
---

# Subagent dispatch

1. Define a bounded assignment: question, context pointers, required skills, permitted edits/external actions, output location, and completion criteria. Pass enough context to stand alone; children do not inherit this conversation.
2. Honor the originating workflow's claim and dependency rules before dispatch. Keep tracker operations in that workflow; the dispatcher does not claim or close tickets itself.
3. Select a workspace:
   - `worktree` for research artifacts or code changes. It creates a new branch from committed HEAD; uncommitted and untracked parent files are not copied. Supply `branch` when the workflow requires a name such as `research/<name>`.
   - `shared-read` for local inspection with only read/grep/find/ls and reporting. It cannot run bash or write research artifacts. Worktrees and tool allowlists are not security sandboxes.
4. Call `subagent_dispatch` with the assignment and absolute required `SKILL.md` paths. Check its returned workspace warning and retain the job UUID, branch, session, and artifact pointers. The child may need the human to approve project trust or authenticate in its window; never automatically grant trust to unblock it.
5. Dispatch other independent tasks up to the open-window limit. Then do independent parent work. Inspect with `subagent_status`; use acknowledgements to distinguish queued messages from accepted messages. Avoid polling in a tight loop.
6. Treat `done` reports as evidence to review against the assignment. `idle` means no active run, not success. For `needs-human`, have the human visit the child window; never fabricate their side of a grilling/prototype discussion. Use `subagent_message` for factual context or revised instructions, not invented human decisions.
7. Link verified artifacts/results into the originating workflow. Preserve sessions, worktrees, and branches until the human explicitly retires them. Commits, merges, pushes, and tracker mutations require the assignment's explicit authority.

## Recovery and control

`/subagents` lists jobs across parent sessions; `subagent_status` can inspect an older job by full UUID. New done/failed notifications wake the parent to review and continue within the assignment's authority. Human-input requests alert the human; informational status changes do not trigger model turns. Notifications already delivered before an upgrade are not replayed. A resumed parent recovers its own jobs by session ID.

After a done report reaches the parent, the child automatically parks: it exits and closes its owned pane, retaining its session, branch, worktree and artifacts. Failed/human-blocked sessions remain open. Review the saved report even when status is now `parked`; pane closure is not loss of the result.

For further work on a parked/closed job, call `subagent_resume` with its full UUID and a bounded follow-up. This opens the same session/worktree in a new window, makes you its dispatcher, and does not replay the original assignment or old mailbox. Use `subagent_message` only while the child remains open. The human can use `/subagents resume <UUID>` to reopen it without an automatic task. If resume refuses due to a live PID, missing session or changed branch, inspect rather than bypassing its checks.

`subagent_cancel` requests cooperative cancellation, discards undelivered mailbox messages, and leaves the session open. Inspect its acknowledgement; cancellation is not rollback and cannot guarantee external processes stop. If a child is unresponsive, the human can use `/subagents close <UUID>` to terminate only its verified owned pane. All artifacts remain.

For restart, trust, credential, or interrupted-delivery details, read [the package README](../../README.md#recovery-and-limitations).
