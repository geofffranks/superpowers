# Code Reviewer Subagent Dispatch Template

Dispatch the `reviewer` subagent (defined in
`~/.config/polytoken/subagents/reviewer.md`) to review completed work against
its requirements and quality standards. Its methodology — read the diff,
spec-compliance + quality verdict, severity calibration — lives in the
definition. Pass only task-specific context.

```
Subagent (reviewer):
  model: [optional override — per the dispatching skill's Model Selection;
         the definition defaults to default_model:full]
  prompt: |
    Review the completed work against its requirements and code quality
    standards before it cascades into more work.

    ## What Was Implemented

    [DESCRIPTION — brief summary of what was built]

    ## Requirements / Plan

    [PLAN_OR_REQUIREMENTS — plan file path, task text, or requirements]

    ## Diff to Review

    Diff file: [DIFF_FILE]
    (Generate it first: `git diff --stat [BASE_SHA]..[HEAD_SHA]` and
    `git diff [BASE_SHA]..[HEAD_SHA]` redirected to a file, or use
    subagent-driven-development's `scripts/review-package BASE HEAD`.)

    Review scope: whole-branch (or task-scoped, per the dispatching skill).
```

**Placeholders:**
- `[DESCRIPTION]` — brief summary of what was built
- `[PLAN_OR_REQUIREMENTS]` — plan file path, task text, or requirements
- `[BASE_SHA]` — starting commit
- `[HEAD_SHA]` — ending commit
- `[DIFF_FILE]` — the file path the controller wrote the diff to

**Reviewer returns:** `exit_tool` with `verdict` (approved | needs_fixes), `spec_compliance` (compliant | issues_found), `summary` (strengths + issues by severity), `report_file`.
