# Implemented NIP Audit Report

Date: 2026-03-10

Purpose: provide one canonical review artifact for the autonomous implemented-NIP audit so findings,
accepted risks, decision points, and follow-up items can be reviewed systematically after the audit
completes.

## Scope

- This report covers the implemented NIPs in `noztr`.
- It summarizes audit conclusions after the per-NIP evidence is gathered in beads issues.
- It does not replace raw evidence in beads or canonical policy decisions in
  `docs/plans/decision-log.md`.

## Evidence Sources

- relevant NIP text
- current `noztr` code and tests
- `rust-nostr` harness/source behavior
- `nostr-tools` harness/source behavior for every implemented NIP
- existing in-repo ecosystem notes and intentional-divergence records

## Review Standard

- Judge each NIP against the canonical review axes and lenses in
  `docs/plans/build-plan.md`.
- `rust-nostr` is the active parity lane and strongest production reference.
- `nostr-tools` is a secondary non-gating ecosystem signal.
- No reference library is treated as protocol authority.

## Audit Status

| NIP | Status | Rust Evidence | TS Evidence | Findings | Decision Points | Follow-ups | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | pending | - | - | - | - | - | - |
| 02 | pending | - | - | - | - | - | - |
| 09 | pending | - | - | - | - | - | - |
| 10 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Removed unnecessary rejection of legacy `mention`; removed unnecessary rejection of four-slot pubkey fallback | none | `no-4iw` closed | `noztr` now preserves four-slot author pubkey; `nostr-tools` accepts the shape but drops author |
| 11 | pending | - | - | - | - | - | - |
| 13 | pending | - | - | - | - | - | - |
| 18 | pending | - | - | - | - | - | - |
| 19 | pending | - | - | - | - | - | - |
| 21 | pending | - | - | - | - | - | - |
| 22 | pending | - | - | - | - | - | - |
| 25 | pending | - | - | - | - | - | - |
| 27 | pending | - | - | - | - | - | - |
| 40 | pending | - | - | - | - | - | - |
| 42 | pending | - | - | - | - | - | - |
| 44 | pending | - | - | - | - | - | - |
| 45 | pending | - | - | - | - | - | - |
| 50 | pending | - | - | - | - | - | - |
| 51 | pending | - | - | - | - | - | - |
| 59 | pending | - | - | - | - | - | - |
| 65 | pending | - | - | - | - | - | - |
| 70 | pending | - | - | - | - | - | - |
| 77 | pending | - | - | - | - | - | - |

## Decision Summary

- NIP-10: accept legacy `mention` tags as explicit mentions in thread extraction instead of failing
  the helper on that input.
- NIP-10: accept four-slot `e` tags with a valid slot-four pubkey as bounded compatibility input
  instead of rejecting the whole extract path.

## Accepted Risks

- none yet

## Follow-up Summary

- NIP-10: no follow-up remains from `no-4iw`; the prior provisional divergence is resolved.
