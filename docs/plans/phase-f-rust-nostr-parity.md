# Phase F Rust-nostr Parity Pass

Date: 2026-03-08

Purpose: record one-pass rust-nostr overlap validation for all currently implemented `noztr` NIPs.

## Decisions

- `PF-RNP-001`: add persistent harness `tools/interop/rust-nostr-parity-all` for reusable
  overlap checks across implemented and future NIPs.
- `PF-RNP-002`: adopt parity model v1 taxonomy/depth output in the rust parity-all harness.
- `PF-RNP-003`: use canonical matrix/ledger artifacts for parity status;
  this document is lane-local execution evidence only.
- `PF-RNP-004`: expand depth (not breadth) for supported overlap checks with one malformed/edge
  notch in `NIP-19`, `NIP-21`, `NIP-42`, `NIP-44`, and `NIP-65`.

## Canonical References

- Canonical side-by-side parity matrix: `docs/plans/phase-f-parity-matrix.md`.
- Canonical parity ledger and deltas: `docs/plans/phase-f-parity-ledger.md`.

## Rust Lane Evidence

- Command: `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml`.
- Output contract: `NIP-XX | taxonomy=<...> | depth=<...> | result=<...>` with summary counters.
- Current lane result: `pass` (`HARNESS_COVERED` checks all `PASS`; remaining implemented NIPs are
  `NOT_COVERED_IN_THIS_PASS`).

Pass classification: `pass`.

Depth-notch classification (malformed/edge expansion, same coverage set): `pass`.

Policy note: no frozen-default or strictness-policy change is introduced by this pass.

## Tradeoffs

## Tradeoff T-F-RNP-001: Single reusable parity harness versus one-off command checks

- Context: this pass requires immediate evidence and reusable scaffolding for future NIPs.
- Options:
  - O1: write one persistent multi-NIP harness.
  - O2: run ad-hoc one-off commands without a shared harness.
- Decision: O1.
- Benefits: repeatable parity evidence and lower future setup cost.
- Costs: one additional tool artifact to maintain.
- Risks: harness drift from intended matrix coverage.
- Mitigations: keep explicit per-NIP output and matrix-linked command references.
- Reversal Trigger: future parity checks are better served by a different canonical harness layout.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: Phase F rust-nostr overlap evidence and future NIP additions.

## Open Questions

- None for this pass.

## Principles Compliance

- `P01`: trust-boundary overlap checks remain explicit and test-backed in the harness.
- `P03`: parity evidence is behavior-focused (runtime checks), not API-shape focused.
- `P05`: deterministic outputs are recorded with per-NIP status lines and one summary line.
- `P06`: harness exits non-zero on supported overlap failures and is reusable for bounded future runs.
