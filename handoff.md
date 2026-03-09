# Handoff

Current project context for the next Phase F execution slice.

## Current Phase Status

- Planning phase records remain closed in `docs/plans/decision-log.md`.
- Active execution state is Phase F on post-I7 baseline.
- Frozen defaults and strictness posture remain unchanged.
- Canonical Phase F trackers:
  - `docs/plans/phase-f-kickoff.md`
  - `docs/plans/phase-f-parity-matrix.md`
  - `docs/plans/phase-f-parity-ledger.md`
  - `docs/plans/phase-f-risk-burndown.md`

## Active Parity Gate

- Active lane: rust only (`tools/interop/rust-nostr-parity-all`).
- Current rust status: `16/16 HARNESS_COVERED`, `DEEP`, `PASS`.
- Latest validation run (2026-03-09): rust parity harness `SUMMARY pass=16 fail=0 total=16`.
- Latest validation run (2026-03-09): `zig build test --summary all` passed (`450/450 tests`).
- Latest validation run (2026-03-09): `zig build` passed.
- Active cadence commands:
  - `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml`
  - `zig build test --summary all && zig build`

## Archived Historical Evidence

- TypeScript parity lane (`tools/interop/ts-nostr-parity-all`) is archived historical evidence only.
- TS history remains preserved in:
  - `docs/plans/phase-f-parity-matrix.md`
  - `docs/plans/phase-f-parity-ledger.md`
  - `docs/plans/phase-f-risk-burndown.md`
  - `docs/plans/phase-f-ts-nostr-tools-parity.md`

## Burn-Down Status

- `UT-E-003`: active, with persistent NIP-44 replay harnesses and fixture evidence in place,
  including deterministic malformed boundary `AQ==`, `AA==`, `Ag==`, and `Aw==` reject coverage in
  active rust parity-all checks.
- `UT-E-004`: active, with expanded typed boundary replay checks recorded as `pass`/`no-drift`,
  including overlength pubkey wrong-shape (`64+2` hex) classified `invalid_public_key` with
  boundary/direct parity, plus overlength message (`64+2`) and signature (`128+2`) wrong-shape
  cases classified `invalid_signature` with boundary/direct parity, and odd-length wrong-shape
  coverage (`63` pubkey/message, `127` signature) passing with the same no-drift parity mapping,
  plus multi-invalid odd-length precedence coverage (`63` pubkey + `63` message + `127` signature)
  passing with deterministic `invalid_public_key` precedence, plus multi-invalid full-length
  non-hex precedence coverage (`64` pubkey + `64` message + `128` signature) passing with the same
  deterministic `invalid_public_key` no-drift mapping.
- Trigger-governance status unchanged: no `UT-E-001`/`A-D-001` trigger criteria fired.

## Pending Actions

1. Keep TypeScript references archive-only in docs and prevent active-cadence wording regressions.
2. Re-run rust parity on dependency/version bumps and update parity matrix/ledger.
3. Continue `UT-E-003` replay-depth burn-down.
4. Continue `UT-E-004` secp-boundary burn-down.
5. Keep rust-active cadence with aggregate `zig` gates (`zig build test --summary all`, `zig build`)
   after each material depth increment.
