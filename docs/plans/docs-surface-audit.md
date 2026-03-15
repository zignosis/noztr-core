---
title: Docs Surface Audit
doc_type: audit
status: active
owner: noztr
posture: docs-discoverability
read_when:
  - refining_process
  - reducing_doc_bloat_without_losing_rigor
  - updating_control_docs
depends_on:
  - docs/guides/PROCESS_CONTROL.md
canonical: true
---

# Docs Surface Audit

Audit posture: docs/discoverability and control-surface drift.

Question:
Can an agent or maintainer find the current rules and next work quickly without rereading repo
history?

## Current Status

- The startup path remains lean:
  - `AGENTS.md`
  - `handoff.md`
  - `docs/README.md`
  - `docs/plans/build-plan.md`
  - `docs/plans/decision-index.md`
- `PROCESS_CONTROL.md` is the canonical local process owner.
- `PROCESS_REFINEMENT_PLAYBOOK.md` is a reference doc for rationale and cross-repo sharing, not a
  second rule owner.
- Resolved findings history now lives in
  `docs/archive/plans/docs-surface-audit-history.md`.

## Live Findings

### DOC-DECISION-001

- Status: accepted-risk
- Problem:
  `docs/plans/decision-log.md` is very large.
- Why it is still acceptable:
  it is a legitimate cold-reference surface and no longer part of the default startup path.
- Watch condition:
  if other active docs start depending on decision-log rereads instead of the decision index, this
  becomes active bloat again.

## Operating Rule

When process changes materially, review the docs control surface coherently rather than adding
append-only refinements.

Minimum review set:
- `docs/guides/PROCESS_CONTROL.md`
- `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md`
- `docs/README.md`
- `handoff.md`
- `docs/plans/docs-surface-audit.md`

If a change resolves a finding:
- remove or rewrite superseded wording
- keep only live findings in this file
- move resolved-history material to archive if it still matters for provenance
