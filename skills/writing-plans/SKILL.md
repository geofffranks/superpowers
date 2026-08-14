---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## When this skill applies

This is the **full-plan branch** of the brainstorming end-fork — reach for it when
the work is large, needs subagent-parallel execution, or will be handed to a
separate session with no shared context. For the common case, the design doc's own
`## Implementation Tasks` checklist is the plan and you implement in-session
(lightweight path) without a separate `plan.md`. Invoke this skill when the
end-fork selects Full plan, or directly when you already have a spec and want a
fully-specified plan.

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `superpowers:using-git-worktrees` skill at execution time.

## Plan-Writer Handoff

This handoff is owned by the primary agent. Before drafting or editing any plan, the primary agent dispatches the runtime `plan-writer` persona with the reviewed spec path and the required output path. A `plan-writer` running this skill does not dispatch another `plan-writer` or any other subagent.

The `plan-writer` owns both normal repository investigation and first-draft authorship. It must:

1. Read the complete spec and extract every requirement, constraint, and acceptance criterion.
2. Investigate the repository locally to verify exact file paths, existing patterns, interfaces, tests, and commands; report facts with paths and line references in its working notes or handoff.
3. Write the complete plan to `docs/superpowers/<tkid>-<slug>/plan.md` (or the user-approved destination), using the spec as the source of truth and the repository evidence to make every task actionable.
4. Return the plan path, evidence gathered, assumptions, and any blocked or missing inputs.

A separate `researcher` is not part of normal plan creation. The primary agent may dispatch one before `plan-writer` only for a bounded prerequisite question that requires capabilities unavailable to `plan-writer`, such as current external research. Resolve that question or provide its evidence artifact to `plan-writer` before plan drafting begins.

After `plan-writer` returns, the primary agent reviews the draft, performs the self-review below, and dispatches `plan-reviewer`; it does not author a competing inline plan or substitute a generic `researcher` for `plan-writer`. If `plan-writer` cannot run, lacks the reviewed spec, or cannot write the requested plan, stop with `BLOCKED`, report the exact missing input or failure, and ask the human partner how to proceed. Do not silently fall back to inline authorship.

**Save plans to:** `docs/superpowers/<tkid>-<slug>/plan.md` — the same `<tkid>-<slug>` directory the design doc lives in
- (User preferences for plan location override this default)
- **Never commit.** docs/superpowers artifacts are local working docs, not version control — never `git add` or `git commit` them

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in. This mapping is part of the `plan-writer`'s normal repository investigation, not a separate `researcher` handoff.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. When drawing task boundaries: fold setup,
configuration, scaffolding, and documentation steps into the task whose
deliverable needs them; split only where a reviewer could meaningfully
reject one task while approving its neighbor. Each task ends with an
independently testable deliverable.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

---
```

## Required Setup, Code Review, and Finalize Tasks

Every plan wraps its tasks in three fixed bookends. **Setup** is the first task, **Code Review** is the second-to-last, and **Finalize** is the last, in that order.

**Setup (first task):** start the ticket / work item (`tk start <id>` where Herdle is in use), create the work branch from the repository's default branch, and record the branch on the ticket.

**Code Review (second-to-last task):** run one fresh final integration review of the full branch diff against its base; address valid Critical/Important findings as one complete fixer batch, then rereview only after branch-changing fixes. Defer the review mechanics to `requesting-code-review`.

**Finalize (last task):** write the **validation plan** split into **automated** and **manual** sections with concrete runnable steps; run the **automated validation** and fix defects until it passes; **squash** the branch's commits into one; and present the **manual validation steps** to the human for completion. Do not mark the manual steps done yourself.

Write Finalize with the same concrete, non-placeholder steps as any other task (see "No Placeholders"). Where Herdle is in use, `herdle-tk-artifacts` supplies the lifecycle/gatekeeper stamping (`tk start`, `branch:` frontmatter, `lifecycle:` transitions) that wraps these bookends.

## Task Structure

Every task is one independently testable behavioral slice. Split before dispatch when a task combines independently testable behaviors, unrelated subsystems, unresolved design with implementation, or cannot state one focused test intent and one done condition. More than four production files, multiple package roots, or refactor-plus-behavior are warning thresholds, not automatic failure; a genuinely cohesive multi-file slice crossing one must include a non-empty cohesion override explaining the boundary. File count is not a hard failure by itself. Preserve review intent for the later final integration review, and do not paste prior plan/history into dispatch prompts.

Use this S1-compatible recipe for every task:

````markdown
### Task 1: Implement bounded parser behavior

**Files:**
- Modify: `src/parser.py`
- Test: `tests/test_parser.py`

**Focused behavior:** Parse one bounded task into durable artifacts.

**Test intent:** Verify valid input is accepted and invalid input is rejected precisely.

**Inherited interfaces:**
- None

**Out of scope:**
- Unrelated Markdown extensions

**Done when:** The parser publishes the brief and manifest together.

**Review intent:** Verify task-local parsing and defer branch-wide integration review.

**Cohesion override:** Keep the parser and its focused test together because they form one independently testable behavior.

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Primary-Agent Self-Review

After `plan-writer` returns the complete plan, the primary agent looks at the spec with fresh eyes and checks the plan against it. This is the primary agent's quick acceptance pass—not part of `plan-writer` authorship—before it dispatches the independent `plan-reviewer` for a thorough second pass.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Plan-reviewer dispatch

After the inline self-review, dispatch the `plan-reviewer` subagent with the
plan path and spec-for-reference path (template:
plan-document-reviewer-prompt.md). The inline check is a quick first pass; the
plan-reviewer is a thorough single-pass spot check. Apply its findings by
severity:

- **Critical / High:** fix, then re-review so the fix is verified.
- **Medium / Low / Nit:** fix (or rebut) and move on — re-reviewing is **not**
  required.

Ready for the execution handoff means every finding is fixed or rebutted; it
does not require another reviewer pass. Re-dispatch the plan-reviewer only when
a Critical/High fix changed the plan's substance.

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/superpowers/<tkid>-<slug>/plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review
