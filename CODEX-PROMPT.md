# Build noztr from scratch

Pure Zig Nostr protocol library. Read `AGENTS.md` for standards and constraints.

Do not write library source code in this track. Documentation and planning only.

---

## Workflow Model

- Use one prompt per phase from `docs/plans/prompts/`.
- Do not combine phases in one run.
- Do not skip phase gates.
- Stop phase advancement when ambiguity is unresolved and high impact.
- Record tradeoffs for every material decision.
- Respect frozen defaults in `docs/plans/nostr-principles.md` and track changes
  in `docs/plans/decision-log.md`.

---

## Phase Order

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

---

## Scope Policy

- Use a two-horizon scope model:
  - `H1`: protocol support parity with `libnostr-z`.
  - `H2`: expansion to additional stable NIPs.
- Prioritize protocol correctness, determinism, and bounded memory behavior.

---

## Required Output Structure Per Phase

Every phase output must include:

- `Decisions`
- `Tradeoffs`
- `Open Questions`
- `Principles Compliance`

Use tradeoff IDs in the form `T-<phase>-<number>`.

---

## Constraints

- Do not modify `src/`, `README.md`, or `build.zig` in research/planning phases.
- Output docs only under `docs/research/`, `docs/guides/`, and `docs/plans/`.
- When uncertain, flag as open question and do not guess.
