# Validation

Validated against Pi 0.84.4, Node 26.7.0 and tmux 3.7c.

## Passed

- JavaScript syntax checks for the job and launcher modules.
- Pi's actual extension loader accepted the TypeScript extension in model-free JSON/print mode.
- Isolated integration checks using real interactive Pi child processes on a separate disposable tmux server (not the user's existing server):
  - Worktree creation on a named research branch; committed HEAD preserved; parent dirty/untracked files unchanged and not copied.
  - Required child reporting tool registered without recursive dispatch tools.
  - Explicit structured report persisted while the child stayed interactive.
  - Multiline follow-up delivered literally, including shell syntax, slash-command text and a Unicode separator; no shell expansion or command expansion.
  - Cancellation acknowledged without closing the pane; follow-up accepted after cancellation.
  - Real Pi `/reload` preserved a completion report and restarted mailbox polling; follow-up worked afterward.
  - Four children in parallel; fifth launch refused at the open-window limit.
  - Mismatched pane ownership tag prevented closure.
  - Explicit closure retained worktrees and sessions; other test panes remained independently managed.
  - State directory/file permissions, invalid job IDs, parent-scoped listing, and subsequent dispatch after an existing-branch failure.
- Parent adapter simulations under Pi's loader: tool registration, status output, pre-aborted dispatch refusal, durable notification deduplication across extension reconstruction, and polling shutdown.
- Global discovery: all four parent tools and the companion skill discovered exactly once. A real Pi child also loaded the global extension alongside its explicit extension path, exposed child-only reporting, and completed through the manual report command without inference. These checks passed both for the original package registration and after moving to the dotfiles-managed, Stow-linked extension/skill directories.

The child integration driver intercepted prompts and invoked the reporting implementation without model inference. These checks prove process/extension/mailbox mechanics, not an LLM's compliance with delegated task instructions. Test code and fixtures were kept outside the package and k8s-start checkout, under `/tmp/pi-subagents-check.xFVHjM/`; the disposable tmux servers were stopped. No provider inference, GitHub ticket operations, cloud provisioning, or real research dispatch occurred during validation.

## Completion wake-up regression

A model-free temporary harness (`/tmp/pi-subagents-check.xFVHjM/wakeup-test.ts`) exercised the real parent polling callback against disposable job records and owned panes on a private tmux server. Before the fix it failed because done/failed notifications had `triggerTurn: false`. After the fix it passed: only done/failed request follow-up/wake, other statuses use passive next-turn delivery, human-input statuses issue UI alerts, and repeated polls/reconstructed parent state do not duplicate notifications. No model inference was invoked; actual automatic model continuation remains a live acceptance check after `/reload`.

## Automatic parking and explicit resume

Temporary harness: `/tmp/pi-subagents-check.xFVHjM/park-resume-test.ts`. Real interactive Pi processes ran on a disposable tmux server with an in-memory fixture provider emitting real `subagent_report` tool calls (no network or paid model inference). The parent notification adapter was simulated; its actual polling and parking code ran.

Passed: a done report stays open before parent notification; accepted notification triggers graceful Pi exit and owned-pane removal even with `remain-on-exit`; an unrelated split pane survives; worktree edits and old launch records remain. Explicit resume creates a new pane/launch while preserving Pi session ID, context file, branch, worktree and edits. Only the new task runs; taskless human resume stays idle. Live-child resume is refused. Failed/needs-human reports stay open, stale park revisions are rejected, and parked/reload status does not duplicate completion wake-ups. Existing wake-up regression and five-tool/global skill discovery also pass.

Each launch now gets independent runtime files, preventing stale exit records or old inbox commands from leaking into resume. Sessions without a persisted conversation are not auto-parked. Existing launchers need relaunch to acquire the new behavior. Tests exercised disposable fixtures only; production research panes were not closed or resumed.

## Reloaded helper / starved notification regression (2026-09-16)

Live evidence: the latest research child had a durable done report but no parent notification marker. The parent footer reported a missing `requestPark` function; an earlier `resume` call also failed with a missing export. No live child or parent records were edited during diagnosis.

Two red-capable reproductions in `/tmp/pi-notify-regression.yoXywE/`:

- `pi --no-extensions --no-skills --no-prompt-templates --no-session --mode json -e ./check.ts` (from that temporary directory) executes a copy of the real parent adapter with an already-notified older job whose parking fails, followed by a new done job. Before the fix, the new job never notified; after per-job error isolation it wakes exactly once despite repeated polling.
- Actual interactive Pi `/reload` on private tmux servers loaded a changed entrypoint but retained the original `.mjs` helper exports. Query-string imports also stayed stale under the loader. A `.ts` helper refreshed correctly. `upgrade-check.ts` exercised the real extension entrypoint across an old `.mjs` import, migration to `.ts`, and a later helper-only update; observed helper versions were `[1, 2, 3]` after the fix.

Fix: share `lib/jobs.ts` between Pi and the Node launcher (requires Node 22.18+), and isolate delivery/parking errors per job instead of aborting the whole polling pass. No protocol/state migration or deletion of delivery markers is needed. Existing parent processes require `/reload` to load the fix.

Also reran the prior wake-up/deduplication and real-Pi parking/resume tests with the renamed helper: passed. Those tests use a fixture model provider with no network/inference, private tmux servers, and disposable jobs/repos. Graceful parking, same-session resume, pane ownership, sibling preservation, failed/human retention, and stale-park refusal remain covered. Syntax checks passed on Node 26.7.0; the declared Node 22.18 minimum was not separately exercised. No production child was closed/resumed, no host configuration changed, and no paid model calls ran in the tests. After the human reload, the waiting production research result was delivered to this parent: the saved session contains exactly one matching done notification marker and one injected update (2026-09-16T23:28:40.572Z), and the parent continued to review it. This confirms delivery/wake recovery for the reported incident, not every remaining acceptance scenario.

## Remaining human acceptance

- Reload the main interactive session, dispatch a real bounded task, visit its child window, and inspect its report in the parent.
- Exercise a real human-in-the-loop question and answer it directly in the child.
- Verify project trust/authentication onboarding in a fresh worktree without auto-approval.
- Cancel a real running tool and inspect any external process effects; cooperative cancellation is not process isolation or rollback.
- Quit/resume the actual parent session while a child is working; check status/report recovery without duplicate notifications.
- Manually inspect recovery from a killed launcher, an interrupted mailbox delivery, or a stale launch lock. No automatic recovery/cleanup is promised.
- Check other Pi versions/platforms before claiming compatibility. No standalone TypeScript typecheck was performed; the real Pi loader/runtime was exercised.
