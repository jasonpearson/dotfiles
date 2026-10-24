---
name: ammend-commits
description: On explicit human invocation, propose which uncommitted changes belong in which existing commits on the current branch, then amend only after the user approves the proposal.
disable-model-invocation: true
---

# Ammend commits

Run only when the user explicitly invokes this skill. Invocation authorizes
**inspection and a proposal**, not staging, committing, or rewriting history.
Never infer rewrite approval from the invocation, an earlier general instruction,
or silence. Do not invoke this skill automatically or from another skill.

Fold approved uncommitted changes into the existing commits they logically
belong to. Unlike rebuilding a branch, preserve commit order, boundaries,
messages, and authors unless the user explicitly approves an exception. Do not
improve code, create unrelated commits, or publish anything as part of this task.

## 1. Inspect the checkout and establish the history range

Start in the current working directory, find its repository root, and inspect the
whole checkout, not just the current subdirectory. Read repository instructions.
Use read-only Git operations during planning; keep notes and patches outside the
working tree. Do not stage, stash, reset, create refs, or run modifying checks.

Require a named branch with an existing HEAD. Stop for an ongoing merge, rebase,
cherry-pick, or revert, unmerged index entries, dirty submodules, sparse checkout,
or insufficient history. Do not automatically clean up these conditions.

Inventory all staged, unstaged, and untracked changes, including deletions,
renames, binary files, modes, symlinks, and submodule gitlinks:

```sh
git status --porcelain=v1 --untracked-files=all --ignore-submodules=none
git diff --cached --no-ext-diff --no-textconv --binary --
git diff --no-ext-diff --no-textconv --binary --
git diff HEAD --no-ext-diff --no-textconv --binary --
git ls-files --others --exclude-standard
```

Read relevant untracked files explicitly; ordinary diffs omit them. Do not add
ignored files, credentials, or generated state. Account for the staged and
unstaged versions separately, even when their changes cancel in the net diff.
Do not accidentally commit an intermediate staged version instead of the user's
final working version. If there are no changes, report that and stop.

Establish an explicit base for candidate commits. Honor a user-specified base;
otherwise resolve the remote and actual default branch from local configuration
and refs, then use the unique merge-base with HEAD. Do not assume `origin`,
`main`, an arbitrary number of recent commits, or that the tracking branch is
the branch point. Ask if the base or remote is ambiguous, no branch-only range
exists, or the user wants to amend a commit outside that range. Ask before any
network lookup or fetch; disclose that local remote-tracking refs may be stale.

Pin the branch name, full original tip ID, base ID, candidate commit IDs, and a
content-sensitive inventory of the index, worktree, and untracked files. Paths
and status letters alone cannot detect edits made while approval is pending.
Inspect commit messages **and patches** in `base..HEAD`, plus surrounding code
and blame/history where useful. Never assign changes from subjects alone.
If the proposed rewrite range contains merges, stop and ask for a narrower range
or a separate merge-preserving plan; do not silently flatten the history.

## 2. Map changes to their owning commits

Split the uncommitted work into logical changes, down to individual hunks or
lines when a file contains unrelated work. Match each change to the existing
commit whose intent it completes or corrects. Use the actual historical patch,
not merely the most recent commit touching that file. Keep related tests and
documentation with their implementation.

For every change, propose exactly one disposition:

- **Amend `<full commit ID>`:** identify the matching commit and explain why.
- **Leave uncommitted:** unrelated new work, no convincing target, or work the
  user has excluded. Do not invent a new commit or force it into an old one.
- **Needs clarification:** multiple plausible targets or an inseparable change.
  Ask a specific question rather than guessing.

Check that the change makes sense at the target commit, before later commits
are replayed. A change depending on code introduced later cannot simply be
folded into an earlier commit. Flag overlapping hunks, later edits to the same
code, binary replacements, and likely replay conflicts. Do not promise that
intermediate commits build or pass tests without testing them in isolation.

Account for every staged, unstaged, and untracked change exactly once. Staging
status does not itself authorize inclusion. Preserve the staged/unstaged split
of work left out; if overlapping edits make that ambiguous, resolve it with the
user before executing.

## 3. Present the proposal and wait

Present a concise table in original commit order:

| Target commit (short ID and subject) | Assigned paths and hunks | Rationale / risks |
| --- | --- | --- |

Identify hunks by path, current line range or symbol, and a short description;
do not offer only file-level assignments when files contain mixed concerns.
Include full target IDs in the pinned plan even if the table abbreviates them.
List changes that will remain uncommitted and any unresolved questions separately.

Also show:

- Current branch, original tip, selected base, and earliest affected commit.
- The replay boundary: the parent of the earliest target, or an explicitly
  approved root rewrite if the target is the root commit.
- All descendants whose IDs will change, even if their patches will not.
- A proposed unused backup ref, plus how dirty work and residual staging will
  be saved and restored. A branch backup alone does **not** save uncommitted work.
