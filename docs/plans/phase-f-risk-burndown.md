# Phase F Risk Burndown

Date: 2026-03-09

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
| `7` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`HARNESS_COVERED` checks `PASS`; `NIP-40/45/50/70/77 NOT_COVERED_IN_THIS_PASS`) | `pass` | supported overlap checks passed; non-covered implemented NIPs explicitly classified |

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
| `8` | `UT-E-003` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | pass (`HARNESS_COVERED` checks `PASS`; `NIP-02/09/11/40/45/50/59/65/70/77 NOT_COVERED_IN_THIS_PASS`; summary contract includes taxonomy counters) | `pass` | supported overlap checks passed; remaining implemented NIPs explicitly classified |

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
| `9` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`NIP-01/02/09/11/13/19/21/42/44/59/65 HARNESS_COVERED PASS`; `NIP-40/45/50/70/77 NOT_COVERED_IN_THIS_PASS NOT_RUN`) | `pass` | coverage set unchanged; added malformed/edge negatives for `NIP-19/21/42/44/65` |
| `9` | `UT-E-004` | `zig build test --summary all && zig build` | pass (`454/456` tests passed, `2` skipped; build pass) | `pass` | aggregate gate remains green after parity-depth increment |

Step 9 conclusion:
- rust-nostr parity-all depth-notch classification is `pass`.
- Coverage breadth is unchanged; only supported-check malformed/edge depth increased.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 10 Pass Entry (Parity Model v1 rollout)

- Step: 10 (adopt parity model v1 taxonomy/depth contract and canonical matrix/ledger docs).
- Canonical parity artifacts:
  - `docs/plans/phase-f-parity-matrix.md`
  - `docs/plans/phase-f-parity-ledger.md`

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `10` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`SUMMARY pass=11 fail=0 harness_covered=11 lib_supported=0 not_covered_in_this_pass=5 lib_unsupported=0 total=16`) | `pass` | output now includes stable `taxonomy` and `depth` fields |
| `10` | `UT-E-003` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | pass (`SUMMARY pass=6 fail=0 harness_covered=6 lib_supported=0 not_covered_in_this_pass=10 lib_unsupported=0 total=16`) | `pass` | output now includes stable `taxonomy` and `depth` fields |
| `10` | `UT-E-004` | `zig build test --summary all && zig build` | pass (`454/456` tests passed, `2` skipped; build pass) | `pass` | aggregate gates remain green after rollout |

Step 10 conclusion:
- Parity model v1 is adopted as the Phase F execution model baseline.
- No overloaded `unsupported` wording remains in parity-all lane reporting.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 11 Pass Entry (Parity Expansion + Capability Proof)

- Step: 11 (depth expansion on existing HARNESS_COVERED checks plus explicit capability probes for
  uncovered NIPs in both lanes).
- Scope:
  - rust lane depth negatives expanded on covered checks (`NIP-01/02/09/11/13/59/65`) and runtime
    capability probes added for uncovered `NIP-40/45/50/70/77`.
  - TS lane adds new covered checks for `NIP-11`, `NIP-59`, and `NIP-77`, expands edge negatives on
    prior checks, and adds runtime export probes for remaining uncovered NIPs.

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `11` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`SUMMARY pass=11 fail=0 harness_covered=11 lib_supported=0 not_covered_in_this_pass=5 lib_unsupported=0 total=16`) | `pass` | rust uncovered NIPs now include explicit probe evidence in detail fields; no unsupported proof surfaced |
| `11` | `UT-E-003` | `npm install && npm run run` (in `tools/interop/ts-nostr-parity-all`) | pass (`SUMMARY pass=9 fail=0 harness_covered=9 lib_supported=0 not_covered_in_this_pass=0 lib_unsupported=7 total=16`) | `pass` | TS lane now covers `NIP-11/59/77`; remaining uncovered NIPs are proven `LIB_UNSUPPORTED` via runtime export probes |
| `11` | `UT-E-004` | `zig build test --summary all && zig build` | pass (`454/456` tests passed, `2` skipped; build pass) | `pass` | aggregate gates remain green after parity-expansion increment |

Step 11 conclusion:
- Parity coverage depth increased in both lanes without widening non-covered false negatives.
- Capability proof now explicitly separates support-vs-coverage in harness output and docs.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 12 Pass Entry (TS thorough parity now expansion)

