# Phase E: Build Plan Prompt

Goal: produce the final implementation schedule and phase gates.

## Inputs

- `docs/plans/nostr-principles.md`
- `docs/plans/v1-scope.md`
- `docs/plans/v1-api-contracts.md`
- `docs/research/v1-implementation-decisions.md`

## Required Work

- Convert contracts into implementation phases with deliverables.
- Add clear exit criteria for each phase.
- Define build/test checkpoints and compatibility expectations.
- Carry unresolved tradeoffs and ambiguities forward with impact radius.

## Required Output

- `docs/plans/build-plan.md`
  - phase-by-phase module schedule
  - test and vector plan per phase
  - risks, assumptions, and open questions
  - unresolved tradeoff register
  - definition of done for implementation handoff

## Exit Criteria

- Plan is executable without architecture clarification.
- Each phase has measurable completion criteria.
- Unresolved tradeoffs are explicit with mitigation and reversal trigger.
- Open questions are explicit and minimal.
