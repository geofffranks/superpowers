---
name: artifact-retention-policy
description: Use when deciding whether plans, reports, review notes, validation records, or other workflow output should be committed, attached to a tracker, kept temporarily, or discarded
---

# Artifact Retention Policy

Use this policy whenever a workflow considers creating a plan, report, review note, checklist, or validation record. Preserve durable truth without turning execution traces into product files.

## Four retention classes

1. **Durable product or operational truth — commit.** Keep current architecture contracts, user/operator runbooks, privacy and security requirements, versioned data definitions, provenance needed to interpret shipped data, and compatibility or qualification records with a defined ongoing purpose.
2. **Planning or issue state — one authoritative tracker.** Keep roadmap and issue state in the project, ticket, or PR system that owns it. Do not copy the same inventory into a repository plan and separate validation files.
3. **Active implementation material — temporary.** Plans, task briefs, review notes, subagent summaries, and temporary checklists belong in session storage. Attach them to an active ticket or PR only when durable multi-session coordination requires it. At close, move lasting facts into source, tests, product docs, or the ticket summary, then delete or archive the working material.
4. **Ephemeral execution evidence — do not commit.** Raw command output, test-passed reports, implementer reports, validator transcripts, dated test counts, before/after JSON, review checkboxes, and recursive report hashes belong in CI or session logs.

## Before creating a persistent evidence file

Answer all five questions:

- Who consumes it after this implementation closes?
- What durable claim does it establish?
- Why are source, tests, CI, or ticket history insufficient?
- What is its validity scope?
- What event updates or retires it?

If any answer is not concrete, do not create the file. A persistent record is justified for operator qualification, compliance, migration attestation, or physical-hardware compatibility when its consumer, scope, and retirement/update event are explicit. Ordinary implementation evidence is not.

## Scope beats ceremony

An explicit request for a small docs, planning, or metadata cleanup controls generic workflow defaults. Do not reintroduce an RFC, ticket, design spec, duplicate plan, validator report, permanent evidence file, worktree, or formal review loop unless the request or risk classification requires it.

Product tests must not require workflow-document headings, review checkboxes, validator reports, dated plan paths, or historical validation files. Test durable documentation only when that documentation is itself a shipped interface, policy, runbook, schema, or privacy contract. Process compliance belongs in workflow state, CI metadata, or ticket state—not application tests.

### Examples

- **Lightweight:** edit a Markdown heading or project metadata, read it back, check links and formatting once, and report the result. Keep command output in the session log; create no validation document.
- **High-risk qualification:** qualify software against physical hardware. Commit the current compatibility record only if operators rely on it, state the tested hardware/firmware and validity scope, record the update/retirement trigger, and retain raw runs in CI or the qualification system.
