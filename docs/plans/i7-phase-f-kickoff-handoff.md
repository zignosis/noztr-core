# I7 Phase-F Kickoff Handoff

Date: 2026-03-08

Purpose: record implementation-readiness at I7 closure and define immediate Phase F kickoff actions.

## Readiness Checklist

- [x] I0-I7 execution waves complete on current scope baseline.
- [x] Aggregate gates pass: `zig build test --summary all` and `zig build`.
- [x] Transcript replay checks pass (`src/nip01_message.zig` transcript suite).
- [x] Crypto check-order replay checks pass (`src/nip44.zig` staged decrypt order suite).
- [x] Contract trace checklist completed:
  `docs/plans/i7-api-contract-trace-checklist.md`.
- [x] I7 regression evidence captured:
  `docs/plans/i7-regression-evidence.md`.
- [x] Contract wording synced to current deltas: NIP-44 padded-length `u32` semantics,
  parser `OutOfMemory` variants where implemented, strict `kind <= 65535` policy,
  transcript canonical-vs-compat wording, NIP-77 CLOSE/ERR parse APIs,
  NIP-50 unsupported multi-colon token handling, and NIP-09 duplicate-`d` coordinate policy.

## Carry-Forward Accepted Risks

- `UT-E-001` optional-module vector depth beyond `3 valid + 3 invalid` baseline (medium).
- `UT-E-002` compatibility API physical placement (`co-located` vs `compat/`) (low).
- `UT-E-003` NIP-44 differential replay depth in CI beyond pinned corpus (medium).
- `UT-E-004` secp256k1/BIP340 differential hardening depth beyond I1 baseline (medium).
- `A-D-001` optional module vector depth beyond current minimum (medium).

Carry-forward policy: keep defaults unchanged at kickoff; escalate only on parity drift evidence,
integration failures, or repeated escaped defects.

## First Phase-F Actions

1. Freeze I7 closure packet in active status docs (`build-plan`, `implementation-kickoff`,
   `handoff`, `decision-log`) and reference all three I7 artifacts.
2. Open Phase F execution with targeted risk burn-down tasks for `UT-E-003` and `UT-E-004`
   (differential replay depth and boundary corpus depth), without changing strict defaults.
3. Run first Phase F optional-lane corpus review for `UT-E-001`/`A-D-001`; keep baseline unless
   objective drift indicators trigger escalation.
4. Keep Layer 2 compatibility placement (`UT-E-002`) in accepted-risk state until
   `OQ-E-006` closure evidence is finalized.
5. Preserve dual-run gate posture (`enable_i6_extensions=true/false`) for all aggregate test reruns.
