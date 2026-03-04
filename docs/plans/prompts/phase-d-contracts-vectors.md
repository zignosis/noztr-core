# Phase D: Contracts And Vectors Prompt

Goal: define implementation-ready contracts before editing `src/`.

## Inputs

- `docs/plans/v1-scope.md`
- `docs/plans/nostr-principles.md`
- `docs/research/v1-protocol-reference.md`
- `docs/research/v1-implementation-decisions.md`
- `docs/guides/zig-patterns.md`
- `docs/guides/zig-anti-patterns.md`
- `docs/research/v1-zig-implementation-notes.md`

## Required Work

- Define module-by-module public API signatures.
- Define bounds, error sets, invariants, and assertion checklist per module.
- Define test vectors and invalid corpora per module.

## Required Output

- `docs/plans/v1-api-contracts.md`
  - public API signatures with explicit types
  - deterministic behavior contracts
  - error sets and assertion pairs
  - test vector requirements
- tradeoff records and open questions

## Exit Criteria

- Every public function has bounds and explicit failure modes.
- Every module has both happy-path and error-path test requirements.
- Every material design choice has a tradeoff record.
- Contracts are specific enough for coding without clarification.
