---
title: Docs Surface Audit History
doc_type: archive
status: archive
owner: noztr
archive_of: docs/plans/docs-surface-audit.md
---

# Docs Surface Audit History

Historical resolved findings from the docs-surface audit.

This archive keeps provenance for past control-surface fixes without forcing the active audit to
act like a running change log.

## Resolved Findings

### DOC-HANDOFF-001

- Status: fixed
- Problem:
  `handoff.md` had become a running execution history instead of a current-state control doc.
- Fix:
  slim `handoff.md` to state-only and move routing responsibility to `docs/README.md`.

### DOC-ROUTING-001

- Status: fixed
- Problem:
  the repo lacked one explicit docs index for active vs reference vs archive routing.
- Fix:
  add `docs/README.md` as the docs index and control-surface router.

### DOC-POLICY-001

- Status: fixed
- Problem:
  process-refinement rules were implied across active docs but not stated in one repo-specific
  control guide.
- Fix:
  add `docs/guides/PROCESS_CONTROL.md` and point the active surface at it.

### DOC-METADATA-001

- Status: fixed
- Problem:
  active control docs had mixed or missing frontmatter.
- Fix:
  define one shared frontmatter schema in `docs/guides/PROCESS_CONTROL.md` and apply it to the
  active control surface docs.

### DOC-LOOP-001

- Status: fixed
- Problem:
  requested-NIP state was duplicated across `build-plan`, the loop packet, and handoff.
- Fix:
  keep `handoff.md` as current next-item state, keep the loop packet for order and rules, and keep
  `build-plan.md` to a concise progress pointer.

### DOC-PLAN-001

- Status: fixed
- Problem:
  `docs/plans/build-plan.md` mixed active baseline, historical execution notes, and multiple
  generations of planning context.
- Fix:
  move long review procedure to reference and move historical execution detail to archive.

### DOC-DECISION-002

- Status: fixed
- Problem:
  the full decision log remained in the startup route even though it was reference-sized.
- Fix:
  add `docs/plans/decision-index.md` as the startup route and move the full decision log to
  on-demand reference status.

### DOC-CLOSEOUT-001

- Status: fixed
- Problem:
  closeout consistency was implied but not explicit.
- Fix:
  add an explicit closeout-consistency rule in `docs/guides/PROCESS_CONTROL.md`.

### DOC-SYNC-001

- Status: fixed
- Problem:
  packet closeout touchpoints were real but not declared early enough.
- Fix:
  add explicit synchronization-discipline rules and fold touchpoint declaration into active packets.

### DOC-PLAYBOOK-001

- Status: fixed
- Problem:
  the repo had no reusable `noztr`-specific playbook for sharing process lessons.
- Fix:
  add `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md` and route process-refinement tasks to it.

### DOC-PLAYBOOK-002

- Status: fixed
- Problem:
  the first playbook version did not yet capture ordered micro-loops, posture-design guidance, or
  process anti-patterns.
- Fix:
  extend the playbook with those transferable lessons and reflect only the canonical rule fragments
  in `PROCESS_CONTROL.md`.

## Historical Snapshot

Measured on 2026-03-15 before the first docs-refinement pass:

- `handoff.md`: 732 lines / 48,728 chars
- `docs/plans/build-plan.md`: 900 lines / 58,876 chars
- `docs/plans/decision-log.md`: 2,537 lines / 143,322 chars
- `AGENTS.md`: 283 lines / 11,936 chars

## Adoption Notes

The earlier refinement passes established:

1. one docs index
2. one repo-specific process-control guide
3. one shared frontmatter schema for active docs
4. one decision index so the full decision log is on-demand reference
5. one reusable process-refinement playbook
6. explicit closeout-consistency and synchronization rules
7. archive routing for historical execution and resolved audit material
