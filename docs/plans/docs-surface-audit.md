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
---

# Docs Surface Audit

Audit posture: docs/discoverability and control-surface drift.

Question:
Can an agent or maintainer find the current rules and next work quickly without rereading repo
history?

## Current Snapshot

Measured on 2026-03-15 before the current refinement pass:

- active high-load docs:
  - `handoff.md`: 732 lines / 48,728 chars
  - `docs/plans/build-plan.md`: 900 lines / 58,876 chars
  - `docs/plans/decision-log.md`: 2,537 lines / 143,322 chars
  - `AGENTS.md`: 283 lines / 11,936 chars
- repeated requested-NIP closeout language was present in both `handoff.md` and
  `docs/plans/decision-log.md`
- `handoff.md` had accumulated repeated “is now complete” history entries across multiple phases
  and requested-NIP closures

## Findings

### DOC-HANDOFF-001

- Status: fixed in this pass
- Problem:
  `handoff.md` had become a running execution history instead of a current-state control doc.
- Why it hurt:
  startup reading cost was high, and the reader had to separate current state from historical
  narrative manually.
- Fix:
  slim `handoff.md` to state-only and move routing responsibility to `docs/README.md`.

### DOC-ROUTING-001

- Status: fixed in this pass
- Problem:
  the repo lacked one explicit docs index for active vs reference vs archive routing.
- Why it hurt:
  readers had to infer which docs were currently authoritative from scattered references.
- Fix:
  add `docs/README.md` as the docs index and control-surface router.

### DOC-POLICY-001

- Status: fixed in this pass
- Problem:
  process-refinement rules were implied across `AGENTS.md`, `handoff.md`, and execution docs but
  not stated in one repo-specific control guide.
- Why it hurt:
  the repo could recognize bloat but had no canonical rule set for preventing it from regrowing.
- Fix:
  add `docs/guides/PROCESS_CONTROL.md` and point the active surface at it.

### DOC-METADATA-001

- Status: fixed in this pass
- Problem:
  active control docs had mixed or missing frontmatter, so routing metadata was not standardized.
- Why it hurt:
  docs were harder to classify mechanically across repos and easier to route by custom habit than
  by explicit metadata.
- Fix:
  define one shared frontmatter schema in `docs/guides/PROCESS_CONTROL.md` and apply it to the
  active control surface docs.

### DOC-LOOP-001

- Status: fixed in this pass
- Problem:
  requested-NIP state still exists in multiple active places:
  - `docs/plans/build-plan.md`
  - `docs/plans/post-kernel-requested-nips-loop.md`
  - `handoff.md`
- Why it hurts:
  the next-item and completion-state story can drift if all three are edited narratively.
- Fix:
  keep:
  - `docs/plans/post-kernel-requested-nips-loop.md` for order and loop rules
  - `handoff.md` for only the current next item
  reduce `docs/plans/build-plan.md` to one concise progress pointer instead of repeating the full
  closure sequence.

### DOC-PLAN-001

- Status: fixed in this pass
- Problem:
  `docs/plans/build-plan.md` mixes active baseline, historical execution notes, and multiple
  generations of planning context.
- Why it hurts:
  it is still authoritative, but its signal-to-noise ratio is lower than it should be for an
  active control doc.
- Fix:
  move the long review procedure into `docs/plans/implemented-nip-review-guide.md`, move historical
  execution detail into `docs/archive/plans/build-plan-history.md`, and keep
  `docs/plans/build-plan.md` baseline-oriented.

### DOC-DECISION-001

- Status: accepted-risk
- Problem:
  `docs/plans/decision-log.md` is very large.
- Why it is not the first cut:
  unlike `handoff.md`, the decision log is a legitimate reference surface and is allowed to be
  long if it remains the canonical home for accepted defaults.
- Recommendation:
  preserve it as reference, but keep it off the default startup path and avoid using it as a
  packet or handoff substitute.

### DOC-DECISION-002

- Status: fixed in this pass
- Problem:
  the full `docs/plans/decision-log.md` remained in the startup route even though it is
  reference-sized.
- Why it hurt:
  active-memory reads were paying reference-cost on every session before any task had established
  that a full canonical decision payload was actually needed.
- Fix:
  add `docs/plans/decision-index.md` as the startup route into policy areas and move
  `docs/plans/decision-log.md` to on-demand reference status.

### DOC-CLOSEOUT-001

- Status: fixed in this pass
- Problem:
  closeout consistency was implied by good hygiene, but not stated as an explicit control rule.
- Why it hurt:
  slices could land technically correct code and still leave startup routing, examples catalogs, or
  handoff emphasis in a stale state, which recreates doc bloat and process drift quietly.
- Fix:
  add an explicit closeout-consistency rule in `docs/guides/PROCESS_CONTROL.md` that requires
  audit updates, discovery-surface updates, and steady-state routing restoration as part of done.

### DOC-SYNC-001

- Status: fixed in this pass
- Problem:
  packet closeout touchpoints were real but not declared early, so doc/audit/startup sync work
  could still be discovered late by memory or cleanup instinct.
- Why it hurt:
  this made it easier for a technically correct slice to land while leaving small routing or audit
  drift behind until a later pass noticed it.
- Fix:
  add explicit synchronization-discipline rules in `docs/guides/PROCESS_CONTROL.md` and fold the
  touchpoint declaration into the active requested-NIP execution packet.

### DOC-PLAYBOOK-001

- Status: fixed in this pass
- Problem:
  the repo had refined process rules, but no reusable `noztr`-specific playbook for sharing the
  lessons with other agents or sibling repos without replaying the full local history.
- Why it hurt:
  cross-repo learning depended too much on conversational memory and ad hoc references to specific
  recent slices.
- Fix:
  add `docs/guides/PROCESS_REFINEMENT_PLAYBOOK.md`, then route `AGENTS.md`, `handoff.md`, and
  `docs/README.md` to it when the task is process refinement or cross-repo process sharing.

## Adoption Notes

This pass takes the minimal adoption path:

1. define doc roles
2. add one docs index
3. add one repo-specific process-control guide
4. define one shared frontmatter schema for active docs
5. add one decision index so the full decision log becomes on-demand reference
6. make closeout-consistency explicit so finished slices restore steady-state routing
7. keep a stable-ID audit for docs/process findings
8. shorten handoff to current state
9. keep `build-plan.md` lean by moving long review procedure to reference and historical narrative
   to archive
10. declare refinement-packet sync touchpoints early enough that closeout work is visible before the
    slice finishes
11. keep one reusable process-refinement playbook so cross-repo learning does not depend on replaying
    recent session history

That is enough to reduce startup load immediately without a risky full doc reorg.
