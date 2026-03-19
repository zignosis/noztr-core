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

Current execution state for `noztr-core`.

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
- The third requested-NIP loop is complete:
  - landed:
    - `NIP-14`
    - bounded `NIP-28`
    - `NIP-30`
    - `NIP-38`
    - bounded `NIP-61`
    - `NIP-75`
    - expanded bounded `NIP-89`
- The fourth requested-NIP loop is complete:
  - landed:
    - bounded `NIP-71`
    - bounded `NIP-72`
- `NIP-66` is now implemented as a split relay-discovery slice only.
- `NIP-91` is now implemented as an additive extension of the existing `nip01_filter` family.
- The third-loop audit supplement and the targeted remediation packet are complete.
- `no-6e6p` remains open pending downstream `noztr-sdk` feedback.
- Public tracked docs now live in `docs/release/` plus `examples/`; internal planning, audit, and
  process docs live in local-only `.private-docs/`.
- `noztr` no longer carries a vendored `docs/nips` checkout; use the official upstream NIPs repo
  for spec texts, with any standalone local clone kept outside this repo.
- Public contributor style guides now exist in `docs/release/` for external contributors.
- frozen bounded ownership calls carried through the third loop:
  - `NIP-28` stops at deterministic channel metadata/linkage/moderation-contract helpers
  - `NIP-61` stops at deterministic nutzap informational/event/redemption-marker contracts and
    stays out of wallet/mint flow
- frozen bounded ownership calls carried through the fourth loop:
  - `NIP-71` stops at deterministic video metadata, `imeta` field, and tag-contract helpers
  - `NIP-72` stops at deterministic community definition, post-linkage, and approval-contract
    helpers
- frozen pending ownership call:
  - `NIP-91` extends the existing strict filter family only and stays out of relay
    signaling/fallback/workflow scope
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

- execute `.private-docs/plans/phase-h-remaining-work.md`
- current tracker lanes:
  - `no-6e6p`
  - `no-nrzk`
- keep `.private-docs/plans/phase-h-rc-api-freeze.md` open until downstream `noztr-sdk` feedback
  either confirms the current RC-facing surface or forces one explicit blocker packet
- if `NIP-91` implementation is selected next, start from `.private-docs/plans/nip91-and-filters-plan.md`
- use `.private-docs/plans/noztr-sdk-ownership-matrix.md` whenever downstream feedback pressures
  kernel-vs-SDK scope

## Notes

- completed packets, reports, and supplement history belong in reference docs, archive, or git
  history, not in this handoff
