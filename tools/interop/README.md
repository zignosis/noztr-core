# Interop Harnesses

Persistent interop harnesses for NIP-44 replay and parity-all checks.

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
- Per-NIP output format: `NIP-XX PASS|FAIL|UNSUPPORTED`
- Expected summary shape:
  - `SUMMARY pass=<n> fail=0 unsupported=<n> total=<n>` on success.
  - process exits non-zero on any supported-NIP failure.

## ts-nostr parity-all harness

- Harness path: `tools/interop/ts-nostr-parity-all`
- Scope: runtime overlap checks for implemented `noztr` NIPs against `nostr-tools`.
- Supported checks in this lane: `NIP-01`, `NIP-13`, `NIP-19`, `NIP-21`, `NIP-42`, `NIP-44`.
- Per-NIP output format: `NIP-XX PASS|FAIL|UNSUPPORTED`
- Expected summary shape:
  - `SUMMARY pass=<n> fail=0 unsupported=<n> total=<n>` on success.
  - process exits non-zero on any supported-NIP failure.
