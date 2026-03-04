# Phase Prompts

Use one prompt per phase. Do not combine phases in one run.

## Prompt Order

0. `phase-0-philosophy-and-principles.md`
1. `phase-a-scope-freeze.md`
2. `phase-b-protocol-research.md`
3. `phase-c1-applesauce-study.md`
4. `phase-c2-rust-nostr-study.md`
5. `phase-c3-libnostr-z-study.md`
6. `phase-c0-zig-language-study.md`
7. `phase-c4-implementation-synthesis.md`
8. `phase-d-contracts-vectors.md`
9. `phase-e-build-plan.md`
10. `phase-f-implementation-handoff.md`

## Global Rules

- Complete the current phase exit criteria before moving on.
- Keep outputs phase-local. Avoid writing future-phase documents early.
- Keep all outputs under `docs/`.
- Every phase output must include these sections:
  - `Decisions`
  - `Tradeoffs`
  - `Open Questions`
  - `Principles Compliance`
- Every material decision requires a tradeoff entry.
  Use IDs in the form `T-<phase>-<number>`.
- Frozen defaults are defined in `docs/plans/nostr-principles.md` and tracked in
  `docs/plans/decision-log.md`.
- If uncertainty remains, add it to open questions and stop phase advancement.
- Run an ambiguity checkpoint before closing any phase.
  If unresolved ambiguity materially changes the output, ask one targeted clarifying
  question with a recommended default, then stop advancement.

## Tradeoff Record Format

Use this record in every phase document whenever a decision is made.

```md
## Tradeoff T-<id>: <short title>

- Context: <decision point and constraints>
- Options:
  - O1: <option>
  - O2: <option>
  - O3: <option, if needed>
- Decision: <chosen option>
- Benefits: <what improves>
- Costs: <what worsens>
- Risks: <failure modes introduced>
- Mitigations: <how risks are reduced>
- Reversal Trigger: <evidence that should change the decision>
- Principles Impacted: <Pxx IDs from `docs/plans/nostr-principles.md`>
- Scope Impacted: <phase/modules/NIPs>
```

## Ambiguity Checkpoint

- Label ambiguities as `resolved`, `decision-needed`, or `accepted-risk`.
- Do not advance if any high-impact ambiguity is still `decision-needed`.
