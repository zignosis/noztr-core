# Handoff

This handoff captures the current documentation status and immediate direction for the noztr project.

## Current Phase Status

- Phase F: closed.
- Closure basis: implementation kickoff artifact finalized (`docs/plans/implementation-kickoff.md`) and
  closure evidence recorded in `docs/plans/decision-log.md` (`PF-E-001`) with high-impact
  decision-needed count 0.
- Next phase target: Implementation Phase I2 continuation on hardened API surface.

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
- Completed security hardening sprint (post-I1 boundary and semantics pass):
  - updated strict verify/auth error contracts to type backend outage separately.
  - finalized NIP-42 hardening semantics: challenge rotation clears auth set, duplicate required tags
    reject as `DuplicateRequiredTag`, and freshness rejects future/stale timestamps beyond window.
  - hardened challenge setter boundary to return distinct `ChallengeEmpty` and `ChallengeTooLong`
    failures.
  - finalized strict NIP-42 relay origin matching to bind normalized path in addition to
    scheme/host/port (`?query`/`#fragment` ignored; missing path normalized to `/`).
  - finalized strict NIP-42 relay authority parsing to reject unbracketed IPv6 authorities and accept
    bracketed IPv6 authorities.
  - finalized strict PoW commitment policy to enforce commitment truthfulness and floor
    (`actual_bits >= commitment >= required_bits`).
  - froze safe wrapper APIs: `pow_meets_difficulty_verified_id`,
    `delete_extract_targets_checked`, `transcript_mark_client_req`,
    `transcript_apply_relay`.
  - hardened `nip11` contract with strict pubkey validation and typed bounded-cap errors.
  - recorded secp boundary hardening defaults: reduced module surface and commit-SHA pinning.
- Completed low-hardening and edge-audit closure updates:
  - strict relay `OK` message parsing now requires lowercase hex event ids.
  - strict filter parsing now rejects empty `#x` value arrays.
  - edge-case audit now has no unresolved Medium+ findings.
  - remaining low hardening findings are closed:
    - normalized-path binding in NIP-42 relay origin matching (`/` default;
      query/fragment ignored).
    - unbracketed IPv6 authority rejection in NIP-42 relay matching.
    - canonical event runtime shape/UTF-8 validation guards.
    - PoW commitment truthfulness/floor enforcement (`actual_bits >= commitment >= required_bits`).
- Added dedicated security hardening tracker:
  - created `docs/plans/security-hardening-register.md`.
  - linked register from `docs/plans/build-plan.md` and `docs/plans/decision-log.md`.
  - left LLM-first usability sequencing (`OQ-E-006`) open per post-security policy (`D-009`).

## Pending Actions

- Continue implementation in build-plan order from I2 onward on the hardened API contract baseline.
- Keep the secp boundary narrowed to approved exports only; preserve commit-SHA pinning policy when
  updating backend references.
- Maintain `docs/plans/security-hardening-register.md` as the canonical hardening status ledger.
- Keep LLM-first usability evaluation pending post-security checkpoint and before first RC API freeze.
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
  - `docs/plans/security-hardening-register.md`
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
- Continue Implementation Phase I2 using `docs/plans/implementation-kickoff.md`, including required
  `5 valid + 5 invalid` vector floors for `nip01_message`, `nip42_auth`, `nip70_protected`, and
  `nip11`.
- Continue implementation phases in build-plan order and close each slice only after gate commands pass.
- Keep `applesauce` as comparative context only when evaluating API ergonomics and developer UX.
