# Phase A: Scope Freeze Prompt

Goal: define v1 scope and non-goals before deeper planning.

## Inputs

- `AGENTS.md`
- `docs/plans/nostr-principles.md`
- `docs/plans/decision-log.md`
- `docs/research/*.md`
- `docs/plans/build-plan.md`

## Required Decisions

- Confirm product target: low-level Zig protocol library.
- Apply frozen defaults from `D-001` to `D-004`.
- Confirm horizon model:
  - `H1`: protocol support parity with `libnostr-z`.
  - `H2`: expansion to as many stable NIPs as practical.
- Classify each NIP into one of:
  - `parity-core`
  - `parity-optional`
  - `expansion-candidate`
  - `defer`
  - `rejected`
- Define non-goals for v1 (what will not be implemented).

## Required Output

- `docs/plans/v1-scope.md`
  - feature matrix with status per NIP
  - horizon tags (`H1` and `H2`) per NIP
  - rationale per classification
  - explicit non-goals
  - tradeoff records
  - open questions

## Exit Criteria

- No NIP remains unclassified.
- Every classification has one rationale sentence.
- Every material decision has a tradeoff record.
- Any deviation from frozen defaults is logged as a new decision entry.
- Ambiguities include impact and status (`resolved` or `decision-needed`).
- Open questions are explicit and bounded.
