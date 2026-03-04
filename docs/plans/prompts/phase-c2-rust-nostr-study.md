# Phase C2: rust-nostr Deep Study Prompt

Goal: extract transferable systems-language lessons from rust-nostr for v1 scope.

## Inputs

- `docs/plans/v1-scope.md`
- `docs/research/v1-protocol-reference.md`
- `docs/research/rust-nostr-study.md` (reference only)
- local mirror at `/workspace/pkgs/nostr`

## Required Work

- Study module boundaries, typed APIs, and conformance testing practices.
- Identify Rust patterns that should not be copied into Zig directly.
- Record adopt/adapt/reject candidates for noztr.
- Record source provenance: local path, origin URL, commit hash, and pin date.

## Required Output

- `docs/research/v1-rust-nostr-deep-study.md`
  - source snapshot metadata (`/workspace/pkgs` path, URL, commit, date)
  - scoped findings
  - transferable patterns and non-transferable patterns
  - adopt/adapt/reject table
  - tradeoff records
  - open questions

## Exit Criteria

- Findings are translated to Zig-native constraints.
- Source snapshot metadata is complete and reproducible.
- Rust crate conventions are not copied as Zig anti-patterns.
- Tradeoffs are documented for each material recommendation.
