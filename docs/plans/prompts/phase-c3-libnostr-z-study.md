# Phase C3: libnostr-z Deep Study Prompt

Goal: define parity-relevant guidance from libnostr-z under noztr constraints.

## Inputs

- `docs/plans/v1-scope.md`
- `docs/research/v1-protocol-reference.md`
- `docs/research/libnostr-z-study.md` (reference only)
- local mirror at `/workspace/pkgs/libnostr-z`

## Required Work

- Map libnostr-z feature coverage to `parity-core` and `parity-optional` scope.
- Extract API, module, and test patterns that fit pure Zig stdlib constraints.
- Flag dependency and runtime assumptions that must be rejected.
- Record source provenance: local path, origin URL, commit hash, and pin date.

## Required Output

- `docs/research/v1-libnostr-z-deep-study.md`
  - source snapshot metadata (`/workspace/pkgs` path, URL, commit, date)
  - parity gap map
  - adopt/adapt/reject table
  - edge cases to preserve for parity behavior
  - tradeoff records
  - open questions

## Exit Criteria

- Every parity claim is mapped to explicit feature coverage.
- Source snapshot metadata is complete and reproducible.
- Rejected dependency patterns are explicit.
- Tradeoffs are documented for all parity-shaping decisions.
