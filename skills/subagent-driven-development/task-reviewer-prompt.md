# Task Review Rubric (applied inline)

When an implementer task comes back `DONE`, **you (the controller) review its diff
inline** — do not dispatch a subagent for this. It is a task-scoped gate, not a
merge review; the broad whole-branch review happens separately, dispatched to the
clod code-reviewer. The methodology below mirrors the `reviewer` persona
(`~/.config/polytoken/subagents/reviewer.md`) — apply it yourself.

## Inputs you read

- **Task brief** — the requirements the implementer worked from (`scripts/task-brief PLAN N`).
- **Global constraints** from the spec/design that bind this task (exact values, formats, relationships — copied verbatim).
- **Implementer's report** — its account of what it did: context, not proof.
- **Diff file** — the review-package (`scripts/review-package BASE HEAD`, BASE = the commit recorded before dispatching the implementer). The diff is the source of truth.

## Method

- Read the diff once; it is what shipped — don't re-derive it, and don't trust the report over the diff.
- Don't re-run tests the implementer already ran on the same code — its report carries the test evidence.
- Don't pre-judge or suppress findings. If you catch yourself thinking "at most Minor" or "the checklist chose this," stop — raise it and adjudicate it in the fix loop, don't spare yourself the loop.

## Two verdicts (both required)

- **Spec compliance** (`compliant` | `issues_found`): built exactly what the brief required — nothing missing, nothing extra (catches over- and under-build).
- **Quality** (`approved` | `needs_fixes`): severity-classified findings (Critical / Important / Minor).

## Outcome

- **Critical / Important** → dispatch a fix implementer (clod) with the findings, then re-review the updated diff inline. Loop until spec ✅ and quality approved.
- **Minor** → record in the progress ledger for the final whole-branch review to triage.
- **⚠️ Can't-verify-from-diff** items (requirements living in unchanged code or spanning tasks) → resolve directly; you hold the cross-task context the diff lacks. A confirmed gap is a failed spec review — send it back to a fix implementer.
