# Phase F Risk Burndown

Date: 2026-03-08

Purpose: record the first concrete Phase F execution pass for `UT-E-003` and `UT-E-004`.

## Baseline Snapshot

`UT-E-003`
- Topic: NIP-44 differential replay depth in CI beyond pinned corpus.
- Impact: medium.
- Status at start: accepted-risk.
- Default at start: pinned official vectors are required; cross-language replay expands only on drift evidence.
- Owner: Phase F owner.

`UT-E-004`
- Topic: secp256k1/BIP340 differential hardening depth beyond I1 baseline.
- Impact: medium.
- Status at start: accepted-risk.
- Default at start: enforce I1 boundary acceptance criteria; expand differential corpus only on drift evidence.
- Owner: Phase I owner.

## Replay Matrix Template

| Risk ID | What to replay | Command/evidence source | Expected behavior | Classification |
| --- | --- | --- | --- | --- |
| `UT-E-003` | NIP-44 staged decrypt order and pinned vectors | `zig test src/nip44.zig --test-filter "staged check order"`; build-wired replay `zig build test --summary all -- --test-filter "nip44 valid vectors derive conversation keys"`; aggregate `zig build test --summary all` | deterministic pass; no decrypt-order inversion | `pass`, `vector-gap`, `behavior-drift`, `harness-issue` |
| `UT-E-004` | secp boundary sign/verify hardening corpus through project wiring | build-wired replay `zig build test --summary all -- --test-filter "bip340 vectors classify with boundary-direct parity"`; aggregate `zig build test --summary all` | deterministic pass on boundary corpus; typed mapping unchanged | `pass`, `vector-gap`, `behavior-drift`, `harness-issue` |

## First Pass Command Evidence and Outcomes

Environment snapshot:
- Timestamp (UTC): `2026-03-08T20:38:39Z`
- Commit: `73f5472`
- Zig: `0.15.2`

| Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- |
| `zig build test --summary all` | pass (`8/8` steps, `448/450` tests passed, `2` skipped) | `pass` for `UT-E-003`/`UT-E-004` baseline replay posture | aggregate suite remains green; no first-pass drift signal |
| `zig build` | pass | `pass` | static library build remains healthy on first pass |
| `zig test src/nip44.zig --test-filter "staged check order"` | pass (`2/2`) | `pass` for `UT-E-003` focused replay | staged order remains `version -> MAC -> padding` |
| `zig test src/crypto/secp256k1_backend.zig --test-filter "hardened"` | fail (no module named `secp256k1` in direct test context) | `harness-issue` for `UT-E-004` focused replay | direct module test bypasses build wiring; use build-wired boundary replay in next pass |

First-pass conclusion:
- Burn-down is started with concrete replay execution evidence.
- No behavior-drift evidence observed in this pass.
- Defaults and strictness policy remain unchanged.

## Replay Delta Pass 1 (Build-Wired)

Build-wired replay commands executed:

| Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- |
| `zig build test --summary all -- --test-filter "nip44 valid vectors derive conversation keys"` | pass (`448/450` tests passed, `2` skipped) | `pass` for `UT-E-003` replay delta | build-wired NIP-44 replay is now in place for phase tracking |
| `zig build test --summary all -- --test-filter "bip340 vectors classify with boundary-direct parity"` | pass (`448/450` tests passed, `2` skipped) | `pass` for `UT-E-004` replay delta | build-wired secp/BIP340 parity replay is now in place |

Delta-pass conclusion:
- Prior `UT-E-004` focused direct-module `harness-issue` is mitigated by the build-wired replay command now in place.
- No behavior-drift evidence observed in this delta pass.
- Defaults and strictness policy remain unchanged.

## Step 1 Pass Entry (External Cross-Language Replay)

- Step: 1 (run replay fixtures through an external implementation).
- External implementation: `github.com/nbd-wtf/go-nostr/nip44`.
- Temporary harness path: `/workspace/projects/noztr/.phasef-go/main.go`.
- Fixture set replayed: `docs/plans/phase-f-replay-inputs.md` (`UT-E-003-FX-001`..`UT-E-003-FX-005`).

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `1` | `UT-E-003` | `go get github.com/nbd-wtf/go-nostr/nip44@v0.52.3` | pass | `pass` | dependency hydration for temporary harness only |
| `1` | `UT-E-003` | `go run .` (in `.phasef-go`) | pass (`5/5` fixtures) | `pass` | each fixture passed decrypt parity and custom-nonce encrypt parity |

Step 1 conclusion:
- External cross-language replay evidence is now recorded with concrete command output.
- `UT-E-003` classification outcome for this step is `pass`.
- Defaults and strictness policy remain unchanged.