- Step: 12 (practical parity-breadth expansion in TS lane with truthful probe-only classification
  for remaining uncovered NIPs).
- TS harness: `tools/interop/ts-nostr-parity-all` (`nostr-tools` `v2.23.3`).
- Scope:
  - promote `NIP-02`, `NIP-09`, and `NIP-65` from probe-only to `HARNESS_COVERED` structural
    baseline checks.
  - keep existing `NIP-59` and `NIP-77` checks unchanged.
  - run explicit runtime capability probes for remaining uncovered TS NIPs (`NIP-40/45/50/70`) and
    classify by model v1 (`LIB_UNSUPPORTED` only when no public API path is proven).

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `12` | `UT-E-003` | `npm install && npm run run` (in `tools/interop/ts-nostr-parity-all`) | pass (`SUMMARY pass=12 fail=0 harness_covered=12 lib_supported=0 not_covered_in_this_pass=4 lib_unsupported=0 total=16`) | `pass` | TS breadth increased to 12 covered NIPs; remaining 4 are probe-backed supported-but-not-covered |
| `12` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`SUMMARY pass=11 fail=0 harness_covered=11 lib_supported=0 not_covered_in_this_pass=5 lib_unsupported=0 total=16`) | `pass` | rust lane unchanged and still truthful/consistent with model v1 |
| `12` | `UT-E-004` | `zig build test --summary all && zig build` | pass (`454/456` tests passed, `2` skipped; build pass) | `pass` | aggregate gates remain green after TS parity expansion |

Step 12 conclusion:
- TS lane now performs practical parity-breadth checks for implemented optional modules with clear
  structural scope limits.
- Remaining TS uncovered NIPs are explicitly probe-classified as supported public-paths and therefore
  `NOT_COVERED_IN_THIS_PASS`, not `LIB_UNSUPPORTED`.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 13 Pass Entry (Remaining NIPs full parity expansion)

- Step: 13 (promote remaining uncovered NIPs to executable `HARNESS_COVERED` checks in both lanes
  where practical).
- Scope:
  - rust lane: promote `NIP-40`, `NIP-45`, `NIP-50`, `NIP-70`, `NIP-77` from probe-only to
    executable overlap checks.
  - TS lane: promote `NIP-40`, `NIP-45`, `NIP-50`, `NIP-70` from probe-only to executable overlap
    checks (including offline mocked websocket COUNT flow).

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `13` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`SUMMARY pass=16 fail=0 harness_covered=16 lib_supported=0 not_covered_in_this_pass=0 lib_unsupported=0 total=16`) | `pass` | rust remaining NIPs now fully executable with baseline/edge checks |
| `13` | `UT-E-003` | `npm install && npm run run` (in `tools/interop/ts-nostr-parity-all`) | pass (`SUMMARY pass=16 fail=0 harness_covered=16 lib_supported=0 not_covered_in_this_pass=0 lib_unsupported=0 total=16`) | `pass` | TS remaining NIPs now fully executable; NIP-40 uses documented file-URL fallback path |
| `13` | `UT-E-004` | `zig build test --summary all && zig build` | pass (`454/456` tests passed, `2` skipped; build pass) | `pass` | aggregate gates remain green after parity expansion pass |

Step 13 conclusion:
- Both parity lanes now classify all implemented NIPs as `HARNESS_COVERED` with executable checks.
- Parity model v1 output shape and exit semantics remain unchanged.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 14 Pass Entry (NIP-40/NIP-70 incremental depth raise)

- Step: 14 (incremental depth raise on newest covered NIPs first, without broad surface churn).
- Scope:
  - rust lane: `NIP-40` adds malformed-expiration negative; `NIP-70` adds close-variant non-protected
    negative.
  - TS lane: `NIP-40` adds exact-boundary plus malformed-expiration invalid-Date negative;
    `NIP-70` adds malformed protected-tag shape negative.
- Release-facing divergence note added: `docs/release/intentional-divergences.md`.

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `14` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`SUMMARY pass=16 fail=0 harness_covered=16 lib_supported=0 not_covered_in_this_pass=0 lib_unsupported=0 total=16`) | `pass` | rust depth labels raised `NIP-40: BASELINE->EDGE`, `NIP-70: BASELINE->EDGE` |
| `14` | `UT-E-003` | `npm install && npm run run` (in `tools/interop/ts-nostr-parity-all`) | pass (`SUMMARY pass=16 fail=0 harness_covered=16 lib_supported=0 not_covered_in_this_pass=0 lib_unsupported=0 total=16`) | `pass` | TS depth labels: `NIP-40` stays `EDGE` with added negatives, `NIP-70: BASELINE->EDGE` |
| `14` | `UT-E-004` | `zig build test --summary all && zig build` | pass (`454/456` tests passed, `2` skipped; build pass) | `pass` | aggregate gates remain green after parity depth increment |

