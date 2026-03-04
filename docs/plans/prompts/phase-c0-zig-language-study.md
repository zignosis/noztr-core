# Phase C0: Zig Language Study Prompt

Goal: build implementation-ready Zig guidance before contracts are finalized.

## Inputs

- `AGENTS.md`
- `docs/guides/TIGER_STYLE.md`
- `docs/plans/nostr-principles.md`
- `docs/plans/v1-scope.md`
- `docs/research/v1-protocol-reference.md`
- `docs/research/v1-applesauce-deep-study.md`
- `docs/research/v1-rust-nostr-deep-study.md`
- `docs/research/v1-libnostr-z-deep-study.md`
- `docs/guides/zig-patterns.md` (reference only)

## Required Work

- Document Zig idiosyncrasies relevant to protocol and cryptography code.
- Define approved Zig patterns for memory, errors, parsing, and API design.
- Define Zig anti-patterns and footguns to avoid in implementation.
- Document Zig-native alternatives when translating Rust/TS patterns observed in
  C1/C2/C3 studies.

## Required Output

- `docs/guides/zig-patterns.md` (updated, v1-scoped)
- `docs/guides/zig-anti-patterns.md`
- `docs/research/v1-zig-implementation-notes.md`
  - translation notes for cross-language pattern adaptation
  - review checklist for coding agents
  - tradeoff records
  - open questions

## Exit Criteria

- Zig guidance is specific to noztr modules and constraints.
- Every high-risk Zig footgun has a preferred safe pattern.
- Translation notes cover each external study source.
- Tradeoffs are recorded for material Zig design choices.
