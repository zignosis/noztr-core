# Handoff

This handoff captures the current documentation status and immediate direction for the noztr project.

## Current Phase Status

- Planning prompt phase closure records are complete (`PF-E-001` in
  `docs/plans/decision-log.md`, high-impact decision-needed count 0).
- Active execution state is Phase F on the post-I7 baseline.
- Phase F kickoff tracking is active in `docs/plans/phase-f-kickoff.md`.
- Phase F risk burn-down started with first replay pass evidence in
  `docs/plans/phase-f-risk-burndown.md`.
- First replay delta run is executed with build-wired NIP-44 and secp parity commands;
  defaults remain unchanged.
- No frozen-default or strictness-policy changes are introduced by kickoff activation.
- Implementation status snapshot: I0-I7 are complete and validated on current protocol fixes.
- I4 optional modules are implemented with required non-interference coverage.
- I5 gates passed: staged `nip44` decrypt checks, staged `nip59` unwrap, and vector floors plus
  forcing coverage.
- I6 gate note: optional extension modules implemented, vector floors met, and extension tests pass
  with I6 enabled and disabled.
- I7 closure evidence pack is complete:
  - `docs/plans/i7-regression-evidence.md`
  - `docs/plans/i7-api-contract-trace-checklist.md`
  - `docs/plans/i7-phase-f-kickoff-handoff.md`
- I5 gate wording is aligned to implementation contract semantics (not a behavior relaxation):
  `nip44` documents no unbounded/runtime-heap allocation in encrypt/decrypt hot paths, and
  decrypt maps invalid UTF-8 plaintext after padding checks to typed `InvalidPadding`;
  `nip59_unwrap` documents caller-provided bounded scratch for strict inner event parsing,
  recipient private key material input for per-layer key derivation (`wrap.pubkey` then
  `seal.pubkey`), unsigned-rumor enforcement (reject rumor `sig`), and sender continuity checks.
- I6 contract wording is aligned to implementation: `nip77_negentropy` includes strict
  `negentropy_close_parse`/`negentropy_err_parse` APIs for `NEG-CLOSE`/`NEG-ERR` with typed
  `InvalidNegErr` failure mapping.
- Additional contract sync deltas are aligned to implementation: NIP-44 padded-length helper returns
  `u32` with `32..65536` padded bounds semantics; parser `OutOfMemory` variants are explicit where
  implemented (`nip01_event`, `nip01_filter`, `nip11`, `nip59_wrap`); strict kind boundary remains
  `kind <= 65535`; NIP-50 ignores unsupported multi-colon tokens while rejecting malformed supported
  tokens; NIP-09 coordinate matching rejects duplicate `d` tags.
- Overengineering/correctness mitigation pass is recorded in active planning docs:
  - canonical trust-boundary path wording is clarified for strict checked entry points,
  - message parse error contract now reflects implemented `InvalidFilter` and `InvalidEvent`,
  - transcript naming cleanup is documented: `transcript_apply_compat` is alias-only wording and
    canonical strict flow remains `transcript_mark_client_req` + `transcript_apply_relay`,
  - strict filter semantics are documented as deterministic lowercase prefix matching for
    `ids`/`authors` (`1..64`) with lowercase-only `#x` keys and typed `TooManyTagKeys` overflow.
  - PoW trust-boundary docs now pin `pow_meets_difficulty` as safe-by-default compatibility behavior
    (`invalid id -> false`), keep `pow_meets_difficulty_verified_id` as the canonical strict path,
    and treat unchecked helper behavior as internal-only.
  - delete checked extractor contract now matches implementation typing
    (`DeleteExtractCheckedError`, including `BufferTooSmall`).
- Next execution target: Phase F kickoff actions on the I7 closure baseline.
- Layer 2 compatibility/ergonomic adapter work remains deferred pending Layer 1 execution and
  `OQ-E-006` closure.

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
- Completed Implementation Phases I1-I3 gate pass:
  - core event/filter kernel, message/auth/protected/`nip11`, and lifecycle policy primitives are
    implemented and validated.
  - recent protocol hardening fixes are integrated (strict transcript terminal `CLOSED` semantics,
    strict `OK` lowercase-hex id parsing, strict filter-empty `#x` rejection, strict PoW
    commitment truthfulness/floor policy).
- Completed security hardening sprint (post-I1 boundary and semantics pass):
  - updated strict verify/auth error contracts to type backend outage separately.
  - finalized NIP-42 hardening semantics: challenge rotation clears auth set, duplicate required tags
    reject as `DuplicateRequiredTag`, and freshness uses bounded symmetric skew (within-window
    future/stale accepted; beyond-window future rejects `FutureTimestamp`; beyond-window stale rejects
    `StaleTimestamp`).
  - hardened challenge setter boundary to return distinct `ChallengeEmpty` and `ChallengeTooLong`
    failures.
  - hardened `auth_validate_event` boundary to reject empty and oversized `expected_challenge`
    inputs.
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
  - strict filter parsing now enforces lowercase-only `#x` keys, rejects empty `#x` value arrays,
    and uses deterministic lowercase hex-prefix matching (`1..64`) for `ids`/`authors`.
  - edge-case audit now has no unresolved Medium+ findings.
  - low hardening follow-up status:
    - normalized-path binding in NIP-42 relay origin matching (`/` default;
      query/fragment ignored).
    - unbracketed IPv6 authority rejection in NIP-42 relay matching.
    - canonical event runtime shape/UTF-8 validation guards.
    - PoW commitment truthfulness/floor enforcement (`actual_bits >= commitment >= required_bits`).
    - closed: `event_compute_id` invalid runtime shape now fails with typed error instead of
      all-zero compatibility fallback.
