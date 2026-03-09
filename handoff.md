# Handoff

Current project context for the Phase G kickoff baseline.

## Current Phase Status

- Planning phase records remain closed in `docs/plans/decision-log.md`.
- Active execution state is Phase G on post-`no-dr3` baseline.
- Frozen defaults and strictness posture remain unchanged.
- Canonical Phase F trackers:
  - `docs/plans/phase-f-kickoff.md`
  - `docs/plans/phase-f-parity-matrix.md`
  - `docs/plans/phase-f-parity-ledger.md`
  - `docs/plans/phase-f-risk-burndown.md`

## Phase G Kickoff

- Active execution state is Phase G kickoff baseline.
- `UT-E-003` and `UT-E-004` are maintenance-mode only; reopen only on new behavior-class discovery.
- Active blocker: `no-3uj` (git/Dolt remote + sync readiness).

## Active Parity Gate

- Active lane: rust only (`tools/interop/rust-nostr-parity-all`).
- Current rust status: `16/16 HARNESS_COVERED`, `DEEP`, `PASS`.
- Latest validation run (2026-03-09): rust parity harness `SUMMARY pass=16 fail=0 total=16`.
- Latest validation run (2026-03-09): `zig build test --summary all` passed (`460/460 tests`).
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
  including deterministic malformed boundary `AQ==`, `AA==`, `Ag==`, and `Aw==` plus empty-payload
  and truncated-version (`AgA=`) plus short-truncated (`AgAA`) reject coverage in active rust
  parity-all checks, plus length-4 truncated-body (`AgAAAA==`) and length-5 truncated-body
  (`AgAAAAA=`) reject coverage, plus length-6 truncated-body (`AgAAAAAA`) reject coverage,
  plus length-7 truncated-body (`AgAAAAAAAA==`) reject coverage.
- `UT-E-004`: active, with expanded typed boundary replay checks recorded as `pass`/`no-drift`,
  including overlength pubkey wrong-shape (`64+2` hex) classified `invalid_public_key` with
  boundary/direct parity, plus overlength message (`64+2`) and signature (`128+2`) wrong-shape
  cases classified `invalid_signature` with boundary/direct parity, and odd-length wrong-shape
  coverage (`63` pubkey/message, `127` signature) passing with the same no-drift parity mapping,
  plus multi-invalid odd-length precedence coverage (`63` pubkey + `63` message + `127` signature)
  passing with deterministic `invalid_public_key` precedence, plus multi-invalid full-length
  non-hex precedence coverage (`64` pubkey + `64` message + `128` signature) passing with the same
  deterministic `invalid_public_key` no-drift mapping, plus mixed-stage precedence coverage
  (non-hex `64` pubkey + odd-length `63` message + valid `128` signature) passing with
  deterministic `invalid_signature` no-drift mapping, plus mixed-stage signature-length precedence
  coverage (non-hex `64` pubkey + valid `64` message + odd-length `127` signature) passing with
  deterministic `invalid_signature` no-drift mapping.
- Trigger-governance status unchanged: no `UT-E-001`/`A-D-001` trigger criteria fired.

## Hard-Gate Snapshot (epic `no-dr3`)

- Scope freeze: representative sets are locked for `UT-E-003` and `UT-E-004`; no class expansion
  during this pass.
- Stability window: three consecutive controlled runs completed with no drift
  (rust parity `pass=16 fail=0`; zig tests `460/460`; `zig build` pass each run).
- No-new-findings closure: latest incremental candidates produced no new behavior-class findings.
- Governance closure: open high-priority check (`P0/P1`) is `0` before and after gate sequence.
- Policy continuity: rust-active lane maintained; TS remains archived historical evidence.

## Pending Actions

1. Keep TypeScript references archive-only in docs and prevent active-cadence wording regressions.
2. Re-run rust parity on dependency/version bumps and update parity matrix/ledger.
3. Continue `UT-E-003` replay-depth burn-down.
4. Continue `UT-E-004` secp-boundary burn-down.
5. Keep rust-active cadence with aggregate `zig` gates (`zig build test --summary all`, `zig build`)
   after each material depth increment.
