# Phase F Parity Matrix (Model v1)

Date: 2026-03-09

Canonical parity matrix for implemented `noztr` NIPs.

Governance status:
- Rust lane (`rust-nostr`) is the only active parity gate lane.
- TypeScript lane (`nostr-tools`) is archived for historical evidence only.
- Historical TypeScript evidence is preserved here and remains referenceable.

## Taxonomy and Depth

- Taxonomy: `LIB_SUPPORTED`, `HARNESS_COVERED`, `NOT_COVERED_IN_THIS_PASS`, `LIB_UNSUPPORTED`.
- Depth: `BASELINE`, `EDGE`, `DEEP`.
- Default for this rollout: implemented NIPs without an executed overlap check are
  `NOT_COVERED_IN_THIS_PASS`.
- Support-versus-coverage rule: `LIB_UNSUPPORTED` appears only when the harness executes an explicit
  runtime capability probe proving unsupported status.

## Matrix

| NIP | Rust taxonomy (active) | Rust depth | Rust result | Rust evidence command | TS taxonomy (archived) | TS depth | TS result | TS evidence command | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NIP-01 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds tampered-content rejection in addition to tampered-signature rejection |
| NIP-02 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `BASELINE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds malformed `p`-tag non-hex rejection path |
| NIP-09 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `BASELINE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds malformed `e`-tag non-hex rejection path |
| NIP-11 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep confirms unknown-field acceptance while preserving strict known-field typing |
| NIP-13 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds empty-input leading-zero boundary (`0` bits) |
| NIP-19 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds mixed-case bech32 rejection in addition to invalid-prefix/checksum checks |
| NIP-21 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds malformed `nostr:npub...` decode rejection |
| NIP-40 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds missing-expiration-value negative plus existing boundary/malformed checks |
| NIP-42 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds missing-challenge-tag rejection via auth-tag mutation |
| NIP-44 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `DEEP` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds tampered-payload MAC-bitflip rejection on top of fixture replay |
| NIP-45 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds malformed relay top-level object rejection |
| NIP-50 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds array-typed `search` rejection in parser boundary checks |
| NIP-59 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep now includes malformed gift-wrap payload-content rejection in addition to prior deep checks |
| NIP-65 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `BASELINE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds malformed relay-url tag rejection |
| NIP-70 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds malformed dash-key (`" -"`) non-protected shape rejection |
| NIP-77 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | rust deep adds malformed NEG-MSG subscription-id type rejection |

Active cadence note: active pass/fail cadence uses only the rust parity harness plus aggregate `zig`
gates.

NIP-59 comparative note:
- rust deep evidence command: `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml`
- noztr evidence command: `zig build test --summary all -- --test-filter "nip59"`
- noztr test area: `src/nip59_wrap.zig`

Rust deep-pass note:
- Active rust lane now records `DEEP` depth for all implemented NIPs (`16/16`) with added malformed
  or negative assertions per check function.

Policy note: this governance-scope change introduces no frozen-default or strictness-policy change.
