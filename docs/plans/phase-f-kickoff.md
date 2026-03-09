# Phase F Kickoff

Date: 2026-03-08

Purpose: start Phase F execution tracking on the post-I7 baseline without changing frozen defaults.

## Current Baseline Summary

- Active execution state is Phase F on the post-I7 baseline (`I0`-`I7` complete).
- I7 closure evidence is canonical in:
  `docs/plans/i7-regression-evidence.md`,
  `docs/plans/i7-api-contract-trace-checklist.md`, and
  `docs/plans/i7-phase-f-kickoff-handoff.md`.
- Carry-forward accepted risks remain: `UT-E-001`, `UT-E-002`, `UT-E-003`, `UT-E-004`, `A-D-001`.
- Default-policy posture is unchanged (`D-001`..`D-004` and accepted strictness defaults remain frozen).
- Phase F first concrete burn-down pass is executed and recorded in
  `docs/plans/phase-f-risk-burndown.md`.
- Phase F Step 2 replay-input artifact is now recorded in
  `docs/plans/phase-f-replay-inputs.md` (`UT-E-003-FX-001`..`UT-E-003-FX-005`).
- Phase F Step 1 external cross-language replay is now executed via
  `/workspace/projects/noztr/.phasef-go/main.go` using `github.com/nbd-wtf/go-nostr/nip44`.
- Phase F Step 6 persistent cross-language replay harnesses are now maintained under
  `tools/interop/` with shared fixture input
  `tools/interop/fixtures/nip44_ut_e_003.json` and reusable harnesses for Go/Rust/TypeScript.
- Phase F Step 6 replay classification outcomes are now recorded as
  Go `pass`, Rust `pass`, TypeScript `pass` in
  `docs/plans/phase-f-risk-burndown.md`.
- Phase F Step 7 rust-nostr parity-all matrix pass is recorded in
  `docs/plans/phase-f-risk-burndown.md` and
  `docs/plans/phase-f-rust-nostr-parity.md`.
- Phase F Step 8 ts-nostr parity-all matrix pass is recorded in
  `docs/plans/phase-f-risk-burndown.md` and
  `docs/plans/phase-f-ts-nostr-tools-parity.md`.
- Phase F Step 9 rust-nostr parity-all depth notch (malformed/edge expansion with same
  coverage set) is recorded in `docs/plans/phase-f-risk-burndown.md` and
  `docs/plans/phase-f-rust-nostr-parity.md`.
- Phase F Step 3 `UT-E-004` replay expansion is recorded in
  `docs/plans/phase-f-risk-burndown.md` with expanded mutation classes and `no-drift`
  typed-class mapping stability.
- Phase F Step 4 `UT-E-004` next-step 2 expansion is recorded in
  `docs/plans/phase-f-risk-burndown.md` with additional hex-input seam classes
  (wrong-length message/signature and non-hex message/signature/pubkey) and
  `pass` outcome classification.
- Aggregate dual-run gates were executed after each cadence increment:
  TS parity-all step (`8`) and rust depth-notch step (`9`); latest aggregate result remains
  `454/456` passed, `2` skipped.

## UT-E-003 and UT-E-004 Burn-Down Worklist

`UT-E-003` NIP-44 differential replay depth beyond pinned corpus
- Immediate task 1: define the Phase F replay matrix (pinned vectors plus differential references).
- Immediate task 2: define explicit replay input fixtures with stable IDs and replay fields.
- Immediate task 3: classify any mismatch as `vector-gap`, `behavior-drift`, or `harness-issue`.

`UT-E-004` secp256k1/BIP340 differential hardening depth beyond I1 baseline
- Immediate task 1: define added boundary corpus targets beyond I1 acceptance criteria.
- Immediate task 2: execute first differential boundary pass against pinned references.
- Immediate task 3: map any divergence to typed boundary behavior and required follow-up vectors.

Burn-down guardrail: execute these tasks as depth expansion only; do not change strict defaults.

## First Pass Status

- First replay/boundary pass status: executed.
- First replay delta run status: executed with build-wired NIP-44 and secp parity commands.
- Step 1 external cross-language replay status: executed (`UT-E-003-FX-001`..`UT-E-003-FX-005`
  passed in go-nostr harness).
- Step 2 replay-input set status: executed (`UT-E-003` input set defined and linked).
- Step 3 `UT-E-004` replay expansion status: executed (expanded secp mutation matrix plus
  wrong-length seam classification).
- Step 4 `UT-E-004` next-step 2 status: executed (expanded hex-input seam matrix and typed
  class parity assertions for wrong-length/non-hex classes).
- Step 6 persistent cross-language replay status: executed
  (`UT-E-003-FX-001`..`UT-E-003-FX-005` passed in persistent Go/Rust/TypeScript harnesses).
- Step 7 rust-nostr parity-all status: executed (all supported overlap checks passed; implemented
  unsupported NIPs explicitly reported as `UNSUPPORTED`).
- Step 8 ts-nostr parity-all status: executed (all supported overlap checks passed; implemented
  unsupported NIPs explicitly reported as `UNSUPPORTED`).
- Step 9 rust-nostr parity-all depth-notch status: executed (supported overlap checks passed with
  added malformed/edge negatives for `NIP-19/21/42/44/65`; implemented unsupported NIPs unchanged).
- Canonical evidence artifact: `docs/plans/phase-f-risk-burndown.md`.
- Canonical parity matrix artifact: `docs/plans/phase-f-rust-nostr-parity.md`.
- Canonical parity matrix artifact (TypeScript lane):
  `docs/plans/phase-f-ts-nostr-tools-parity.md`.
- Canonical replay input artifact: `docs/plans/phase-f-replay-inputs.md`.
- Defaults/frozen policy status: unchanged.
- Step 5 governance status: no `UT-E-001`/`A-D-001` trigger criteria fired, so no
  policy/default changes were considered.
- Rule remains: any future trigger firing requires a decision-log entry before any default changes.

## Optional Corpus Review Triggers (`UT-E-001` / `A-D-001`)

Keep optional-module baseline at `3 valid + 3 invalid` unless one or more triggers occur:

- parity-corpus drift is observed in optional-module behavior.
- optional-module non-interference tests fail in aggregate runs.
- repeated escaped defects are traced to optional-module corpus depth.
- cross-implementation replay evidence shows optional-module mismatch.

Trigger action: raise vector depth only for affected optional modules and record rationale in
`docs/plans/build-plan.md` and `docs/plans/decision-log.md`.

## Dual-Run Gate Reminder

- Keep aggregate test reruns in dual-run mode with `enable_i6_extensions=true` and
  `enable_i6_extensions=false`.
- Required gate posture for Phase F tracking remains:
  `zig build test --summary all` and `zig build` with dual-run coverage preserved.
