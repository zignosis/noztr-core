# Interop Harnesses

Persistent cross-language NIP-44 replay harnesses for `UT-E-003` fixtures.

## Fixture source

- Shared fixture file: `tools/interop/fixtures/nip44_ut_e_003.json`
- Source anchor: `docs/plans/phase-f-replay-inputs.md`

## Harnesses

- Go (`go-nostr`): `tools/interop/go-nostr-nip44`
- Rust (`rust-nostr`): `tools/interop/rust-nostr-nip44`
- TypeScript (`nostr-tools`): `tools/interop/ts-nostr-tools-nip44`

Each harness performs the same checks for every fixture:

1. `decrypt(payload, conversation_key) == plaintext`
2. `encrypt(plaintext, conversation_key, custom_nonce) == payload`

All harnesses print per-fixture pass/fail and a final summary line.
Process exit code is non-zero on any mismatch or runtime error.

## Run commands

From repository root:

```bash
go run ./tools/interop/go-nostr-nip44
cargo run --manifest-path tools/interop/rust-nostr-nip44/Cargo.toml
npm --prefix tools/interop/ts-nostr-tools-nip44 install
npm --prefix tools/interop/ts-nostr-tools-nip44 run run
```

## Expected success output shape

- Per fixture: `UT-E-003-FX-00N PASS decrypt+encrypt parity`
- Final line: `RESULT PASS: 5/5 fixtures`
