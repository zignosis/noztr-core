# Handoff

This handoff captures the current documentation status and immediate direction for the noztr project.

## Current Phase Status

- Phase F: closed.
- Closure basis: implementation kickoff artifact finalized (`docs/plans/implementation-kickoff.md`) and
  closure evidence recorded in `docs/plans/decision-log.md` (`PF-E-001`) with high-impact
  decision-needed count 0.
- Next phase target: Implementation Phase I1 start (after I0 gate pass).

## Completed Tasks

- Completed research docs in `docs/research/`:
  - `building-nostr-study.md`
  - `nostr-protocol-study.md`
  - `applesauce-study.md`
  - `rust-nostr-study.md`
  - `libnostr-z-study.md`
- Completed `docs/guides/zig-patterns.md`.
- Completed `docs/plans/build-plan.md`.
- Added phase prompt pack under `docs/plans/prompts/`.
- Updated `AGENTS.md` with startup, phase-gated workflow, and state-update requirements.
- Replaced `./agent-brief` with a noztr-specific status snapshot script.
- Added tradeoff and ambiguity requirements to phase workflow prompts.
- Added dedicated Phase 0 for `building-nostr.pdf` philosophy extraction.
- Added dedicated Phase C0 for Zig language patterns, anti-patterns, and footguns.
- Split implementation study into C1/C2/C3 deep studies plus C4 synthesis.
- Added frozen defaults baseline in `docs/plans/nostr-principles.md`.
- Added immutable decision records in `docs/plans/decision-log.md`.
- Codified artifact categorization policy:
  pre-v1 broad studies are reference-only, v1 artifacts are canonical,
  and `docs/plans/build-plan.md` is a working baseline until Phase E finalization.
- Finalized Phase 0 principles artifact in `docs/plans/nostr-principles.md`:
  - one-line enforceable rules and rationale for `P01`..`P06`
  - anti-goals and forbidden shortcuts
  - ambiguity checkpoint with impact/status/default/owner tagging
  - concrete principles compliance checks
- Finalized Phase 0 decision artifact in `docs/plans/decision-log.md`:
  - inlined canonical `D-001` snapshot payload
  - related tradeoff traceability links
  - phase closure evidence section and validation rules
- Updated `handoff.md` for Phase 0 closure and Phase A kickoff.
- Added source provenance requirements for C1/C2/C3 prompts.
- Defined handoff ownership as active phase owner before closure.
- Completed Phase A scope freeze artifact:
  - created `docs/plans/v1-scope.md` with H1/H2 feature matrix across NIPs
    01/02/04/05/09/11/12/13/16/17/19/20/21/33/40/42/44/45/50/59/65/70/77
  - recorded Phase A ambiguity checkpoint with all items resolved
  - recorded Phase A closure evidence in `docs/plans/decision-log.md`
- Completed Phase B protocol reference artifact:
  - created `docs/research/v1-protocol-reference.md` for selected H1 NIPs only
  - recorded strictness-vs-compatibility tradeoff decisions for material policy choices
  - recorded Phase B closure evidence in `docs/plans/decision-log.md`
- Completed Phase C1 applesauce deep study artifact:
  - created `docs/research/v1-applesauce-deep-study.md` scoped to v1-selected H1 NIPs and
    build-plan modules
  - recorded Phase C1 closure evidence in `docs/plans/decision-log.md`
- Completed Phase C2 rust-nostr deep study artifact:
  - created `docs/research/v1-rust-nostr-deep-study.md` scoped to v1-selected H1 NIPs and
  build-plan modules
  - recorded Phase C2 closure evidence in `docs/plans/decision-log.md`
- Completed Phase C3 libnostr-z deep study artifact:
  - created `docs/research/v1-libnostr-z-deep-study.md` scoped to v1-selected H1 NIPs and
    build-plan modules
  - recorded Phase C3 closure evidence in `docs/plans/decision-log.md`
- Completed Phase C0 Zig language study artifacts:
  - refreshed `docs/guides/zig-patterns.md` for v1-scoped module-safe patterns
  - created `docs/guides/zig-anti-patterns.md` with footgun-safe replacements
  - created `docs/research/v1-zig-implementation-notes.md` with C1/C2/C3 translation notes,
    coding-agent review checklist, tradeoffs, and ambiguity checkpoint
  - recorded Phase C0 closure evidence in `docs/plans/decision-log.md`
- Completed additional NIP scope planning addendum:
  - created `docs/plans/v1-additional-nips-roadmap.md` with user-requested Group A/B/C
    classifications and H2/H3 wave sequencing
  - captured NIP-41 provisional comparison between PR `#829` (`41.md`, kinds 1776/1777) and PR
    `#1056` draft direction
- Completed Phase C4 implementation synthesis artifact:
  - created `docs/research/v1-implementation-decisions.md` with final module decision matrix,
    conflict resolutions, risk/mitigation register, and ambiguity checkpoint
  - recorded Phase C4 closure evidence in `docs/plans/decision-log.md`
