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

## Next Burndown Tasks

1. `UT-E-003` owner: Phase F owner
   - Expand differential replay depth beyond pinned vectors and capture the next replay delta outcomes.
2. `UT-E-004` owner: Phase I owner
   - Expand boundary corpus depth beyond current parity replay and record typed mismatch mapping if observed.
3. Shared owner: active phase owner
   - Re-run aggregate gates after each replay addition and append outcomes in this artifact.
