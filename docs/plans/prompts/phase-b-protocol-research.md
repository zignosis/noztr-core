# Phase B: Protocol Research Prompt

Goal: create protocol-grounded guidance for only the NIPs selected in Phase A.

## Inputs

- `docs/plans/v1-scope.md`
- `docs/plans/nostr-principles.md`
- `docs/nips/*.md` for selected NIPs only

## Required Work

- Document wire format rules, edge cases, and ambiguity points.
- Identify cross-NIP dependencies and ordering constraints.
- Separate hard requirements from policy choices.
- Capture principle impacts and tradeoffs for each material policy choice.

## Required Output

- `docs/research/v1-protocol-reference.md`
  - per-NIP: canonical rules, limits, and rejection cases
  - interaction matrix between selected NIPs
  - ambiguity register with recommended defaults
  - tradeoff records for strictness vs compatibility choices

## Exit Criteria

- Each selected NIP has acceptance criteria and failure criteria.
- Ambiguities are tagged `decision-needed` or `resolved`.
- Every material policy choice has a tradeoff record.
- No out-of-scope NIP analysis is included.
