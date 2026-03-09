# Phase F Rust-nostr Parity Pass

Date: 2026-03-08

Purpose: record one-pass rust-nostr overlap validation for all currently implemented `noztr` NIPs.

## Decisions

- `PF-RNP-001`: add persistent harness `tools/interop/rust-nostr-parity-all` for reusable
  overlap checks across implemented and future NIPs.
- `PF-RNP-002`: classify this pass as `pass` when all supported overlap checks return `PASS`.
- `PF-RNP-003`: report explicit `UNSUPPORTED` for implemented NIPs without rust-nostr overlap
  helpers in this pass (`NIP-40`, `NIP-45`, `NIP-50`, `NIP-70`, `NIP-77`).
- `PF-RNP-004`: expand depth (not breadth) for supported overlap checks with one malformed/edge
  notch in `NIP-19`, `NIP-21`, `NIP-42`, `NIP-44`, and `NIP-65`.

## Parity Matrix

| NIP | rust-nostr support status | validation outcome | command/evidence reference | notes |
| --- | --- | --- | --- | --- |
| NIP-01 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | event parse/verify baseline |
| NIP-02 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | contact-list builder/tag presence |
| NIP-09 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | deletion builder semantics baseline |
| NIP-11 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | relay-info parse/roundtrip baseline |
| NIP-13 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | deterministic leading-zero sample |
| NIP-19 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | bech32 roundtrip plus invalid-prefix and invalid-decode negative assertions |
| NIP-21 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | nostr URI roundtrip plus invalid-URI and forbidden-entity (`nsec`) negative assertions |
| NIP-40 | unsupported overlap | UNSUPPORTED | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | explicit unsupported report |
| NIP-42 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | auth helper plus challenge-mismatch, relay-mismatch, and non-auth-kind negative assertions |
| NIP-44 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | replays `tools/interop/fixtures/nip44_ut_e_003.json` plus malformed-payload negative assertion |
| NIP-45 | unsupported overlap | UNSUPPORTED | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | explicit unsupported report |
| NIP-50 | unsupported overlap | UNSUPPORTED | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | explicit unsupported report |
| NIP-59 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | gift-wrap unwrap happy-path baseline |
| NIP-65 | supported overlap | PASS | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | relay metadata extraction plus invalid-marker negative assertion |
| NIP-70 | unsupported overlap | UNSUPPORTED | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | explicit unsupported report |
| NIP-77 | unsupported overlap | UNSUPPORTED | `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` | explicit unsupported report |

Pass classification: `pass`.

Depth-notch classification (malformed/edge expansion, same coverage set): `pass`.

Policy note: no frozen-default or strictness-policy change is introduced by this pass.

## Tradeoffs

## Tradeoff T-F-RNP-001: Single reusable parity harness versus one-off command checks

- Context: this pass requires immediate evidence and reusable scaffolding for future NIPs.
- Options:
  - O1: write one persistent multi-NIP harness.
  - O2: run ad-hoc one-off commands without a shared harness.
- Decision: O1.
- Benefits: repeatable parity evidence and lower future setup cost.
- Costs: one additional tool artifact to maintain.
- Risks: harness drift from intended matrix coverage.
- Mitigations: keep explicit per-NIP output and matrix-linked command references.
- Reversal Trigger: future parity checks are better served by a different canonical harness layout.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: Phase F rust-nostr overlap evidence and future NIP additions.

## Open Questions

- None for this pass.

## Principles Compliance

- `P01`: trust-boundary overlap checks remain explicit and test-backed in the harness.
- `P03`: parity evidence is behavior-focused (runtime checks), not API-shape focused.
- `P05`: deterministic outputs are recorded with per-NIP status lines and one summary line.
- `P06`: harness exits non-zero on supported overlap failures and is reusable for bounded future runs.
