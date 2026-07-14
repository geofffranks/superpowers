# Implementer Subagent Dispatch Template

Dispatch the `implementer` subagent (defined in
`~/.config/polytoken/subagents/implementer.md`) to implement one plan task.
Its methodology — TDD loop, code-organization rules, self-review, escalation,
report contract — lives in the definition. Pass only task-specific context.

```
Subagent (implementer):
  model: [optional override — per SKILL.md Model Selection; the definition
         defaults to default_model:mini]
  prompt: |
    You are implementing Task N: [task name]

    ## Task

    Read your task brief first: [BRIEF_FILE]
    It is your single source of requirements, with exact values to use verbatim.

    ## Context

    [Scene-setting: where this task fits, dependencies, architectural context,
    interfaces and decisions from earlier tasks the brief cannot know]

    ## Global Constraints

    [GLOBAL_CONSTRAINTS — binding requirements copied verbatim from the plan's
    Global Constraints section or the spec]

    Work from: [directory]

    Report file: [REPORT_FILE] — write your full report here.
```

**Placeholders:**
- `[BRIEF_FILE]` — REQUIRED: task brief path (`scripts/task-brief PLAN N` prints it)
- `[REPORT_FILE]` — REQUIRED: where the implementer writes its full report
- `[GLOBAL_CONSTRAINTS]` — binding requirements from the plan/spec (exact values, formats, relationships — not process rules)

**Implementer returns:** `exit_tool` with `status` (DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT), `summary`, `commits`, `test_summary`, `concerns`, `report_file`. Detail lives in the report file, not the exit payload.
