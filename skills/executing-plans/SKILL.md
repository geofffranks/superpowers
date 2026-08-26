---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Classify the approved work first, then load only the coordination needed for its risk and scope. For class-1 cleanup, execute directly and report concise evidence; for larger work, load the plan, review it critically, execute the applicable tasks, and report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Subagent-driven development is an option for genuinely independent multi-task work, not a default for small docs, metadata, or config cleanup.

## Proportionality classification

Classify the approved request before creating todos, loading sub-skills, or applying a development lifecycle:

1. **Small mechanical metadata/docs/config cleanup** — contained wording, metadata, or configuration edits with no design trade-off or product implementation.
2. **Ordinary single-session implementation** — a bounded feature, bug fix, or refactor that can be completed in one session.
3. **Multi-session or parallel implementation** — work requiring handoff, independent task coordination, or parallel contributors.
4. **Qualification-, security-, migration-, or audit-sensitive work** — work whose evidence, rollback, provenance, or approval has a continuing operational or compliance purpose.

Explicit scope language controls. If the request says it is a small planning/docs/metadata cleanup and excludes RFCs, tickets, artifacts, or formal review, do not reintroduce those through generic defaults.

**Required shared policy:** Use `superpowers:artifact-retention-policy` when deciding whether an execution artifact is temporary, attached to a ticket, or durable.

### Class 1: direct execution

Execute directly from the approved request or plan. An approved plan is already the plan; do not mirror numbered steps into a second design, task brief, validation plan, or todo graph. Create todos only when they materially help continuation. Do not require subagents, a worktree, TDD, code review, a validator, or `finishing-a-development-branch` merely because a plan exists. Use one focused final verification pass and report results concisely.

A referenced sub-skill may be declared inapplicable when it assumes code implementation, worktrees, test suites, squashing, or manual validation that this scope does not have.

### Classes 2–4: execute the plan

1. Read the plan and review it for real contradictions or blockers.
2. Raise genuine concerns before starting; do not manufacture ceremony when the plan is clear.
3. Create todos only when they provide useful progress/recovery state; the plan remains the authoritative task list.
4. For each task, follow the plan, run the smallest specified verification, and record completion.
5. Apply reviews, subagents, worktrees, and finalization only when required by the classification, risk, or approved plan.

After implementation, use `verification-before-completion` to perform sufficient final verification. Use `finishing-a-development-branch` only when branch/worktree integration, squashing, or human manual validation is actually part of the work.

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent

## Integration

For classes 2–4, load only the sub-skills that match the approved scope and classification:
- `superpowers:using-git-worktrees` when isolation is genuinely necessary.
- `superpowers:brainstorming` when the work needs a new design rather than an already approved plan.
- `superpowers:finishing-a-development-branch` when branch/worktree integration, squashing, or human manual validation is part of the work.

These are not required for class-1 direct execution. A sub-skill whose assumptions do not fit the scope may be declared inapplicable.
