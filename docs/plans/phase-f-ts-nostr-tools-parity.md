# Phase F ts-nostr-tools Parity Pass

Date: 2026-03-08

Purpose: record one-pass `nostr-tools` overlap validation for all currently implemented `noztr` NIPs.

## Decisions

- `PF-TNP-001`: add persistent harness `tools/interop/ts-nostr-parity-all` for reusable overlap
  checks across implemented and future NIPs.
- `PF-TNP-002`: classify this pass as `pass` when all supported overlap checks return `PASS`.
- `PF-TNP-003`: report explicit `UNSUPPORTED` for implemented NIPs without sufficient
  `nostr-tools` overlap helpers in this pass (`NIP-02`, `NIP-09`, `NIP-11`, `NIP-40`, `NIP-45`,
  `NIP-50`, `NIP-59`, `NIP-65`, `NIP-70`, `NIP-77`).

## Parity Matrix

| NIP | `nostr-tools` support status | validation outcome | command/evidence reference | notes |
| --- | --- | --- | --- | --- |
| NIP-01 | supported overlap | PASS | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | finalize/verify baseline (`finalizeEvent`, `verifyEvent`, `getEventHash`) |
| NIP-02 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-09 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-11 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-13 | supported overlap | PASS | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | deterministic PoW helper sample (`getPow`) |
| NIP-19 | supported overlap | PASS | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | encode/decode roundtrip (`npub`, `note`) |
| NIP-21 | supported overlap | PASS | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | parse/roundtrip baseline (`nostr:` URI) |
| NIP-40 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-42 | supported overlap | PASS | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | `makeAuthEvent` baseline structure |
| NIP-44 | supported overlap | PASS | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | fixture replay (`tools/interop/fixtures/nip44_ut_e_003.json`) |
| NIP-45 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-50 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-59 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-65 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-70 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |
| NIP-77 | unsupported overlap | UNSUPPORTED | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | explicit unsupported report |

Harness summary output:

- `SUMMARY pass=6 fail=0 unsupported=10 total=16`

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
