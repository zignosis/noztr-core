# Phase 0: Philosophy And Principles Prompt

Goal: extract the Nostr design ethos from `building-nostr.pdf` into enforceable
principles for all later phases.

## Inputs

- `AGENTS.md`
- `docs/guides/building-nostr.pdf`
- `docs/research/building-nostr-study.md` (reference only)

## Required Work

- Extract the protocol philosophy that must shape library design decisions.
- Convert philosophy into concrete principles with stable IDs (`P01`, `P02`, ...).
- Freeze default planning policies in canonical docs.
- Identify anti-goals and design traps that violate the philosophy.
- Define how principles will be applied in later phases.

## Required Output

- `docs/plans/nostr-principles.md`
  - frozen defaults (`D-001` to `D-004`)
  - principle list with IDs and one-line rule per principle
  - rationale per principle
  - anti-goals and forbidden shortcuts
  - principles compliance checklist
  - open questions
  - tradeoff records
- `docs/plans/decision-log.md`
  - immutable decision records for `D-001` to `D-004`
  - change-control rules for future updates

## Exit Criteria

- Principles are actionable, testable, and referenced by stable IDs.
- Frozen defaults are present and mirrored in decision log entries.
- Tradeoffs are recorded for all material principle interpretations.
- Any unresolved ambiguity is tagged and impact-scoped.
