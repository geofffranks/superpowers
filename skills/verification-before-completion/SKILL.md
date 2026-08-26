---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT SUFFICIENT VERIFICATION EVIDENCE
```

Evidence must be collected after the final relevant mutation. “Fresh” means relevant to the current state, not a command repeated because the conversation entered a new phase. Verification already performed after the final mutation remains valid; do not rerun an equivalent check solely to restate the same claim.

## The Gate Function

```
BEFORE claiming completion:

1. IDENTIFY: What is the smallest check that proves this claim?
2. RUN or READ BACK: Perform it after the final relevant mutation.
3. READ: Check output, exit code, and scope.
4. VERIFY: Does the evidence confirm the claim?
   - If NO: State actual status with evidence.
   - If YES: State the claim with the evidence and stop.

One final integration verification is enough when it subsumes earlier checks.
```

For prose and metadata, use focused semantic read-back, reference/link checks, and formatting checks. Do not build a regression-test framework for one-time wording unless the text is a machine-consumed contract. CI logs, session logs, and PR checks are evidence; do not turn their output into a committed validation document by default.

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to commit/push/PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust agent report
```

## Why This Matters

From 24 failure memories:
- your human partner said "I don't believe you" - trust broken
- Undefined functions shipped - would crash
- Missing requirements shipped - incomplete features
- Time wasted on false completion → redirect → rework
- Violates: "Honesty is a core value. If you lie, you'll be replaced."

## When To Apply

Apply before claiming a completed, fixed, or passing result, committing, opening a PR, or closing a task. Match the check to the claim and scope; do not manufacture a new phase or a second equivalent run.

For any persistent validation/evidence file, first apply `superpowers:artifact-retention-policy`. Persistent evidence is required only when validation itself is a durable deliverable—such as operator qualification, compliance, migration attestation, or a physical-hardware compatibility record—with a defined consumer and validity scope.

## Anti-pattern

Bad:
```
edit Markdown → test exact heading → write validation plan → dispatch validator
→ write validator report → rerun same heading test
```

Good:
```
edit Markdown → read it back → check links and formatting → report result
```

Product tests must not require workflow-document headings, review checkboxes, validator reports, dated plan paths, or historical validation files. Tests may validate durable product documentation only when it is a shipped interface, policy, runbook, schema, or privacy contract. Process compliance belongs in workflow state, CI metadata, or ticket state.

## The Bottom Line

**No shortcuts for verification.**

Run the command. Read the output. THEN claim the result.

This is non-negotiable.
