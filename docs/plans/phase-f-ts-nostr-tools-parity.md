# Phase F ts-nostr-tools Parity Pass

Date: 2026-03-08

Purpose: record one-pass `nostr-tools` overlap validation for all currently implemented `noztr` NIPs.

## Decisions

- `PF-TNP-001`: add persistent harness `tools/interop/ts-nostr-parity-all` for reusable overlap
  checks across implemented and future NIPs.
- `PF-TNP-002`: adopt parity model v1 taxonomy/depth output in the TypeScript parity-all harness.
- `PF-TNP-003`: use canonical matrix/ledger artifacts for parity status;
  this document is lane-local execution evidence only.

## Canonical References

- Canonical side-by-side parity matrix: `docs/plans/phase-f-parity-matrix.md`.
- Canonical parity ledger and deltas: `docs/plans/phase-f-parity-ledger.md`.

## TypeScript Lane Evidence

- Command: `npm run run` (in `tools/interop/ts-nostr-parity-all`).
- Output contract: `NIP-XX | taxonomy=<...> | depth=<...> | result=<...>` with summary counters.
- Current lane result: `pass` (`HARNESS_COVERED` checks all `PASS`; remaining implemented NIPs are
  `NOT_COVERED_IN_THIS_PASS`).

Harness summary output:

- `SUMMARY pass=6 fail=0 harness_covered=6 lib_supported=0 not_covered_in_this_pass=10 lib_unsupported=0 total=16`

Pass classification: `pass`.

Policy note: defaults unchanged; no frozen-default or strictness-policy change is introduced by this pass.

## Tradeoffs

## Tradeoff T-F-TNP-001: Single reusable TypeScript parity harness versus one-off checks

- Context: this pass requires immediate evidence and reusable scaffolding for future NIP overlap checks.
- Options:
  - O1: write one persistent multi-NIP TypeScript harness.
  - O2: run ad-hoc one-off commands without a shared harness.
- Decision: O1.
- Benefits: repeatable parity evidence and lower future setup cost.
- Costs: one additional tool artifact to maintain.
- Risks: harness drift from intended matrix coverage.
- Mitigations: keep explicit per-NIP output and matrix-linked command references.
- Reversal Trigger: future parity checks are better served by a different canonical harness layout.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: Phase F `nostr-tools` overlap evidence and future NIP additions.

## Open Questions

- None for this pass.

## Principles Compliance

- `P01`: trust-boundary overlap checks are explicit and test-backed in the harness.
- `P03`: parity evidence is behavior-focused (runtime checks), not API-shape focused.
- `P05`: deterministic outputs are recorded with per-NIP status lines and one summary line.
- `P06`: harness exits non-zero on supported overlap failures and remains reusable for bounded runs.
