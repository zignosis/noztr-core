# Interop Harnesses

Persistent interop harnesses for NIP-44 replay and parity-all checks.

Governance status:
- Active parity gate lane: rust (`tools/interop/rust-nostr-parity-all`).
- TypeScript parity-all lane (`tools/interop/ts-nostr-parity-all`) is not an active gate lane; it is
  preserved historical evidence and may be re-run as a secondary ecosystem audit signal.
- Historical evidence is preserved; this scope change does not alter library defaults or strictness.
- Use `bun` for local TypeScript harness install/run commands in this repo; do not use `npm`.

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
- TypeScript parity-all (`nostr-tools`, archived): `tools/interop/ts-nostr-parity-all`

NIP-44 harnesses perform the same checks for every fixture:

1. `decrypt(payload, conversation_key) == plaintext`
2. `encrypt(plaintext, conversation_key, custom_nonce) == payload`

All harnesses print per-fixture pass/fail and a final summary line.
Process exit code is non-zero on any mismatch or runtime error.

## Active run commands

From repository root:

```bash
cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml
zig build test --summary all && zig build
```

## Archived historical commands (not active parity cadence)

```bash
go run ./tools/interop/go-nostr-nip44
cargo run --manifest-path tools/interop/rust-nostr-nip44/Cargo.toml
bun --cwd tools/interop/ts-nostr-tools-nip44 install
bun --cwd tools/interop/ts-nostr-tools-nip44 run run
bun --cwd tools/interop/ts-nostr-parity-all install
bun --cwd tools/interop/ts-nostr-parity-all run run
```

## Expected success output shape

- Per fixture: `UT-E-003-FX-00N PASS decrypt+encrypt parity`
- Final line: `RESULT PASS: 5/5 fixtures`

## rust-nostr parity-all harness

- Harness path: `tools/interop/rust-nostr-parity-all`
- Scope: runtime overlap checks for implemented `noztr` NIPs against `nostr` crate (`v0.44.2`).
- Current runtime coverage: `HARNESS_COVERED` for
  `NIP-01/02/09/10/11/13/18/19/21/22/25/27/40/42/44/45/50/51/59/65/70/77`.
- NIP-59 depth: `DEEP`.
- Per-NIP output format (stable parse shape):
  - `NIP-XX | taxonomy=<...> | depth=<...> | result=PASS|FAIL|NOT_RUN [| detail=<...>]`
- Expected summary shape:
  - `SUMMARY pass=<n> fail=<n> harness_covered=<n> lib_supported=<n> not_covered_in_this_pass=<n> lib_unsupported=<n> total=<n>`
  - process exits non-zero only when a `HARNESS_COVERED` check fails.

## NIP-59 deep parity evidence (rust lane)

- Command: `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml`
- Harness area: `tools/interop/rust-nostr-parity-all/src/main.rs` (`check_nip59`)
- Covered deep checks:
  1. valid wrap/unwrap baseline,
  2. wrong recipient rejection,
  3. non-giftwrap event rejection,
  4. sender-mismatch rejection (spoofed rumor pubkey),
  5. deterministic repeated unwrap consistency.
- noztr comparison command: `zig build test --summary all -- --test-filter "nip59"`
- noztr test area: `src/nip59_wrap.zig`

## ts-nostr parity-all harness

- Harness path: `tools/interop/ts-nostr-parity-all`
- Status: non-gating audit evidence lane only (not part of active pass/fail cadence).
- Scope: runtime overlap checks for implemented `noztr` NIPs against `nostr-tools`.
- Current runtime coverage: `HARNESS_COVERED` for
  `NIP-01/02/09/10/11/13/18/19/21/25/27/40/42/44/45/50/59/65/70/77`.
- Additional implemented NIPs are cross-checked during the audit with explicit source review when
  `nostr-tools` does not expose a dedicated runtime helper.
- NIP-40 implementation-path dependency:
  - `nostr-tools` does not export `./nip40` in package `exports` for this version.
  - harness uses file-URL fallback to `node_modules/nostr-tools/lib/esm/nip40.js` when needed.
- Per-NIP output format (stable parse shape):
  - `NIP-XX | taxonomy=<...> | depth=<...> | result=PASS|FAIL|NOT_RUN [| detail=<...>]`
- Expected summary shape:
  - `SUMMARY pass=<n> fail=<n> harness_covered=<n> lib_supported=<n> not_covered_in_this_pass=<n> lib_unsupported=<n> total=<n>`
  - process exits non-zero only when a `HARNESS_COVERED` check fails.