## Step 2 Pass Entry (UT-E-003 Replay Inputs)

- Step: 2 (explicit cross-implementation replay input set).
- Input set: `docs/plans/phase-f-replay-inputs.md` (`UT-E-003-FX-001`..`UT-E-003-FX-005`).
- Local replay run reference: `2026-03-08T20:38:39Z` baseline plus build-wired delta pass in this artifact.

| Step | Risk ID | Input evidence | Replay command reference | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `2` | `UT-E-003` | `docs/plans/phase-f-replay-inputs.md` | `zig build test --summary all -- --test-filter "nip44 valid vectors derive conversation keys"`; `zig build test --summary all` | `pass` | replay input set is explicit and stable; no local drift signal |

Step 2 conclusion:
- `UT-E-003` replay inputs are now explicit and replay-ready for cross-implementation checks.
- Current local replay outcome classification is `pass`.
- Aggregate dual-run gate cadence check executed after this increment pass (`enable_i6_extensions=true`
  and `enable_i6_extensions=false`): `zig build test --summary all` pass (`448/450`, `2` skipped)
  and `zig build` pass.
- Defaults and strictness policy remain unchanged.

## Step 3 Pass Entry (UT-E-004 Replay Expansion)

- Step: 3 (expanded secp boundary mutation/differential replay depth).
- Scope: `src/crypto/secp256k1_backend.zig` deterministic mutation matrix expansion over valid
  BIP340 baseline vectors.
- Mutation classes covered:
  - message bitflip
  - signature bitflip
  - pubkey bitflip
  - wrong-length public key class via existing hex-input seam

| Step | Risk ID | Replay command reference | Outcome classification | Typed-class mapping stability | Notes |
| --- | --- | --- | --- | --- | --- |
| `3` | `UT-E-004` | `zig build test --summary all`; `zig build` | `pass` | `no-drift` | expanded replay matrix passes; boundary classifier parity with direct shim classifier remains stable |

Step 3 conclusion:
- `UT-E-004` replay depth is expanded beyond the prior single mutation case.
- Typed class mapping stability outcome is `no-drift` (boundary/direct parity holds for all new
  mutation classes, and wrong-length seam classification remains stable).
- Defaults and strictness policy remain unchanged.

## Step 4 Pass Entry (UT-E-004 Next-Step 2 Matrix Notch)

- Step: 4 (UT-E-004 next-step 2 matrix notch over hex-input seams).
- Scope: `src/crypto/secp256k1_backend.zig` tests-only expansion; production API/behavior unchanged.
- Added seam classes:
  - wrong-length message hex,
  - wrong-length signature hex,
  - non-hex public key hex input,
  - non-hex message hex input,
  - non-hex signature hex input.
- Parity requirement: each new class asserts boundary classifier parity with direct classifier and
  deterministic typed class expectation (`invalid_public_key` or `invalid_signature`).

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `4` | `UT-E-004` | `zig fmt src/crypto/secp256k1_backend.zig` | pass | `pass` | formatting gate applied before aggregate rerun |
| `4` | `UT-E-004` | `zig build test --summary all` | pass (`8/8` steps, `454/456` tests passed, `2` skipped) | `pass` | expanded seam/mutation matrix remains parity-stable |
| `4` | `UT-E-004` | `zig build` | pass | `pass` | static library build remains healthy after matrix expansion |

Step 4 conclusion:
- `UT-E-004` next-step 2 matrix expansion outcome classification is `pass`.
- Typed-class mapping stability remains `no-drift` for all new seam classes.
- Aggregate dual-run gate cadence check executed after this expanded-matrix increment pass
  (`enable_i6_extensions=true` and `enable_i6_extensions=false`): latest `zig build test --summary all`
  pass (`454/456`, `2` skipped) and `zig build` pass.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 5 Documentation Lock

- Aggregate dual-run gates were executed after each cadence increment:
  TS parity-all step (`8`) and rust depth-notch step (`9`).
- Latest aggregate result remains passing: `zig build test --summary all` (`454/456`, `2` skipped)
  and `zig build`.
- Trigger-governance status: no `UT-E-001`/`A-D-001` trigger criteria fired, so no
  policy/default changes were considered.
- Rule remains: any future trigger firing requires a decision-log entry before any default changes.

## Step 6 Persistent Cross-Language Replay Harnesses

- Step: 6 (promote replay harnesses to persistent `tools/interop/` layout and execute all
  cross-language runs against one shared fixture file).
- Shared fixture file: `tools/interop/fixtures/nip44_ut_e_003.json`
  (`UT-E-003-FX-001`..`UT-E-003-FX-005`).
