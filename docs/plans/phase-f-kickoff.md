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

## UT-E-003 and UT-E-004 Burn-Down Worklist

`UT-E-003` NIP-44 differential replay depth beyond pinned corpus
- Immediate task 1: define the Phase F replay matrix (pinned vectors plus differential references).
- Immediate task 2: run and record first replay pass results in execution evidence notes.
- Immediate task 3: classify any mismatch as `vector-gap`, `behavior-drift`, or `harness-issue`.

`UT-E-004` secp256k1/BIP340 differential hardening depth beyond I1 baseline
- Immediate task 1: define added boundary corpus targets beyond I1 acceptance criteria.
- Immediate task 2: execute first differential boundary pass against pinned references.
- Immediate task 3: map any divergence to typed boundary behavior and required follow-up vectors.

Burn-down guardrail: execute these tasks as depth expansion only; do not change strict defaults.

## First Pass Status

- First replay/boundary pass status: executed.
- First replay delta run status: executed with build-wired NIP-44 and secp parity commands.
- Canonical evidence artifact: `docs/plans/phase-f-risk-burndown.md`.
- Defaults/frozen policy status: unchanged.

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
