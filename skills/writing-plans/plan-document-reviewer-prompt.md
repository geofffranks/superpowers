# Plan Document Reviewer Subagent Dispatch Template

Dispatch the `plan-reviewer` subagent to review the written plan for
completeness, spec alignment, task decomposition, and buildability. The
subagent inspects the document and relevant code/context, and returns
severity-classified findings. Pass only the plan path and spec reference.

```
Subagent (plan-reviewer):
  prompt: |
    Review this plan document before it is handed off to implementation.

    **Plan to review:** [PLAN_FILE_PATH]
    **Spec for reference:** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Completeness | TODOs, placeholders, incomplete tasks, missing steps |
    | Spec Alignment | Plan covers spec requirements, no major scope creep |
    | Task Decomposition | Tasks have clear boundaries, steps are actionable |
    | Buildability | Could an engineer follow this plan without getting stuck? |

    Flag only issues that would cause real problems during implementation.
    Minor wording and stylistic preferences are not findings.
```

**Placeholders:**
- `[PLAN_FILE_PATH]` — the plan document path
- `[SPEC_FILE_PATH]` — the spec the plan was written from

**plan-reviewer returns:** severity-classified findings that must be fixed or rebutted before handoff.