- Harnesses:
  - Go: `tools/interop/go-nostr-nip44`
  - Rust: `tools/interop/rust-nostr-nip44`
  - TypeScript: `tools/interop/ts-nostr-tools-nip44`

| Step | Risk ID | Implementation | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `6` | `UT-E-003` | go-nostr `github.com/nbd-wtf/go-nostr/nip44` | `go run .` (in `tools/interop/go-nostr-nip44`) | pass (`5/5` fixtures) | `pass` | decrypt parity and custom-nonce encrypt parity both matched fixture payloads |
| `6` | `UT-E-003` | rust-nostr `nostr` crate `v0.44.2` (`nip44::v2`) | `cargo run --manifest-path Cargo.toml` (in `tools/interop/rust-nostr-nip44`) | pass (`5/5` fixtures) | `pass` | decrypt parity and deterministic encrypt parity matched using fixed-nonce RNG injection |
| `6` | `UT-E-003` | TypeScript `nostr-tools/nip44` | `npm run run` (in `tools/interop/ts-nostr-tools-nip44`) | pass (`5/5` fixtures) | `pass` | decrypt parity and custom-nonce encrypt parity both matched fixture payloads |

Step 6 conclusion:
- Persistent interop harnesses are now in-repo under `tools/interop/` for reuse by future NIP
  replay tracks.
- Replay classification outcomes: Go `pass`, Rust `pass`, TypeScript `pass`.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 7 Pass Entry (rust-nostr parity-all matrix)

- Step: 7 (comprehensive overlap validation for all currently implemented `noztr` NIPs).
- Harness: `tools/interop/rust-nostr-parity-all` (`nostr` crate `v0.44.2`, `all-nips`).
- Matrix artifact: `docs/plans/phase-f-rust-nostr-parity.md`.

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `7` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`NIP-01/02/09/11/13/19/21/42/44/59/65 PASS`; `NIP-40/45/50/70/77 UNSUPPORTED`) | `pass` | supported overlap checks passed; unsupported NIPs explicitly reported |

Step 7 conclusion:
- rust-nostr parity-all pass classification is `pass` for this execution slice.
- Canonical matrix coverage for all implemented NIPs is now recorded.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 8 Pass Entry (ts-nostr parity-all matrix)

- Step: 8 (comprehensive overlap validation for all currently implemented `noztr` NIPs using
  `nostr-tools`).
- Harness: `tools/interop/ts-nostr-parity-all` (`nostr-tools` `v2.7.2`).
- Matrix artifact: `docs/plans/phase-f-ts-nostr-tools-parity.md`.

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `8` | `UT-E-003` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | pass (`NIP-01/13/19/21/42/44 PASS`; `NIP-02/09/11/40/45/50/59/65/70/77 UNSUPPORTED`; `SUMMARY pass=6 fail=0 unsupported=10 total=16`) | `pass` | supported overlap checks passed; remaining implemented NIPs explicitly reported as `UNSUPPORTED` |

Step 8 conclusion:
- ts-nostr parity-all pass classification is `pass` for this execution slice.
- Canonical matrix coverage for all implemented NIPs is now recorded for the TypeScript lane.
- Explicit no-default-change note: defaults unchanged; frozen defaults and strictness policy remain unchanged.

## Step 9 Pass Entry (rust-nostr parity-all depth notch)

- Step: 9 (expand rust-nostr parity depth, not breadth, for supported overlap checks).
- Harness: `tools/interop/rust-nostr-parity-all` (`nostr` crate `v0.44.2`, `all-nips`).
- Depth targets: `NIP-19`, `NIP-21`, `NIP-42`, `NIP-44`, `NIP-65` malformed/edge negatives.

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `9` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`NIP-01/02/09/11/13/19/21/42/44/59/65 PASS`; `NIP-40/45/50/70/77 UNSUPPORTED`; `SUMMARY pass=11 fail=0 unsupported=5 total=16`) | `pass` | coverage set unchanged; added malformed/edge negatives for `NIP-19/21/42/44/65` |
| `9` | `UT-E-004` | `zig build test --summary all && zig build` | pass (`454/456` tests passed, `2` skipped; build pass) | `pass` | aggregate gate remains green after parity-depth increment |

Step 9 conclusion:
- rust-nostr parity-all depth-notch classification is `pass`.
- Coverage breadth is unchanged; only supported-check malformed/edge depth increased.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Next Burndown Tasks

1. `UT-E-003` owner: Phase F owner
   - Expand differential replay depth beyond pinned vectors and capture the next replay delta outcomes.
2. `UT-E-004` owner: Phase I owner
   - Expand boundary corpus depth beyond current parity replay and record typed mismatch mapping if observed.
3. Shared owner: active phase owner
   - Re-run aggregate gates after each replay addition and append outcomes in this artifact.
