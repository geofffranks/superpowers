---
name: subagent-driven-development
description: Use when executing implementation plans with independent tasks in the current session
---

# Subagent-Driven Development

Execute the task checklist by dispatching a fresh implementer subagent per task, reviewing each task's diff **inline yourself** (spec compliance + code quality), and dispatching a broad whole-branch review at the end.

**Dispatch via clod-subagent (preferred), harness fallback:** implementer and the final code-reviewer run through the `clod-subagent` MCP tool — a detached `claude -p` with a chosen model and a system prompt. Call `mcp__clod-subagent__subagent` with the role's `model` and `system_prompt` = the body of `~/.config/polytoken/subagents/<role>.md` (drop the YAML frontmatter and the trailing `Prompt:` / `{{ prompt }}` lines), and `prompt` = the filled dispatch recipe, which must ask for the report as labeled **text sections** (clod returns plain text, so the Polytoken exit-tool schema is replaced by text you parse). If `clod-subagent` is not connected, fall back to dispatching the harness subagent with the same recipe. Roles: **implementer → `claude-sonnet-5`** (`implementer.md`); **final code-reviewer → `claude-opus-4-8`** (`reviewer.md`).

**Why subagents:** You delegate tasks to specialized agents with isolated context. By precisely crafting their instructions and context, you ensure they stay focused and succeed at their task. They should never inherit your session's context or history — you construct exactly what they need. This also preserves your own context for coordination work.

**Core principle:** Fresh subagent per task + inline task review (spec + quality) + broad final review = high quality, fast iteration

**Narration:** between tool calls, narrate at most one short line — the
ledger and the tool results carry the record.

**Continuous execution:** Do not pause to check in with your human partner between tasks. Execute all tasks from the plan without stopping. The only reasons to stop are: BLOCKED status you cannot resolve, ambiguity that genuinely prevents progress, or all tasks complete. "Should I continue?" prompts and progress summaries waste their time — they asked you to execute the plan, so execute it.

## When to Use

```dot
digraph when_to_use {
    "Have implementation plan?" [shape=diamond];
    "Tasks mostly independent?" [shape=diamond];
    "Stay in this session?" [shape=diamond];
    "subagent-driven-development" [shape=box];
    "executing-plans" [shape=box];
    "Manual execution or brainstorm first" [shape=box];

    "Have implementation plan?" -> "Tasks mostly independent?" [label="yes"];
    "Have implementation plan?" -> "Manual execution or brainstorm first" [label="no"];
    "Tasks mostly independent?" -> "Stay in this session?" [label="yes"];
    "Tasks mostly independent?" -> "Manual execution or brainstorm first" [label="no - tightly coupled"];
    "Stay in this session?" -> "subagent-driven-development" [label="yes"];
    "Stay in this session?" -> "executing-plans" [label="no - parallel session"];
}
```

**vs. Executing Plans (parallel session):**
- Same session (no context switch)
- Fresh subagent per task (no context pollution)
- Review after each task (spec compliance + code quality), broad review at the end
- Faster iteration (no human-in-loop between tasks)

## The Process

