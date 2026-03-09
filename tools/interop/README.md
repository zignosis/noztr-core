# Interop Harnesses

Persistent interop harnesses for NIP-44 replay and parity-all checks.

## Parity Model v1 (taxonomy + depth)

- Taxonomy terms (canonical):
  - `LIB_SUPPORTED`
  - `HARNESS_COVERED`
  - `NOT_COVERED_IN_THIS_PASS`
  - `LIB_UNSUPPORTED`
- Depth labels (canonical):
  - `BASELINE`
  - `EDGE`
  - `DEEP`
- Default rule for this rollout:
  - implemented `noztr` NIPs without an executed overlap check are
    `NOT_COVERED_IN_THIS_PASS`.
  - do not emit `LIB_UNSUPPORTED` unless the harness code proves it explicitly.

## Fixture source

- Shared fixture file: `tools/interop/fixtures/nip44_ut_e_003.json`
- Source anchor: `docs/plans/phase-f-replay-inputs.md`

## Harnesses

- Go (`go-nostr`): `tools/interop/go-nostr-nip44`
- Rust (`rust-nostr`): `tools/interop/rust-nostr-nip44`
- TypeScript (`nostr-tools`): `tools/interop/ts-nostr-tools-nip44`
- Rust parity-all (`nostr`): `tools/interop/rust-nostr-parity-all`
- TypeScript parity-all (`nostr-tools`): `tools/interop/ts-nostr-parity-all`

NIP-44 harnesses perform the same checks for every fixture:

1. `decrypt(payload, conversation_key) == plaintext`
2. `encrypt(plaintext, conversation_key, custom_nonce) == payload`

All harnesses print per-fixture pass/fail and a final summary line.
Process exit code is non-zero on any mismatch or runtime error.

## Run commands

From repository root:

```bash
go run ./tools/interop/go-nostr-nip44
cargo run --manifest-path tools/interop/rust-nostr-nip44/Cargo.toml
cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml
npm --prefix tools/interop/ts-nostr-tools-nip44 install
npm --prefix tools/interop/ts-nostr-tools-nip44 run run
npm --prefix tools/interop/ts-nostr-parity-all install
npm --prefix tools/interop/ts-nostr-parity-all run run
```

## Expected success output shape

- Per fixture: `UT-E-003-FX-00N PASS decrypt+encrypt parity`
- Final line: `RESULT PASS: 5/5 fixtures`

## rust-nostr parity-all harness

- Harness path: `tools/interop/rust-nostr-parity-all`
- Scope: runtime overlap checks for implemented `noztr` NIPs against `nostr` crate (`v0.44.2`).
- Current coverage: `HARNESS_COVERED` for all implemented NIPs (`NIP-01/02/09/11/13/19/21/40/42/44/45/50/59/65/70/77`).
- Per-NIP output format (stable parse shape):
  - `NIP-XX | taxonomy=<...> | depth=<...> | result=PASS|FAIL|NOT_RUN [| detail=<...>]`
- Expected summary shape:
  - `SUMMARY pass=<n> fail=<n> harness_covered=<n> lib_supported=<n> not_covered_in_this_pass=<n> lib_unsupported=<n> total=<n>`
  - process exits non-zero only when a `HARNESS_COVERED` check fails.

## ts-nostr parity-all harness

- Harness path: `tools/interop/ts-nostr-parity-all`
- Scope: runtime overlap checks for implemented `noztr` NIPs against `nostr-tools`.
- Current coverage: `HARNESS_COVERED` for all implemented NIPs (`NIP-01/02/09/11/13/19/21/40/42/44/45/50/59/65/70/77`).
- NIP-40 implementation-path dependency:
  - `nostr-tools` does not export `./nip40` in package `exports` for this version.
  - harness uses file-URL fallback to `node_modules/nostr-tools/lib/esm/nip40.js` when needed.
- Per-NIP output format (stable parse shape):
  - `NIP-XX | taxonomy=<...> | depth=<...> | result=PASS|FAIL|NOT_RUN [| detail=<...>]`
- Expected summary shape:
  - `SUMMARY pass=<n> fail=<n> harness_covered=<n> lib_supported=<n> not_covered_in_this_pass=<n> lib_unsupported=<n> total=<n>`
  - process exits non-zero only when a `HARNESS_COVERED` check fails.
