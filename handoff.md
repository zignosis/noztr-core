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
  - .private-docs/README.md
  - .private-docs/plans/build-plan.md
  - .private-docs/plans/decision-index.md
  - .private-docs/plans/phase-h-remaining-work.md
  - .private-docs/plans/phase-h-rc-api-freeze.md
canonical: true
---

# Handoff

Current execution state for `noztr`.

## Read First

- `AGENTS.md`
- `.private-docs/README.md`
- `.private-docs/plans/build-plan.md`
- `.private-docs/plans/decision-index.md`
- `.private-docs/plans/phase-h-remaining-work.md`
- `.private-docs/plans/phase-h-rc-api-freeze.md`

## Current Status

- Active execution state remains Phase H.
- Current active packet is `.private-docs/plans/phase-h-remaining-work.md`.
- The exhaustive audit, supplements, remediation, freeze recheck, and local RC review are complete.
- The second requested-NIP loop is complete:
  - landed:
    - `NIP-31`
    - bounded `NIP-34`
    - `NIP-52`
    - bounded `NIP-53`
    - `NIP-54`
    - narrow schema-agnostic `NIP-78`
  - kept out of kernel scope:
    - `NIP-55`
- `no-6e6p` remains open and is again the active remaining review lane pending downstream `nzdk`
  feedback.
- Public tracked docs now live in `docs/release/` plus `examples/`; internal planning, audit, and
  process docs live in local-only `.private-docs/`.
- Public contributor style guides now exist in `docs/release/` for external contributors.
- Ownership call now frozen:
  - `NIP-55` stays out of `noztr`; it is Android app IPC, not protocol-kernel work
  - `NIP-78` is accepted only as a minimal schema-agnostic addressable helper
- Remote readiness remains deferred-by-operator, and no git remote is configured in this repo.
- Only expected untracked local artifact:
  - `tools/interop/rust-nostr-parity-all/target/`

## Active Control Docs

- `AGENTS.md`
- `.private-docs/README.md`
- `.private-docs/plans/build-plan.md`
- `.private-docs/plans/decision-index.md`
- `.private-docs/plans/phase-h-remaining-work.md`
- `.private-docs/plans/phase-h-rc-api-freeze.md`
- `.private-docs/guides/IMPLEMENTATION_QUALITY_GATE.md`

## Critical Rules

- use `.private-docs/guides/IMPLEMENTATION_QUALITY_GATE.md` for any new implementation, audit, or
  robustness slice
- keep completed packets reference-only and keep new pending work in the current active packet
- keep `handoff.md` state-oriented
- keep `br` mutations, `br sync`, and git-writing steps serial-only

## Next Work

- execute `.private-docs/plans/phase-h-rc-api-freeze.md`
- keep `.private-docs/plans/phase-h-remaining-work.md` as the steady-state Phase H packet
- close `no-6e6p` only after downstream `nzdk` feedback is reviewed against the current expanded
  surface
- use `.private-docs/plans/noztr-sdk-ownership-matrix.md` whenever a requested surface pressures
  kernel-vs-SDK scope

## Notes

- completed packets, reports, and supplement history belong in reference docs, archive, or git
  history, not in this handoff