```dot
digraph process {
    rankdir=TB;

    subgraph cluster_per_task {
        label="Per Task";
        "Dispatch implementer via clod (sonnet-5, implementer.md) / harness fallback" [shape=box];
        "Implementer asks questions?" [shape=diamond];
        "Answer questions, provide context" [shape=box];
        "Implementer implements, tests, commits, self-reviews" [shape=box];
        "Generate diff file, review it INLINE (task-review rubric)" [shape=box];
        "Spec ✅ and quality approved?" [shape=diamond];
        "Dispatch fix implementer via clod for Critical/Important findings" [shape=box];
        "Mark task complete in todo list and progress ledger" [shape=box];
    }

    "Read checklist, note context and global constraints, create todos" [shape=box];
    "More tasks remain?" [shape=diamond];
    "Dispatch final code-reviewer via clod (opus, reviewer.md) / harness fallback" [shape=box];
    "Use superpowers:finishing-a-development-branch" [shape=box style=filled fillcolor=lightgreen];

    "Read checklist, note context and global constraints, create todos" -> "Dispatch implementer via clod (sonnet-5, implementer.md) / harness fallback";
    "Dispatch implementer via clod (sonnet-5, implementer.md) / harness fallback" -> "Implementer asks questions?";
    "Implementer asks questions?" -> "Answer questions, provide context" [label="yes"];
    "Answer questions, provide context" -> "Dispatch implementer via clod (sonnet-5, implementer.md) / harness fallback";
    "Implementer asks questions?" -> "Implementer implements, tests, commits, self-reviews" [label="no"];
    "Implementer implements, tests, commits, self-reviews" -> "Generate diff file, review it INLINE (task-review rubric)";
    "Generate diff file, review it INLINE (task-review rubric)" -> "Spec ✅ and quality approved?";
    "Spec ✅ and quality approved?" -> "Dispatch fix implementer via clod for Critical/Important findings" [label="no"];
    "Dispatch fix implementer via clod for Critical/Important findings" -> "Generate diff file, review it INLINE (task-review rubric)" [label="re-review"];
    "Spec ✅ and quality approved?" -> "Mark task complete in todo list and progress ledger" [label="yes"];
    "Mark task complete in todo list and progress ledger" -> "More tasks remain?";
    "More tasks remain?" -> "Dispatch implementer via clod (sonnet-5, implementer.md) / harness fallback" [label="yes"];
    "More tasks remain?" -> "Dispatch final code-reviewer via clod (opus, reviewer.md) / harness fallback" [label="no"];
    "Dispatch final code-reviewer via clod (opus, reviewer.md) / harness fallback" -> "Use superpowers:finishing-a-development-branch";
}
```

## Pre-Flight Plan Review

Before dispatching Task 1, scan the plan once for conflicts:

- tasks that contradict each other or the plan's Global Constraints
- anything the plan explicitly mandates that the review rubric treats as a
  defect (a test that asserts nothing, verbatim duplication of a logic block)

Present everything you find to your human partner as one batched question —
each finding beside the plan text that mandates it, asking which governs —
before execution begins, not one interrupt per discovery mid-plan. If the
scan is clean, proceed without comment. The review loop remains the net for
conflicts that only emerge from implementation.

## Model Selection

Models are fixed by role in the clod dispatch: the **implementer** (and fix
implementers) run on `claude-sonnet-5`; the **final whole-branch code-reviewer**
runs on `claude-opus-4-8`. Per-task review is done inline by you — no model to
pick. Pass these as the clod `model` argument.

**Harness fallback:** when `clod-subagent` is not connected, the harness
subagents use their Polytoken definition defaults (`implementer` →
`default_model:mini`, `reviewer` → `default_model:full`); override by exception
only, guided by the signals below.

**Task complexity signals (implementation tasks):**
- Touches 1-2 files with a complete spec → the sonnet-5 default is fine
- Touches multiple files with integration concerns, or requires design judgment
  or broad codebase understanding → consider the harness path with a more capable
  model, or split the task smaller

## Handling Implementer Status

Implementer subagents report one of four statuses. Handle each appropriately:

