# Spec Document Reviewer Subagent Dispatch Template

Dispatch the `plan-reviewer` subagent to review the written spec for
completeness, internal consistency, scope, and ambiguity. The subagent
inspects the document and relevant code/context, and returns severity-classified
findings. Pass only the spec path and review criteria.

```
Subagent (plan-reviewer):
  prompt: |
    Review this spec document before it is handed off to plan-writing.

    **Spec to review:** [SPEC_FILE_PATH]

    ## What to Check

    | Category | What to Look For |
    |----------|------------------|
    | Placeholders | TBD, TODO, incomplete sections, vague requirements |
    | Internal consistency | Do sections contradict each other? Does architecture match feature descriptions? |
    | Scope | Focused enough for a single implementation plan, or needs decomposition? |
    | Ambiguity | Could any requirement be interpreted two ways? |

    Flag only issues that would cause real problems during planning or
    implementation. Minor wording and stylistic preferences are not findings.
```

**Placeholders:**
- `[SPEC_FILE_PATH]` — the spec document path

**plan-reviewer returns:** severity-classified findings.

**This is a single-pass spot check, not an iterative review loop.** Dispatch it
once over the current spec; do not re-dispatch it simply because you made
changes after it ran. Apply its findings by severity:

- **Critical / High:** fix, then re-review so the fix is verified.
- **Medium / Low / Nit:** fix (or rebut) and move on — re-reviewing is **not**
  required.

**Ready to hand off** means every finding is fixed or rebutted. It does **not**
mean a fresh reviewer pass ran after your changes — a follow-up review is only
needed when a Critical/High fix changed the spec's substance.
