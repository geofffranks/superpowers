---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

**Integration safety rule:** Never merge, overlay, move a branch ref, reset, or clean a dirty target worktree. Named feature worktrees are preserved exactly; disposable integration worktrees are explicitly manifested and cleaned only after result verification.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: Detect Environment

**Determine workspace state before presenting options:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | No cleanup (externally managed) |

### Step 3: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 4: Present Options

**Normal repo and named-branch worktree — present exactly these 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Detached HEAD — present exactly these 3 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 5: Execute Choice

#### Option 1: Merge Locally

Before merging, record the target worktree fingerprint and inspect all linked worktrees:

```bash
git status --short --branch
git diff --cached --stat
git diff --cached --name-only
git worktree list --porcelain
```

If the target worktree has staged or unstaged changes, stop and preserve it. Do not merge there. Use a clean disposable integration worktree with a manifest (`path`, `purpose`, `base`, `owner`, `cleanup`) and a cleanup trap, or ask the human to commit/shelve the dirty work first.

```bash
set -euo pipefail
MAIN_ROOT=$(git rev-parse --show-toplevel)
TMP="$MAIN_ROOT/.worktrees/tmp-merge-<slug>-$$"
cleanup() {
  if ! git -C "$MAIN_ROOT" worktree remove --force "$TMP"; then
    echo "temporary worktree cleanup failed: $TMP" >&2
    return 1
  fi
  if git -C "$MAIN_ROOT" worktree list --porcelain | grep -Fqx "worktree $TMP"; then
    echo "temporary worktree still registered after cleanup: $TMP" >&2
    return 1
  fi
}
trap cleanup EXIT INT TERM
git worktree add --detach "$TMP" <base-branch>
git -C "$TMP" merge --no-ff <feature-branch> -m "Merge <feature-branch>"
# Verify exact changed paths, resulting commit, and tests in "$TMP".
```

Only after the merged result is verified may the named feature worktree be removed according to Step 6 and the branch deleted. Never broadly prune unrelated worktrees.

Then: Cleanup worktree (Step 6), then delete branch:

```bash
git branch -d <feature-branch>
```

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>
```

**Do NOT clean up worktree** — user needs it alive to iterate on PR feedback.

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then: Cleanup worktree (Step 6), then force-delete branch:
```bash
git branch -D <feature-branch>
```

### Step 6: Cleanup Workspace

**Only runs for Options 1 and 4.** Options 2 and 3 always preserve the worktree.

For disposable worktrees created during Options 1 or 4, cleanup is unconditional and scoped to the exact manifest path. Install the cleanup trap before creation, verify the expected commit is reachable, then remove that path from the repository root. If cleanup fails, report the remaining path; do not silently continue. For named feature worktrees, cleanup requires provenance from `git worktree list --porcelain`, a successful merge/discard decision, and an explicit branch/path match.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If worktree path is under `.worktrees/` or `worktrees/`:** Superpowers created this worktree — we own cleanup.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment (harness) owns this workspace. Do NOT remove it. If your platform provides a workspace-exit tool, use it. Otherwise, leave the workspace in place.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| 4. Discard | - | - | - | yes (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" is ambiguous
- **Fix:** Present exactly 4 structured options (or 3 for detached HEAD)

**Cleaning up worktree for Option 2**
- **Problem:** Remove worktree user needs for PR iteration
- **Fix:** Only cleanup for Options 1 and 4

**Deleting branch before removing worktree**
- **Problem:** `git branch -d` fails because worktree still references the branch
- **Fix:** Merge first, remove worktree, then delete branch

**Running git worktree remove from inside the worktree**
- **Problem:** Command fails silently when CWD is inside the worktree being removed
- **Fix:** Always `cd` to main repo root before `git worktree remove`

**Cleaning up harness-owned worktrees**
- **Problem:** Removing a worktree the harness created causes phantom state
- **Fix:** Only clean up worktrees under `.worktrees/` or `worktrees/`

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Merge or overlay into a worktree with staged or unstaged changes
- Delete work without confirmation
- Force-push without explicit request
- Remove a worktree before confirming merge success
- Clean up worktrees you didn't create (provenance check)
- Reuse an unowned scratch path
- Run `git worktree remove` from inside the worktree
- Treat a successful cleanup command as proof without checking `git worktree list --porcelain`

**Always:**
- Verify tests before offering options
- Detect environment before presenting menu
- Record the target status/index fingerprint and `git worktree list --porcelain` before integration
- Present exactly 4 options (or 3 for detached HEAD)
- Get typed confirmation for Option 4
- Use a manifest and cleanup trap for every disposable worktree
- Clean up worktree for Options 1 & 4 only
- `cd` to main repo root before worktree removal
- Verify the exact expected result and changed paths before cleanup
- Run `git worktree prune` after removal, scoped to the operation