- Added dedicated security hardening tracker:
  - created `docs/plans/security-hardening-register.md`.
  - linked register from `docs/plans/build-plan.md` and `docs/plans/decision-log.md`.
- Started LLM-first usability pass (`OQ-E-006`):
  - created `docs/plans/llm-usability-pass.md` with scope snapshot, task battery, rubric,
    initial findings/recommendations, and closure criteria.
  - usability scope now includes implemented I4 modules and transcript naming cleanup context
    (`transcript_apply_compat` alias wording with canonical strict path
    `transcript_mark_client_req` + `transcript_apply_relay`).
  - updated planning artifacts to mark usability sequencing as in-progress (`D-014`).
- Recorded current Tiger hard-rule cleanliness baseline for `src/`:
  - `>100`-column lines: none.
  - `>70`-line functions: none.
  - strict-width and anti-pattern cleanup remain quality follow-up where applicable.
- Recorded strict Layer 1 defaults and Layer 2 evaluation scope in planning artifacts:
  - Layer 1 defaults: lowercase-only critical hex, unknown filter-field rejection,
    strict relay `OK` rejection status-prefix validation, and strict NIP-42 path-bound `ws`/`wss`
    origin.
  - Layer 2 scope (via `OQ-E-006`): compatibility/ergonomic adapter behavior, not kernel default
    relaxation.
- Added dedicated project style profile and planning links:
  - created `docs/guides/NOZTR_STYLE.md` with strict kernel defaults, compatibility stance,
    canonical trust-boundary entry-point policy, and LLM strictness-evaluation loop.
  - linked style profile from active planning artifacts (`docs/plans/build-plan.md`,
    `docs/plans/decision-log.md`) and handoff context.
- Added explicit two-layer architecture intent in planning records:
  - Layer 1: strict deterministic protocol kernel.
  - Layer 2: explicit compatibility/ergonomic SDK adapter lane.
  - evaluation process: tradeoff + vectors + usability evidence before adapter defaults freeze.

## Pending Actions

- Start Phase F kickoff actions from the I7 closure baseline and keep build-plan ordering intact.
- Execute Phase F kickoff worklist from `docs/plans/phase-f-kickoff.md` and keep defaults unchanged.
- Keep the secp boundary narrowed to approved exports only; preserve commit-SHA pinning policy when
  updating backend references.
- Keep PoW trust-boundary docs explicit: `pow_meets_difficulty` stays compatibility-only and strict
  callers use `pow_meets_difficulty_verified_id`; compatibility path is safe-by-default
  (`invalid id -> false`) and unchecked helper behavior remains internal-only.
- Maintain `docs/plans/security-hardening-register.md` as the canonical hardening status ledger.
- Keep LLM-first usability evaluation in progress and close `OQ-E-006` via
  `docs/plans/llm-usability-pass.md` before first RC API freeze.
- Use `OQ-E-006` outcomes to freeze first RC Layer 2 compatibility adapter defaults while preserving
  frozen Layer 1 strict defaults.
- Keep `docs/guides/NOZTR_STYLE.md` synchronized with accepted strictness-profile defaults and
  trust-boundary wrapper policy updates.
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
- Strategic architecture is explicitly two-layer: strict protocol kernel first, compatibility/ergonomic
  adapter second, with defaults and exceptions captured through decision-log records.

## Files Modified

- Created:
  - `docs/research/building-nostr-study.md`
  - `docs/research/nostr-protocol-study.md`
  - `docs/research/applesauce-study.md`
  - `docs/research/rust-nostr-study.md`
  - `docs/research/libnostr-z-study.md`
  - `docs/guides/zig-patterns.md`
  - `docs/guides/NOZTR_STYLE.md`
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
  - `docs/plans/llm-usability-pass.md`
  - `docs/plans/phase-f-kickoff.md`
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
  - `docs/plans/v1-api-contracts.md`
  - `docs/plans/security-hardening-register.md`
  - `handoff.md`

## Next Steps To Continue

- Run `./agent-brief` and verify prompt artifact status.
- Execute Phase F kickoff tasks using `docs/plans/i7-phase-f-kickoff-handoff.md` and
  `docs/plans/build-plan.md`.
- Continue implementation phases in build-plan order and close each slice only after gate commands pass.
- Keep Layer 2 compatibility/ergonomic adapter work deferred until `OQ-E-006` is closed.
- Keep `applesauce` as comparative context only when evaluating API ergonomics and developer UX.
