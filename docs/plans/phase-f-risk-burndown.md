# Phase F Risk Burndown

Date: 2026-03-09

Purpose: track active burn-down for `UT-E-003` and `UT-E-004` from the rust-deep parity baseline.

## Baseline Snapshot

`UT-E-003`
- Topic: NIP-44 differential replay depth in CI beyond pinned corpus.
- Impact: medium.
- Status: accepted-risk.
- Default: pinned vectors required; expand replay depth on parity or integration signals.
- Owner: Phase F owner.

`UT-E-004`
- Topic: secp256k1/BIP340 differential hardening depth beyond I1 baseline.
- Impact: medium.
- Status: accepted-risk.
- Default: keep I1 boundary acceptance criteria mandatory; expand corpus depth on drift signals.
- Owner: Phase I owner.

## Current Status (Normalized)

- Active parity gate lane is rust-only: `tools/interop/rust-nostr-parity-all`.
- Active parity result is stable: `16/16 HARNESS_COVERED`, `DEEP`, `PASS`.
- Cross-language NIP-44 replay harnesses exist and remain usable evidence for depth expansion:
  - `tools/interop/go-nostr-nip44`
  - `tools/interop/rust-nostr-nip44`
  - `tools/interop/ts-nostr-tools-nip44`
- `UT-E-004` typed-class replay expansion remains `pass` with `no-drift` classifier mapping.
- `UT-E-004` depth increment added overlength pubkey wrong-shape case (`64+2` hex) and passed as
  `invalid_public_key` with boundary/direct parity.
- `UT-E-004` depth increment added overlength message (`64+2`) and signature (`128+2`) wrong-shape
  cases and passed as `invalid_signature` with boundary/direct parity.
- `UT-E-004` odd-length wrong-shape class added (`63` pubkey/message, `127` signature) and passing
  with boundary/direct parity (`no-drift`).
- `UT-E-004` multi-invalid odd-length precedence case (`63` pubkey + `63` message + `127` signature)
  added and passing with boundary/direct parity and deterministic `invalid_public_key` precedence.
- `UT-E-004` multi-invalid full-length non-hex precedence case (`64` pubkey + `64` message +
  `128` signature) added and passing with boundary/direct parity and deterministic
  `invalid_public_key` precedence (`no-drift`).
- `UT-E-004` mixed-stage precedence case (non-hex `64` pubkey + odd-length `63` message + valid
  `128` signature) added and passing with boundary/direct parity and deterministic
  `invalid_signature` precedence (`no-drift`).
- `UT-E-004` mixed-stage signature-length precedence case (non-hex `64` pubkey + valid `64`
  message + odd-length `127` signature) added and passing with deterministic
  `invalid_signature` boundary/direct parity (`no-drift`).
- `UT-E-003` malformed-boundary increment executed: deterministic `AQ==` reject case added and enforced
  in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: second deterministic `AA==` reject case executed
  and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: version-looking single-byte `Ag==` reject case
  executed and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: unsupported-version `Aw==` reject case executed
  and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: empty-payload reject case (`UT-E-003-MAL-005`)
  executed and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: truncated-version reject case
  (`UT-E-003-MAL-006`, payload `AgA=`) executed and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: short-truncated reject case
  (`UT-E-003-MAL-007`, payload `AgAA`) executed and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: length-4 truncated-body reject case
  (`UT-E-003-MAL-008`, payload `AgAAAA==`) executed and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: length-5 truncated-body reject case
  (`UT-E-003-MAL-009`, payload `AgAAAAA=`) executed and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: length-6 truncated-body reject case
  (`UT-E-003-MAL-010`, payload `AgAAAAAA`) executed and passing in active rust parity-all harness.
- `UT-E-003` malformed-boundary increment expanded: length-7 truncated-body reject case
  (`UT-E-003-MAL-011`, payload `AgAAAAAAAA==`) executed and passing in active rust parity-all harness.
- Frozen defaults and strictness policy remain unchanged.

## Active Gate Commands

| Scope | Command | Latest result |
| --- | --- | --- |
| Rust parity gate | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`SUMMARY pass=16 fail=0 total=16`) |
| Aggregate quality gates | `zig build test --summary all && zig build` | pass (`460/460 tests passed`; `zig build` passed) |
| NIP-59 comparative focus | `zig build test --summary all -- --test-filter "nip59"` | pass |

## Stability window (3 consecutive runs)

- Controlled-state sequence executed three consecutive times:
  `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` ->
  `zig build test --summary all` -> `zig build`.
- Run #1 outcome: rust parity `SUMMARY pass=16 fail=0 total=16`; zig tests `460/460` pass;
  `zig build` pass.
- Run #2 outcome: rust parity `SUMMARY pass=16 fail=0 total=16`; zig tests `460/460` pass;
  `zig build` pass.
- Run #3 outcome: rust parity `SUMMARY pass=16 fail=0 total=16`; zig tests `460/460` pass;
  `zig build` pass.
- Drift check result: no drift observed across all three consecutive runs.

## No-new-findings closure check

- Latest incremental candidates were the added malformed/truncated NIP-44 payload representatives
  (`UT-E-003-MAL-001`..`UT-E-003-MAL-011`) and secp classifier-precedence additions under `UT-E-004`.
- Closure rationale: latest candidates produced stable deterministic outcomes with no new classifier
  family, no parity mismatch, and no boundary/direct mapping drift.
- Result: no new findings opened from latest increment set in this pass.
- Incremental expansion status: frozen pending discovery of a new behavior class.

## Historical Evidence (Archived)

- Historical TS parity-all execution records are preserved for audit traceability only and are not
  part of active cadence.
- Historical step-level records that established this baseline remain in project history and related
  artifacts:
  - `docs/plans/phase-f-parity-matrix.md`
  - `docs/plans/phase-f-parity-ledger.md`
  - `docs/plans/phase-f-ts-nostr-tools-parity.md`

## Burn-Down Focus

`UT-E-003`
- Expand replay depth around malformed payload boundaries and deterministic replay invariants.
- Keep mismatch classification strict: `vector-gap`, `behavior-drift`, `harness-issue`.

`UT-E-004`
- Expand secp boundary corpus with additional wrong-shape and malformed-input classes.
- Preserve classifier parity checks between boundary mapping and direct mapping.

Guardrail:
- Burn-down work is depth expansion only; no strict-default or frozen-policy changes without
  decision-log entry.

## Next Actions

1. Continue `UT-E-003` replay-depth additions and append concise outcomes here.
2. Continue `UT-E-004` boundary-depth additions and append typed mapping outcomes here.
3. Re-run rust parity + aggregate zig gates after each material depth increment.
4. Keep TS references archive-only and avoid active-cadence wording.

## Transition Note (Phase G kickoff)

- After `no-dr3` hard-gate closure, this artifact is retained as historical Phase F evidence.
- Burn-down expansion is frozen at current baseline and remains frozen pending new behavior-class
  discovery.
