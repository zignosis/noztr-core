# Phase C1: Applesauce Deep Study Prompt

Goal: derive useful patterns from applesauce for v1-scoped features only.

## Inputs

- `docs/plans/v1-scope.md`
- `docs/research/v1-protocol-reference.md`
- `docs/research/applesauce-study.md` (reference only)
- local mirror at `/workspace/pkgs/applesauce`

## Required Work

- Study applesauce for architecture, event flow, and edge-case handling.
- Separate app-layer ergonomics from protocol-kernel requirements.
- Record adopt/adapt/reject candidates for noztr.
- Record source provenance: local path, origin URL, commit hash, and pin date.

## Required Output

- `docs/research/v1-applesauce-deep-study.md`
  - source snapshot metadata (`/workspace/pkgs` path, URL, commit, date)
  - scoped findings
  - edge cases relevant to v1 modules
  - adopt/adapt/reject table
  - tradeoff records
  - open questions

## Exit Criteria

- Findings map only to v1-scoped modules and decisions.
- Source snapshot metadata is complete and reproducible.
- Tradeoffs are documented for each adopt/adapt/reject decision.
- No framework-coupled advice is proposed for core noztr modules.
