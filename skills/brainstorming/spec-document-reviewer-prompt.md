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

**plan-reviewer returns:** severity-classified findings with stable finding IDs
such as `SPEC-001`. Every finding includes its severity, exact document location, the
violated requirement or review category, the required change, and status:
`open`, `fixed`, or `rebutted`.

## Review modes

The controller must declare one mode and provide the matching comparison data:

- **Initial review:** inspect the complete current spec and the repository context
  needed to validate its requirements, scope, architecture, and buildability.
- **Follow-up review:** use the previous/current version boundary to inspect only
  the changed sections since the previous review, the stable IDs of every
  unresolved prior finding, and directly affected dependencies/context.
  Do not perform another whole-document review unless the change materially alters the spec's overall
  scope, architecture, or requirements.

Every follow-up dispatch includes:

```text
Review mode: initial or follow-up
Previous reviewed version: [commit, timestamp, or content hash]
Current version: [commit, timestamp, or content hash]
Changed sections since previous review: [document sections]
Prior finding IDs being rechecked: [stable IDs]
```

## Review loop and exit condition

Run the initial review once. Batch all Critical and High findings before editing;
fix or rebut each finding, preserving its stable ID. Run a follow-up review only
when a Critical/High fix changed the spec's substance. A follow-up may add new
findings only when the changed sections or directly affected context reveal a
new real blocker. Stop when every blocking finding is `fixed` or `rebutted` and
the follow-up reports **no new blocking findings**. Medium, Low, and Nit findings
do not trigger a follow-up review.

**Ready to hand off** means every finding is fixed or rebutted and the final
follow-up, when required, reports no new blocking findings. A wording-only edit,
a Minor/Low/Nit fix, or an unchanged finding does not justify another full review.
