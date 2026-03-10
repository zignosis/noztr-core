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
| 22 | complete | `HARNESS_COVERED DEEP PASS` | `SOURCE_REVIEW_ONLY no dedicated NIP-22 helper beyond kind constant` | No Layer 1 change required; current root/parent, `K/k`, `P/p`, and kind-1 rejection posture remains justified | none | none | `rust-nostr` emits canonical full linkage when given a root target but still extracts parent-only / optional-kind shapes; `noztr` keeps the stricter trust-boundary contract |
| 25 | pending | - | - | - | - | - | - |
| 27 | pending | - | - | - | - | - | - |
| 40 | pending | - | - | - | - | - | - |
| 42 | complete | `HARNESS_COVERED DEEP PASS` | `HARNESS_COVERED EDGE PASS` | Widened NIP-42 challenge bound from `64` to `255`; retained path-bound websocket origin matching, duplicate-tag rejection, and unbracketed IPv6 rejection | none | none | `rust-nostr` and `nostr-tools` both accept long challenges; current remaining strictness is judged trust-boundary-positive rather than ecosystem-hostile |
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
- NIP-22: keep strict root/parent scope, mandatory `K/k`, mandatory `P/p` for Nostr targets, and
  kind-1 rejection; `rust-nostr` permissive extraction is treated as a compatibility signal, not a
  reason to weaken the Layer 1 parser.
- NIP-42: widen the challenge bound to `255` bytes, but keep path-bound websocket origin matching,
  duplicate required-tag rejection, and unbracketed IPv6 rejection as accepted trust-boundary
  behavior.

## Accepted Risks

- none yet

## Follow-up Summary

- NIP-10: no follow-up remains from `no-4iw`; the prior provisional divergence is resolved.
