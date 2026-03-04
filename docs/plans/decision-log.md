# Decision Log

Immutable record of accepted planning decisions.

## Change Control

- Add new decisions; do not edit prior decisions except for typo fixes.
- Supersede old decisions by adding a new decision that references prior IDs.
- Every decision requires rationale, tradeoffs, and reversal trigger.

## D-001: Freeze parity source snapshots

- Status: accepted
- Date: 2026-03-04
- Decision: freeze local source snapshots for applesauce, rust-nostr, and
  libnostr-z at pinned commits listed in `docs/plans/nostr-principles.md`.
- Why: reproducible analysis across phased planning.
- Tradeoff: stale source risk versus reproducibility.
- Reversal Trigger: parity analysis requires upstream changes not represented in
  pinned commits.
- Supersedes: none

## D-002: Define parity as behavior, not API shape

- Status: accepted
- Date: 2026-03-04
- Decision: parity means behavioral parity (parse, validate, serialize, verify,
  and tests), not API shape parity.
- Why: preserve Zig-native API quality and constraints.
- Tradeoff: adapter work versus cleaner long-term core API.
- Reversal Trigger: explicit product requirement for source-compatible APIs.
- Supersedes: none

## D-003: Strict-by-default protocol policy

- Status: accepted
- Date: 2026-03-04
- Decision: strict parsing/validation by default; compatibility handling only by
  documented exception with tests.
- Why: deterministic behavior and lower safety risk.
- Tradeoff: reduced permissiveness versus clearer semantics.
- Reversal Trigger: high-value interop blocked without broad compatibility mode.
- Supersedes: none

## D-004: Mandatory phase closure gate

- Status: accepted
- Date: 2026-03-04
- Decision: no phase closure without tradeoff records and ambiguity checkpoint.
- Why: prevent silent decision drift and late-stage rework.
- Tradeoff: more process overhead versus higher planning quality.
- Reversal Trigger: demonstrated process bottleneck without quality benefits.
- Supersedes: none