Step 14 conclusion:
- Incremental depth is raised with evidence-first changes focused on `NIP-40` and `NIP-70`.
- Canonical parity artifacts are synchronized (`phase-f-parity-matrix`, `phase-f-parity-ledger`).
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 15 Pass Entry (NIP-59 deep parity check, rust active lane)

- Step: 15 (raise rust `NIP-59` parity depth from `BASELINE` to `DEEP` with additional edge/negative
  checks).
- Scope:
  - rust harness `check_nip59` now includes baseline unwrap, wrong-recipient reject,
    non-giftwrap reject, sender-mismatch reject, and repeated-unwrap consistency.
  - TypeScript lane remains archived/historical evidence only; no active cadence execution.

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `15` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`NIP-59 taxonomy=HARNESS_COVERED depth=DEEP result=PASS`; `SUMMARY pass=16 fail=0 ...`) | `pass` | output format unchanged; only `NIP-59` depth/evidence expanded |
| `15` | `UT-E-003` | `zig build test --summary all -- --test-filter "nip59"` | pass | `pass` | noztr `src/nip59_wrap.zig` module tests pass against deep parity target area |
| `15` | `UT-E-004` | `zig build test --summary all && zig build` | pass | `pass` | aggregate gates remain green after rust `NIP-59` depth raise |

Step 15 conclusion:
- Rust-only active parity cadence is unchanged.
- `NIP-59` deep parity outcome is `PASS` in rust harness and `PASS` in noztr NIP-59 module tests.
- Explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Step 16 Pass Entry (rust all-NIP deep parity sweep)

- Step: 16 (raise parity depth to `DEEP` for all currently implemented rust-lane NIP checks).
- Scope:
  - rust harness expands each check function with at least one additional malformed/negative assertion
    across `NIP-01/02/09/11/13/19/21/40/42/44/45/50/59/65/70/77`.
  - output contract is unchanged (`NIP-XX | taxonomy=<...> | depth=<...> | result=<...>`), and
    process exit remains non-zero only for `HARNESS_COVERED` failures.

| Step | Risk ID | Command | Result | Outcome classification | Notes |
| --- | --- | --- | --- | --- | --- |
| `16` | `UT-E-003` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | pass (`SUMMARY pass=16 fail=0 harness_covered=16 lib_supported=0 not_covered_in_this_pass=0 lib_unsupported=0 total=16`) | `pass` | rust lane now reports `depth=DEEP` on all 16 implemented NIPs with expanded negative coverage |
| `16` | `UT-E-004` | `zig build test --summary all && zig build` | pass (`450/450` tests passed; build pass) | `pass` | aggregate gates remain green after full deep sweep |

Step 16 conclusion:
- rust active parity gate lane now has deep-pass evidence for all implemented NIPs.
- canonical parity model output shape and failure semantics are unchanged.
- explicit no-default-change note: frozen defaults and strictness policy remain unchanged.

## Next Burndown Tasks

1. `UT-E-003` owner: Phase F owner
   - Expand differential replay depth beyond pinned vectors and capture the next replay delta outcomes.
2. `UT-E-004` owner: Phase I owner
   - Expand boundary corpus depth beyond current parity replay and record typed mismatch mapping if observed.
3. Shared owner: active phase owner
   - Re-run aggregate gates after each replay addition and append outcomes in this artifact.

## Governance Scope Update (2026-03-09)

- Active parity gate lane is now rust-only: `tools/interop/rust-nostr-parity-all`.
- `tools/interop/ts-nostr-parity-all` remains in-repo as archived/historical evidence and is not part
  of active pass/fail cadence.
- Historical TS step records in this artifact (Steps `8`, `11`, `12`, `13`, `14`) remain preserved
  for audit traceability.
- Active parity operations now run:
  - `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml`
  - `zig build test --summary all && zig build`
- Policy note: this governance update changes parity operations scope only; frozen defaults and
  strictness/library behavior remain unchanged.
