# Phase F: Implementation Handoff Prompt

Goal: prepare a coding agent to implement the library directly from planning artifacts.

## Inputs

- `AGENTS.md`
- `docs/plans/nostr-principles.md`
- `docs/plans/build-plan.md`
- `docs/plans/v1-api-contracts.md`
- `docs/research/v1-protocol-reference.md`

## Required Work

- Produce a concise coding kickoff brief.
- Define first implementation slice (Phase 0/1 only).
- Define required verification commands and artifact updates.
- Include a tradeoff-aware decision and ambiguity watchlist for coding.

## Required Output

- `docs/plans/implementation-kickoff.md`
  - ordered coding steps for the first implementation phase
  - required tests and vector checks
  - expected files to create/update
  - high-impact tradeoffs to preserve during coding
  - stop conditions if ambiguities are discovered

## Exit Criteria

- A new implementation agent can start coding without planning discovery work.
- Kickoff references exact files, commands, and constraints.
- Handoff includes current open questions and their impact radius.
- Handoff includes unresolved tradeoffs with mitigation guidance.