**DONE:** Generate the review package (`scripts/review-package BASE HEAD`, from this skill's directory — it prints the unique file path it wrote; BASE is the commit you recorded before dispatching the implementer — never `HEAD~1`, which silently drops all but the last commit of a multi-commit task), then review that diff **inline yourself** against the task-review rubric (see "Task Review (inline)").

**DONE_WITH_CONCERNS:** The implementer completed the work but flagged doubts. Read the concerns before proceeding. If the concerns are about correctness or scope, address them before review. If they're observations (e.g., "this file is getting large"), note them and proceed to review.

**NEEDS_CONTEXT:** The implementer needs information that wasn't provided. Provide the missing context and re-dispatch.

**BLOCKED:** The implementer cannot complete the task. Assess the blocker:
1. If it's a context problem, provide more context and re-dispatch with the same model
2. If the task requires more reasoning, re-dispatch with a more capable model
3. If the task is too large, break it into smaller pieces
4. If the plan itself is wrong, escalate to the human

**Never** ignore an escalation or force the same model to retry without changes. If the implementer said it's stuck, something needs to change.

## Handling ⚠️ Items During Inline Review

While reviewing a task's diff inline, you may hit "⚠️ Cannot verify from diff"
items — requirements that live in unchanged code or span tasks. You already hold
the checklist and cross-task context, so resolve each one directly before marking
the task complete. If you confirm an item is a real gap, treat it as a failed spec
review — send it back to the implementer (dispatch a fix implementer) and
re-review.

## Task Review (inline)

Per-task reviews are task-scoped gates you perform **inline** — you review the
task's diff yourself against the rubric in
[task-reviewer-prompt.md](task-reviewer-prompt.md) (spec-compliance verdict +
quality verdict with severity-classified findings). The broad review happens once,
at the end, dispatched to the clod code-reviewer. Apply the same discipline
inline that you would demand of a dispatched reviewer:

- Do not add open-ended directives like "check all uses" or "run race tests
  if useful" without a concrete, task-specific reason
- Do not ask a reviewer to re-run tests the implementer already ran on the
  same code — the implementer's report carries the test evidence
- Do not pre-judge findings for the reviewer — never instruct a reviewer to
  ignore or not flag a specific issue. If you believe a finding would be a
  false positive, let the reviewer raise it and adjudicate it in the review
  loop. If the prompt you are writing contains "do not flag," "don't treat X
  as a defect," "at most Minor," or "the plan chose" — stop: you are
  pre-judging, usually to spare yourself a review loop.
- The global-constraints block is your attention lens when reviewing inline
  (and the block you hand the final clod reviewer). Copy the binding
  requirements verbatim from the design doc's Global Constraints / the spec:
  exact values, exact formats, and the stated relationships between components
  ("same layout as X", "matches Y"). The task-reviewer rubric already carries
  the process rules (YAGNI, test hygiene, review method) — the constraints block
  is for what THIS project's spec demands.
- Get the diff as a file: run this skill's `scripts/review-package BASE HEAD`
  (or, without bash: `git log --oneline`, `git diff --stat`, and
  `git diff -U10` for the range, redirected to one uniquely named file). Read
  it for the inline review — or pass its path to the final clod reviewer. The
  package gives the commit list, stat summary, and full diff with context in one
  Read. Use the BASE you recorded before dispatching the implementer — never
  `HEAD~1`, which silently truncates multi-commit tasks.
- A dispatch prompt describes one task, not the session's history. Do not
  paste accumulated prior-task summaries ("state after Tasks 1-3") into
  later dispatches — a real session's dispatch hit 42k chars of which 99%
  was pasted history. A fresh subagent needs its task, the interfaces it
  touches, and the global constraints. Nothing else.
- Dispatch fix subagents for Critical and Important findings. Record Minor
  findings in the progress ledger as you go, and point the final
  whole-branch review at that list so it can triage which must be fixed
  before merge. A roll-up nobody reads is a silent discard.
- A finding labeled plan-mandated — or any finding that conflicts with
  what the plan's text requires — is the human's decision, like any plan
  contradiction: present the finding and the plan text, ask which governs.
  Do not dismiss the finding because the plan mandates it, and do not
  dispatch a fix that contradicts the plan without asking.
- The final whole-branch review gets a package too: run
  `scripts/review-package MERGE_BASE HEAD` (MERGE_BASE = the commit the
  branch started from, e.g. `git merge-base main HEAD`) and include the
  printed path in the final review dispatch, so the final reviewer reads
  one file instead of re-deriving the branch diff with git commands.
- Every fix dispatch carries the implementer contract: the fix subagent
  re-runs the tests covering its change and reports the results. Name the
  covering test files in the dispatch — a one-line fix does not need the
  whole suite. Before re-dispatching the reviewer, confirm the fix report
  contains the covering tests, the command run, and the output; dispatch
  the re-review once all three are present.
- If the final whole-branch review returns findings, dispatch ONE fix
  subagent with the complete findings list — not one fixer per finding.
  Per-finding fixers each rebuild context and re-run suites; a real
  session's final-review fix wave cost more than all its tasks combined.

## File Handoffs

Everything you paste into a dispatch prompt — and everything a subagent
prints back — stays resident in your context for the rest of the session
and is re-read on every later turn. Hand artifacts over as files:

- **Task brief:** before dispatching an implementer, run this skill's
  `scripts/task-brief PLAN_FILE N` — it extracts the task's full text to a
  uniquely named file and prints the path. Compose the dispatch so the
  brief stays the single source of requirements. Your dispatch should
  contain: (1) one line on where this task fits in the project; (2) the
  brief path, introduced as "read this first — it is your requirements,
  with the exact values to use verbatim"; (3) interfaces and decisions
  from earlier tasks that the brief cannot know; (4) your resolution of
  any ambiguity you noticed in the brief; (5) the report-file path and
  report contract. Exact values (numbers, magic strings, signatures, test
  cases) appear only in the brief.
- **Report file:** name the implementer's report file after the brief
  (brief `…/task-N-brief.md` → report `…/task-N-report.md`) and put it in
  the dispatch prompt. The implementer writes the full report there and
  returns only status, commits, a one-line test summary, and concerns.
- **Task-review inputs (inline):** to review a task, you read three files —
  the same brief file, the report file, and the review package — against the
  global constraints that bind the task. (The final whole-branch review is the
  one that gets these handed to it as a dispatched clod reviewer.)
- Fix dispatches append their fix report (with test results) to the same
  report file and return a short summary; re-reviews read the updated file.

## Durable Progress

Conversation memory does not survive compaction. In real sessions,
controllers that lost their place have re-dispatched entire completed task
sequences — the single most expensive failure observed. Track progress in
a ledger file, not only in todos.

- At skill start, check for a ledger:
  `cat "$(git rev-parse --show-toplevel)/.superpowers/sdd/progress.md"`. Tasks listed there
  as complete are DONE — do not re-dispatch them; resume at the first task
  not marked complete.
- When a task's review comes back clean, append one line to the ledger in
  the same message as your other bookkeeping:
  `Task N: complete (commits <base7>..<head7>, review clean)`.
- The ledger is your recovery map: the commits it names exist in git even
  when your context no longer remembers creating them. After compaction,
  trust the ledger and `git log` over your own recollection.
- `git clean -fdx` will destroy the ledger (it's git-ignored scratch); if
  that happens, recover from `git log`.

## Prompt Templates

- [implementer-prompt.md](implementer-prompt.md) - Dispatch recipe for the implementer (clod `system_prompt` = `implementer.md`, sonnet-5; or harness `implementer` type)
- [task-reviewer-prompt.md](task-reviewer-prompt.md) - The rubric you apply **inline** for each task's review (not dispatched)
- Final whole-branch review: use superpowers:requesting-code-review's [code-reviewer.md](../requesting-code-review/code-reviewer.md) - Dispatch recipe for the final clod code-reviewer (`reviewer.md`, opus; or harness `reviewer` type)

## Example Workflow

```
You: I'm using Subagent-Driven Development to execute this task checklist.

[Read the design doc's ## Implementation Tasks once: docs/superpowers/<tkid>-<slug>/design_spec.md]
[Create todos for all tasks]

Task 1: Hook installation script

[Run task-brief for Task 1; dispatch implementer with brief + report paths + context]

Implementer: "Before I begin - should the hook be installed at user or system level?"

You: "User level (~/.config/superpowers/hooks/)"

Implementer: "Got it. Implementing now..."
[Later] Implementer:
  - Implemented install-hook command
  - Added tests, 5/5 passing
  - Self-review: Found I missed --force flag, added it
  - Committed

[Run review-package, review the diff INLINE against the task-review rubric]
Inline review: Spec ✅ - all requirements met, nothing extra.
  Strengths: Good test coverage, clean. Issues: None. Task quality: Approved.

[Mark Task 1 complete]

Task 2: Recovery modes

[Run task-brief for Task 2; dispatch implementer with brief + report paths + context]

Implementer: [No questions, proceeds]
Implementer:
  - Added verify/repair modes
  - 8/8 tests passing
  - Self-review: All good
  - Committed

[Run review-package, review the diff INLINE against the task-review rubric]
Inline review: Spec ❌:
  - Missing: Progress reporting (spec says "report every 100 items")
  - Extra: Added --json flag (not requested)
  Issues (Important): Magic number (100)

[Dispatch fix implementer via clod with all findings]
Fixer: Removed --json flag, added progress reporting, extracted PROGRESS_INTERVAL constant

[Review the updated diff INLINE again]
Inline review: Spec ✅. Task quality: Approved.

[Mark Task 2 complete]

...

[After all tasks]
[Dispatch final code-reviewer via clod (opus, reviewer.md) / harness fallback]
Final reviewer: All requirements met, ready to merge

Done!
```

## Advantages

**vs. Manual execution:**
- Subagents follow TDD naturally
- Fresh context per task (no confusion)
- Parallel-safe (subagents don't interfere)
- Subagent can ask questions (before AND during work)

**vs. Executing Plans:**
- Same session (no handoff)
- Continuous progress (no waiting)
- Review checkpoints automatic

**Efficiency gains:**
- Controller curates exactly what context is needed; bulk artifacts move
  as files, not pasted text
- Subagent gets complete information upfront
- Questions surfaced before work begins (not after)

**Quality gates:**
- Self-review catches issues before handoff
- Task review carries two verdicts: spec compliance and code quality
- Review loops ensure fixes actually work
- Spec compliance prevents over/under-building
- Code quality ensures implementation is well-built

**Cost:**
- More subagent invocations (implementer + reviewer per task)
- Controller does more prep work (extracting all tasks upfront)
- Review loops add iterations
- But catches issues early (cheaper than debugging later)

## Red Flags

**Never:**
- Start implementation on main/master branch without explicit user consent
- Skip task review, or accept a report missing either verdict (spec compliance AND task quality are both required)
- Proceed with unfixed issues
- Dispatch multiple implementation subagents in parallel (conflicts)
- Make a subagent read the whole plan file (hand it its task brief —
  `scripts/task-brief` — instead)
- Skip scene-setting context (subagent needs to understand where task fits)
- Ignore subagent questions (answer before letting them proceed)
- Accept "close enough" on spec compliance (reviewer found spec issues = not done)
- Skip review loops (reviewer found issues = implementer fixes = review again)
- Let implementer self-review replace actual review (both are needed)
- Tell a reviewer what not to flag, or pre-rate a finding's severity in the
  dispatch prompt ("treat it as Minor at most") — the plan's example code is
  a starting point, not evidence that its weaknesses were chosen
- Review a task without generating the diff file first
  (`scripts/review-package BASE HEAD`) — read the package, don't eyeball
  `git diff` from memory
- Move to next task while the review has open Critical/Important issues
- Re-dispatch a task the progress ledger already marks complete — check
  the ledger (and `git log`) after any compaction or resume

**If subagent asks questions:**
- Answer clearly and completely
- Provide additional context if needed
- Don't rush them into implementation

**If reviewer finds issues:**
- Implementer (same subagent) fixes them
- Reviewer reviews again
- Repeat until approved
- Don't skip the re-review

**If subagent fails task:**
- Dispatch fix subagent with specific instructions
- Don't try to fix manually (context pollution)

## Integration

**Required workflow skills:**
- **superpowers:using-git-worktrees** - Ensures isolated workspace (creates one or verifies existing)
- **superpowers:brainstorming** - Produces the design doc whose `## Implementation Tasks` checklist this skill executes
- **superpowers:requesting-code-review** - Code review template for the final whole-branch review (dispatched to the clod code-reviewer)
- **superpowers:finishing-a-development-branch** - Complete development after all tasks

**Subagents should use:**
- **superpowers:test-driven-development** - Subagents follow TDD for each task

**Alternative workflow:**
- **superpowers:executing-plans** - Use for parallel session instead of same-session execution
