# Phase F Parity Matrix (Model v1)

Date: 2026-03-09

Canonical side-by-side matrix for implemented `noztr` NIPs across rust and TypeScript parity-all lanes.

## Taxonomy and Depth

- Taxonomy: `LIB_SUPPORTED`, `HARNESS_COVERED`, `NOT_COVERED_IN_THIS_PASS`, `LIB_UNSUPPORTED`.
- Depth: `BASELINE`, `EDGE`, `DEEP`.
- Default for this rollout: implemented NIPs without an executed overlap check are
  `NOT_COVERED_IN_THIS_PASS`.

## Matrix

| NIP | Rust taxonomy | Rust depth | Rust result | Rust evidence command | TS taxonomy | TS depth | TS result | TS evidence command | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NIP-01 | `HARNESS_COVERED` | `BASELINE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `BASELINE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | event baseline checks |
| NIP-02 | `HARNESS_COVERED` | `BASELINE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | TS lane not yet wired |
| NIP-09 | `HARNESS_COVERED` | `BASELINE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | TS lane not yet wired |
| NIP-11 | `HARNESS_COVERED` | `BASELINE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | TS lane not yet wired |
| NIP-13 | `HARNESS_COVERED` | `BASELINE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `BASELINE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | deterministic PoW sample |
| NIP-19 | `HARNESS_COVERED` | `EDGE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | roundtrip + invalid-path checks |
| NIP-21 | `HARNESS_COVERED` | `EDGE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | URI boundary checks |
| NIP-40 | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | both lanes pending |
| NIP-42 | `HARNESS_COVERED` | `EDGE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `EDGE` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | auth event checks |
| NIP-44 | `HARNESS_COVERED` | `DEEP` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `HARNESS_COVERED` | `DEEP` | `PASS` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | fixture replay + deterministic encrypt/decrypt |
| NIP-45 | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | both lanes pending |
| NIP-50 | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | both lanes pending |
| NIP-59 | `HARNESS_COVERED` | `BASELINE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | TS lane not yet wired |
| NIP-65 | `HARNESS_COVERED` | `EDGE` | `PASS` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | TS lane not yet wired |
| NIP-70 | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | both lanes pending |
| NIP-77 | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | `NOT_COVERED_IN_THIS_PASS` | `BASELINE` | `NOT_RUN` | `npm run run` (in `tools/interop/ts-nostr-parity-all`) | both lanes pending |

Policy note: parity model v1 adoption introduces no frozen-default or strictness-policy change.