- Completed Phase D contracts and vectors artifact:
  - created `docs/plans/v1-api-contracts.md` with implementation-ready module contracts,
    deterministic behavior rules, assertion pairs, and vector requirements
  - recorded Phase D closure evidence in `docs/plans/decision-log.md`
- Completed Phase E build-plan finalization artifact:
  - finalized `docs/plans/build-plan.md` as implementation-executable phase schedule aligned to
    v1 contracts and implementation decisions
  - recorded Phase E closure evidence in `docs/plans/decision-log.md`
- Completed Phase F implementation handoff artifact:
  - created `docs/plans/implementation-kickoff.md` with implementation-ready I0/I1 coding steps,
    exact file targets, verification cadence, tradeoffs, open questions, and stop conditions
  - recorded Phase F closure evidence in `docs/plans/decision-log.md`
- Completed Implementation Phase I0 gate pass:
  - `zig build test --summary all` pass
  - `zig build` pass

## Pending Actions

- Execute Implementation Phase I1 coding (`src/nip01_event.zig`, `src/nip01_filter.zig`) and enforce
  vector/error forcing gates.
- Implement I1 signature boundary on the resolved path: one in-repo thin Zig wrapper over pinned
  `bitcoin-core/secp256k1` BIP340/Schnorr backend, with no direct backend calls outside the boundary
  module.
- Enforce and verify I1 signature closure acceptance criteria: pinned backend revision, deterministic
  typed-error mapping, BIP340 vector suite + negative corpus, differential checks against pinned
  references, and no unbounded runtime allocation in signature paths.
- Add H2 NIP-06 build-vs-buy checkpoint artifact entry before any NIP-06 implementation start.
- Maintain verification cadence: run `zig build test --summary all` after each material change and
  `zig build` at slice closure.

## Key Decisions Made

- The first objective is a low-level library, not a high-level application framework.
- `applesauce` is a high-level reference only and should not drive core low-level design choices.
- Prompting workflow is phase-gated with one prompt per phase.
- `libnostr-z` parity is treated as a scope target, with staged v1 core/optional prioritization.
- Scope model is two-horizon: parity first, expansion second.
- Tradeoff logging is required for every material decision.
- Ambiguity checkpoint is required before phase closure.
- Zig language phase runs after external studies and before synthesis/contracts.
- Frozen defaults are canonical policy and require decision-log updates to change.
- `noztr` remains differentiated beyond primitive source choice: strict deterministic contracts,
  bounded memory/work, typed errors, and check-order invalid-corpus rigor remain core value even if a
  vetted crypto backend is used behind one boundary.

## Files Modified

- Created:
  - `docs/research/building-nostr-study.md`
  - `docs/research/nostr-protocol-study.md`
  - `docs/research/applesauce-study.md`
  - `docs/research/rust-nostr-study.md`
  - `docs/research/libnostr-z-study.md`
  - `docs/guides/zig-patterns.md`
  - `docs/plans/build-plan.md`
  - `docs/plans/nostr-principles.md`
  - `docs/plans/decision-log.md`
  - `docs/plans/v1-scope.md`
  - `docs/plans/v1-api-contracts.md`
  - `docs/research/v1-implementation-decisions.md`
  - `docs/plans/prompts/README.md`
  - `docs/plans/prompts/phase-0-philosophy-and-principles.md`
  - `docs/plans/prompts/phase-a-scope-freeze.md`
  - `docs/plans/prompts/phase-b-protocol-research.md`
  - `docs/plans/prompts/phase-c0-zig-language-study.md`
  - `docs/plans/prompts/phase-c1-applesauce-study.md`
  - `docs/plans/prompts/phase-c2-rust-nostr-study.md`
  - `docs/plans/prompts/phase-c3-libnostr-z-study.md`
  - `docs/plans/prompts/phase-c4-implementation-synthesis.md`
  - `docs/plans/prompts/phase-d-contracts-vectors.md`
  - `docs/plans/prompts/phase-e-build-plan.md`
  - `docs/plans/prompts/phase-f-implementation-handoff.md`
  - `handoff.md`
- Updated:
  - `AGENTS.md`
  - `agent-brief`
  - `CODEX-PROMPT.md`
  - `docs/plans/prompts/phase-0-philosophy-and-principles.md`
  - `docs/plans/prompts/phase-a-scope-freeze.md`
  - `docs/plans/prompts/phase-c1-applesauce-study.md`
  - `docs/plans/prompts/phase-c2-rust-nostr-study.md`
  - `docs/plans/prompts/phase-c3-libnostr-z-study.md`
  - `docs/plans/build-plan.md`
  - `docs/plans/decision-log.md`
  - `handoff.md`

## Next Steps To Continue

- Run `./agent-brief` and verify prompt artifact status.
- Continue Implementation Phase I1 using `docs/plans/implementation-kickoff.md`, including required
  `5 valid + 5 invalid` vector floors for `nip01_event` and `nip01_filter`.
- Continue implementation phases in build-plan order and close each slice only after gate commands pass.
- Keep `applesauce` as comparative context only when evaluating API ergonomics and developer UX.
