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

### DOC-LOOP-001

- Status: open
- Tracking: `no-3jy`
- Problem:
  requested-NIP state still exists in multiple active places:
  - `docs/plans/build-plan.md`
  - `docs/plans/post-kernel-requested-nips-loop.md`
  - `handoff.md`
- Why it hurts:
  the next-item and completion-state story can drift if all three are edited narratively.
- Recommendation:
  keep:
  - `docs/plans/post-kernel-requested-nips-loop.md` for order and loop rules
  - `handoff.md` for only the current next item
  reduce `docs/plans/build-plan.md` to one concise progress pointer instead of repeating the full
  closure sequence.

### DOC-PLAN-001

- Status: open
- Tracking: `no-l38`
- Problem:
  `docs/plans/build-plan.md` mixes active baseline, historical execution notes, and multiple
  generations of planning context.
- Why it hurts:
  it is still authoritative, but its signal-to-noise ratio is lower than it should be for an
  active control doc.
- Recommendation:
  split future historical narrative into archive or audit/reference docs and keep the build plan
  baseline-oriented.

### DOC-DECISION-001

- Status: accepted-risk
- Problem:
  `docs/plans/decision-log.md` is very large.
- Why it is not the first cut:
  unlike `handoff.md`, the decision log is a legitimate reference surface and is allowed to be
  long if it remains the canonical home for accepted defaults.
- Recommendation:
  preserve it as reference, but avoid using it as a packet or handoff substitute.

## Adoption Notes

This pass takes the minimal adoption path:

1. define doc roles
2. add one docs index
3. add one repo-specific process-control guide
4. keep a stable-ID audit for docs/process findings
5. shorten handoff to current state

That is enough to reduce startup load immediately without a risky full doc reorg.
