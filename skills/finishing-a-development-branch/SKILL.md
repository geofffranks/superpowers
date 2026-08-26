---
name: finishing-a-development-branch
description: Use when implementation is complete and validated - verifies automated validation passed, squashes and cleans up the feature worktree, and hands the human the manual validation steps to finish. Does not push, merge, or open PRs.
---

# Finishing a Development Branch

## Applicability

Use this only when branch/worktree integration, squashing, or a human manual-validation handoff is genuinely part of the approved work. It is not a default consequence of having a plan. A small Markdown, metadata, or config cleanup on the current workspace should finish with a focused verification and concise report instead.

**Required shared policy:** Use `superpowers:artifact-retention-policy` before creating or retaining any validation record.

## Overview

Complete eligible implementation work by verifying the **automated validation** passed,
**squashing** the branch into one commit, **cleaning up the feature worktree**,
and handing the human the **manual validation steps** to finish. Branch
integration (push/merge/PR) is left to the human — this skill does not offer it.

**Core principle:** Verify automated validation → Squash → Clean up worktree → Hand off manual validation.

**Integration safety rule:** Never remove a worktree you did not create, and never
remove a worktree with uncommitted changes unless they are intentionally
discarded. Named feature worktrees are preserved exactly; cleanup is scoped to
the worktree we own (under `.worktrees/` or `worktrees/`).

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## Step 1: Verify Automated Validation Passed

Confirm the plan's Finalize work is complete: the **automated validation** ran
and passed, and the branch is ready to finish.

```bash
# Run the project's automated validation / test suite
npm test / cargo test / pytest / go test ./...
```

**If automated validation fails:**
```
Automated validation failing (<N> failures).
Cannot finish until it passes.
```

Stop. Don't proceed to Step 2.

**If it passes:** continue. If automated validation was already run after the
final relevant mutation, its CI/session evidence remains valid; do not rerun an
equivalent command solely because this skill was entered. Do not require or
create a validation document unless validation itself is a durable deliverable
under `superpowers:artifact-retention-policy`.

## Step 2: Squash the Branch's Commits Into One

After automated validation passes, squash the branch's commits into one against
its base:

```bash
BASE=$(git merge-base HEAD <base-branch>)
git rebase -i "$BASE"
```

Combine the branch's commits into a single commit describing the finished work.
If the branch already carries a single squashed commit, nothing further is
needed.

## Step 3: Clean Up the Worktree

Clean up **now** — do **not** wait for the human's manual validation to finish.

Determine workspace ownership before removing anything:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If the worktree path is under `.worktrees/` or `worktrees/`:** Superpowers
created this worktree — we own cleanup. Verify the squashed commit is reachable,
then remove:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment (harness) owns this workspace. Do NOT remove
it. Leave the workspace in place.

## Step 4: Present the Manual Validation Steps

Present any manual validation steps that are part of the approved work. They may
come from the plan, ticket, or a concise session summary; a separate validation
document is not required. Do not mark human-owned steps done yourself, do not
push/merge/open a PR, and do not advance a ticket past `pending-validation`
until the human confirms completion.

> "Automated validation passed, the branch is squashed, and the worktree is
> cleaned up. Please complete these manual validation steps:
>
> [list the manual steps]
>
> Let me know once they pass. I'll leave integration (push/merge/PR) to you."

## Common Mistakes

**Skipping automated validation**
- **Problem:** Finish unvalidated work
- **Fix:** Always verify automated validation before squashing or cleaning up

**Cleaning up before automated validation passes**
- **Problem:** Lose the worktree while validation is still failing
- **Fix:** Verify automated validation passes (Step 1) before cleanup (Step 3)

**Waiting for manual validation before cleanup**
- **Problem:** Leave the workspace dangling while the human validates
- **Fix:** Clean up after automated validation passes; the manual pass happens in
  the human's own workspace

**Removing a worktree you didn't create**
- **Problem:** Cause phantom state in the host harness
- **Fix:** Only clean up worktrees under `.worktrees/` or `worktrees/`

**Running `git worktree remove` from inside the worktree**
- **Problem:** Command fails silently when CWD is inside the worktree being removed
- **Fix:** Always `cd` to the main repo root before `git worktree remove`

**Offering push/merge/PR**
- **Problem:** Contradicts the skill's contract — integration is the human's job
- **Fix:** End at the manual validation handoff; do not offer integration options

## Red Flags

**Never:**
- Proceed with failing automated validation
- Clean up before automated validation passes
- Wait for manual validation before cleaning up the worktree
- Remove a worktree you didn't create (provenance check)
- Remove a worktree with uncommitted changes unless intentionally discarded
- Treat a successful cleanup command as proof without checking `git worktree list --porcelain`
- Push, merge, open a PR, or offer to
- Advance the ticket past `pending-validation` before the human completes the manual steps

**Always:**
- Verify automated validation before squashing or cleaning up
- Squash the branch's commits into one
- Clean up the worktree after automated validation passes, without waiting for manual validation
- Detect worktree ownership (`GIT_DIR`/`GIT_COMMON`) before removing anything
- `cd` to the main repo root before worktree removal
- Present the manual validation steps to the human and leave integration to them
