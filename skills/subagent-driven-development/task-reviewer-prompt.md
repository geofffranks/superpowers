# Task Reviewer Subagent Dispatch Template

Dispatch the `reviewer` subagent (defined in
`~/.config/polytoken/subagents/reviewer.md`) to review one task's diff.
Its methodology — read the diff once, don't re-derive it, don't trust the
report, don't re-run tests, spec-compliance + quality rubric, severity
calibration — lives in the definition. Pass only task-specific context.

```
Subagent (reviewer):
  model: [optional override — per SKILL.md Model Selection; the definition
         defaults to default_model:full]
  prompt: |
    Review this task's implementation. This is a task-scoped gate, not a
    merge review — a broad whole-branch review happens separately.

    ## What Was Requested

    Task brief: [BRIEF_FILE]

    Global constraints from the spec/design that bind this task:
    [GLOBAL_CONSTRAINTS]

    ## Implementer's Report

    [REPORT_FILE]

    ## Diff Under Review

    Diff file: [DIFF_FILE]

    Review scope: task-scoped.
```

**Placeholders:**
- `[BRIEF_FILE]` — REQUIRED: the task brief (same file the implementer worked from)
- `[REPORT_FILE]` — REQUIRED: the implementer's report file
- `[DIFF_FILE]` — REQUIRED: the review-package path (`scripts/review-package BASE HEAD` prints it)
- `[GLOBAL_CONSTRAINTS]` — binding requirements copied verbatim from the plan/spec

**Reviewer returns:** `exit_tool` with `verdict` (approved | needs_fixes), `spec_compliance` (compliant | issues_found), `summary`, `report_file`.
