---
title: Handoff
doc_type: state
status: active
owner: noztr
phase: phase-h
read_when:
  - starting_session
  - resuming_incomplete_work
  - checking_next_step
depends_on:
  - docs/README.md
  - docs/plans/build-plan.md
  - docs/plans/decision-index.md
canonical: true
---

# Handoff

Current execution state for `noztr`.

## Read First

- `AGENTS.md`
- `docs/README.md`
- `docs/plans/build-plan.md`
- `docs/plans/decision-index.md`
- `docs/plans/post-kernel-requested-nips-loop.md` only when tracing the completed requested-NIP lane

## Current Status

- Active execution state remains Phase H on the post-Phase G local-only closure baseline.
- Remote readiness remains deferred-by-operator.
- No git remote is configured in this repo.
- The post-kernel requested-NIP loop is complete through split-surface `NIP-B7`.
- No active implementation slice is currently selected.
- Only expected untracked local artifact:
  - `tools/interop/rust-nostr-parity-all/target/`

## Control Docs

- `AGENTS.md`
  - agent operating rules and closure discipline
- `docs/README.md`
  - docs index and active/reference/archive routing
- `docs/guides/PROCESS_CONTROL.md`
  - repo-specific process refinement rules for keeping control docs lean
- `docs/plans/build-plan.md`
  - active execution baseline
- `docs/plans/decision-index.md`
  - startup route into accepted policy areas
- `docs/plans/decision-log.md`
  - on-demand canonical reference for accepted defaults and policy decisions
- `docs/plans/docs-surface-audit.md`
  - stable-ID audit of doc bloat, repetition, and control-surface drift
- `docs/plans/post-kernel-requested-nips-loop.md`
  - completed requested-NIP packet retained for order/rule traceability

## Active Quality Rules

- For every new or materially changed NIP surface:
  - freeze a spec-to-contract checklist before closure
  - freeze an explicit invalid-vs-capacity matrix before coding public builder/validator paths
  - run builder/parser symmetry tests where applicable
  - review the public error contract explicitly
  - include at least one hostile consumer-facing example for boundary-heavy surfaces
  - run an adversarial audit before closure
- When reference lanes are weak or `LIB_UNSUPPORTED`:
  - freeze a reject corpus before coding
  - include nonsense-token and separator-discipline challenges where relevant
- `br` mutations, `br sync`, and git-writing steps remain serial-only.

## Current Repo State

- Latest docs/control-surface refinement:
  - active build-plan is lean baseline only
  - implemented-surface review procedure is in `docs/plans/implemented-nip-review-guide.md`
  - historical build-plan narrative is in `docs/archive/plans/build-plan-history.md`
- Latest requested-NIP closure:
  - `NIP-B7` / `no-z9g` is closed locally
  - the full requested-NIP loop is now complete
- Only expected untracked local artifact:
  - `tools/interop/rust-nostr-parity-all/target/`

## Next Work

- Choose the next Phase H implementation or audit slice before starting new code work.
- Use `docs/plans/noztr-sdk-ownership-matrix.md` when the next candidate touches kernel-vs-SDK
  scope.
- Use the refined process controls in `docs/guides/PROCESS_CONTROL.md` when touching process/docs.

## Notes

- Historical execution detail belongs in git history, archived docs, or accepted decision entries,
  not in this handoff.
- If the process tightens again, re-audit recently closed requested NIPs before claiming the
  stronger gate is active.
