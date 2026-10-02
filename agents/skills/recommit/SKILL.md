---
name: recommit
description: Rebuild a finished branch into human-reviewable commits without changing its final tracked tree.
disable-model-invocation: true
---

# Recommit

Reconstruct history **in the existing branch and checkout**, preserving the
finished code. Create `backup/<branch-name>` before resetting; retain it afterward.

By default, infer intent from the aggregate diff and surrounding code, not the
original commit messages or boundaries. The invocation option
`--use-commit-messages` permits consulting old messages as supplementary context;
it does not make the old grouping authoritative.

## 1. Establish the starting point

Work from the repository root. Use metadata-only Git commands for discovery:
`symbolic-ref`, `rev-parse`, `status --porcelain`, and `merge-base`. Ordinary
`log`, `show`, `reflog`, and verbose branch listings can expose old messages.

Require a named, non-default branch, a clean index and working tree, and no
untracked files. Include submodule dirtiness in the check. Stop for an ongoing
merge/rebase/cherry-pick/revert, incomplete history, or sparse checkout. Ask the
developer to resolve these conditions; do not automatically stash or discard work.

Resolve the remote and its actual default branch from Git configuration and
refs, rather than assuming `origin` or `main`. Ask when the choice is ambiguous.
Ask permission before a network lookup or fetch. With permission, fetch the
default branch without pruning; otherwise disclose that the locally available
reference may be stale. Stop if the default branch cannot be established.

Pin these values for the run:

- `branch`: the current branch name.
- `original`: its full tip commit ID.
- `original_tree`: that commit's tree ID (`git rev-parse "$original^{tree}"`).
- `default_ref` and `default_tip`: the selected default-branch ref and commit ID.
- `base`: the unique result of `git merge-base --all "$original" "$default_tip"`.
- `backup`: exactly `backup/<branch-name>` (preserve slashes in the branch name).

Use the **current merge-base**, not the historical fork point or default tip.
Stop if there is no unique merge-base. If the base and original trees are equal,
report that there is no net change to reconstruct and leave history untouched.

Check that the backup ref is valid and available. If it already exists or
conflicts with another ref name, stop and ask the developer to resolve the
collision. Never overwrite it or silently choose a suffix.

**Done when:** the repository is eligible, all inputs are pinned, and the exact
backup name is available. Keep plans, patches, and scratch files outside the
working tree so they cannot become part of the reconstruction.

## 2. Design the commit sequence

Review the complete aggregate diff:

```sh
git diff --no-ext-diff --no-textconv "$base" "$original" --
```

Read surrounding code and repository instructions as needed. Account for
binary files, renames, deletions, modes, symlinks, and submodule gitlinks as well
as text hunks. Inspect content at the pinned revisions when diff output alone
is insufficient. Keep external diff drivers and text conversion disabled.

In the default mode, do not inspect original messages or per-commit patches to
infer the grouping. Only with `--use-commit-messages`, consult messages in
`"$base..$original"` for intent; assess them against the finished diff.

Propose a dependency-ordered sequence with a subject, purpose, and assigned
changes for each commit. Keep implementation, its tests, and closely related
documentation together. Separate independent concerns where that helps review;
prefer a coherent larger commit to artificial file-by-file or size-based splits.

Aim for understandable intermediate states, but do not promise each commit
builds or passes tests. Recommit does not fix bugs, improve code, or introduce
unrelated cleanup. Reconstruct from the net change rather than replaying the
original development path.

**Done when:** every changed path and hunk has an explicit place in the plan,
with no omissions or duplicated assignments, and dependencies explain the order.

## 3. Obtain approval, then back up and reset

Present the sequence, branch, original tip, selected default ref/tip, base,
backup name, and final-tree preservation requirement. Explain that approval
will rewrite the current branch in place; published history and dependent
branches will still refer to the old commits. Never push automatically.

Wait for explicit approval of this plan before beginning reconstruction. This
is the rewrite approval gate; there is no later branch-replacement step.

Immediately before acting, recheck the current branch, original tip, clean
state, and backup availability. If any changed, stop and revisit the plan.
Create and verify the backup before resetting:

```sh
git branch "$backup" "$original" &&
  test "$(git rev-parse "refs/heads/$backup^{commit}")" = "$original" &&
  git reset --mixed "$base"
```

Check the command's result. The mixed reset moves the branch and index to the
base while leaving the finished working files available for regrouping.

**Done when:** the verified backup points at the original tip, the current
branch points at the pinned base, and the working files have been preserved.

## 4. Reconstruct in place

Stage explicitly selected paths or hunks for the next planned commit. Use
reviewed index patches when several concerns share a file. Newly added files
are now untracked; include them deliberately, including originally tracked
files that ignore rules now hide. Preserve binary content and file modes.

Before each commit, review `git diff --cached --no-ext-diff --no-textconv`
against its planned scope. Write a clear subject and, where useful, a short
body explaining why the change belongs together. Keep commit messages focused
on the change, not on the history-rewriting exercise.

Leave repository Git hooks enabled. If a hook fails or changes the intended
contents, pause rather than bypassing it or silently accepting a different
result. The remaining worktree includes later changes, so hook success is
not evidence that this intermediate commit passes tests in isolation.

Do not independently run builds, linters, or test suites, or create verification
worktrees. Testing belongs to the repository's normal workflow.

If the plan needs a material change, ask for renewed approval. On failure or
interruption, preserve the backup and partial reconstruction, report the
current state, and ask whether to resume or roll back. Do not restart the reset
sequence blindly. Rollback requires approval and a fresh check for work that
would be lost; never automatically hard-reset, clean, or remove the backup.

**Done when:** every planned commit exists in order and all intended changes
have been committed, with no remaining staged, unstaged, or untracked work.

## 5. Verify fidelity and report

Verify all of the following using the pinned values:

- The current branch is still `branch`, and `refs/heads/$backup` still points
  at `original`.
- The new commits form the approved linear sequence starting directly at
  `base`, with no merge commits or extra commits. Use parent IDs and the new
  commits' messages, not the original history's messages.
- `git rev-parse 'HEAD^{tree}'` equals `original_tree` exactly.
- `git status --porcelain=v1 --untracked-files=all --ignore-submodules=none`
  produces no output.

Tree equality proves identical tracked paths, contents, modes, symlinks, and
submodule gitlinks. With the same pinned base, the aggregate change is therefore
identical. It does not establish code correctness or test success.

On any mismatch, stop and report what differs. Preserve the backup and seek
approval before recovery; do not claim completion or repair code opportunistically.

Finish with two short sections:

1. **PR summary:** a few copyable bullets describing the finished changes and
   their purpose, derived from the aggregate diff. Exclude rewrite bookkeeping.
2. **Recommit result:** new commits in review order (short ID and subject),
   pinned base, retained backup name and original tip, tree-equality/clean-state
   verification, and test status. Say tests were not run by recommit; mention
   any hook-run checks separately without overstating their coverage.

**Done when:** all fidelity checks pass and the brief summary is delivered.
Keep the backup; leave publishing and eventual backup deletion to the developer.