- Approval includes resolving conflicts during replay and residual-work
  restoration without further approval, using the verified backups for recovery.
- Whether local refs indicate the affected history is published/shared; unknown
  publication status must remain unknown. Warn about collaborators, dependent
  branches, invalidated signatures, and any later coordinated force-push.

Ask: **“Approve these amendments, revise the assignments, or stop?”**
Then end the turn and wait for explicit approval of this particular proposal.
Resolve ambiguities before asking for approval. Partial approval authorizes only
those assignments; show the resulting reduced plan if its dependencies change.
If nothing has a suitable target, report that and leave the checkout untouched.

## 4. Execute only the approved plan

Immediately before acting, recheck the branch, tip, index/worktree/untracked
contents, pinned refs, and backup availability. If anything changed, stop and
refresh the proposal; do not treat the old approval as covering new changes.

Before any destructive operation, create and verify the approved backup ref at
the original tip. Separately save a recoverable snapshot of the original index,
working files, and untracked contents, retaining its exact object ID or external
backup location. Keep snapshots outside the checkout and never overwrite an
existing backup. Verify recovery data before clearing or rearranging the index.
Do not rely on the reflog or a moving `stash@{0}` alone.

A suitable workflow is targeted `git commit --fixup=<full-target-ID>` commits
followed by an inspected interactive autosquash rebase from the pinned replay
boundary. A direct amend is sufficient when the sole target is HEAD. Either way:

1. Record the expected final tracked tree: original HEAD plus **only** approved
   changes. Use a temporary index or another isolated representation, not broad
   staging of the dirty checkout.
2. After saving the original index, stage only the approved paths/hunks for one
   target at a time. Clear unrelated pre-existing staging without discarding
   working files. For mixed files, use reviewed index patches rather than
   whole-file adds. Review the complete cached diff before every commit.
3. Preserve unapproved work and its original staging split separately before
   replay, including untracked files that could obstruct checkout. If using a
   stash, retain its exact ID and use `apply`, not `pop`, until verification.
   The residual snapshot must exclude changes already absorbed by fixups; do
   not reapply the original all-changes snapshot over the amended history.
4. Inspect the rebase todo against the approved target IDs. Preserve all original
   commits in order and place only the intended fixups after their targets.
   Disable automatic stashing and updates to other branch refs
   (`--no-autostash --no-update-refs`), and use the exact pinned boundary rather
   than an inferred fork point (`--no-fork-point`). Preserve intentionally empty
   commits; stop if a replayed commit unexpectedly becomes empty rather than
   silently dropping it.
5. Restore only the residual uncommitted work and staging. Never silently
   normalize all remaining changes to staged or unstaged.

Resolve conflicts during replay and residual-work restoration autonomously;
do not pause for user approval of conflict fixes. The verified backup ref and
dirty-work snapshots provide recovery points. Use the pinned history, approved
assignments, expected final tree, and recorded residual state to resolve each
conflict while preserving both the amendments and later commits' intent. Review
and stage only the resolved paths/hunks, then continue the operation. Do not
choose ours/theirs wholesale, drop commits, or expand the approved scope.
Conflict fixes within that scope are already authorized; material changes to
assignments, unrelated code, messages, or replay strategy still require renewed
approval.

Keep Git hooks enabled. If hooks fail or alter contents, pause and report the
state rather than bypassing hooks or silently accepting a different result.

Do not use `git reset --hard`, `git clean`, automatic rollback, or automatic
backup deletion. On interruption or failure, retain the backup and dirty-work
snapshots, explain what completed and what remains, and ask whether to resume
or recover. Recovery that could overwrite work requires fresh approval.
Never push, force-push, or move unrelated branches/tags.

## 5. Verify and report

Verify that:

- The current branch is unchanged and its backup still points at the old tip.
- The new HEAD tree exactly matches the independently recorded expected tree.
- The commit count, order, messages, and authors match the approved plan; only
  assigned patches changed, with no leftover fixup commits or unintended drops.
  Inspect old/new history (for example with `git range-diff`) in addition to
  checking final-tree equality. Unaffected ancestors retain their IDs.
- All excluded changes remain uncommitted with their contents and staging split
  preserved. Compare against the recorded residual state, including untracked
  file bytes and modes; a clean checkout is expected only if nothing was excluded.
- There is no unfinished Git operation and no unintended tracked-content change.

On a mismatch, stop, report it, and preserve recovery data. Do not silently
repair code or claim success. Report tests actually run, distinguishing hook
checks from tests of intermediate commits; say when tests were not run.

Finish with the old-to-new IDs of amended commits, a short summary of what each
absorbed, conflicts resolved, remaining uncommitted work, verification results,
and retained backup refs/snapshot locations. Leave publishing and backup cleanup
to the user.
