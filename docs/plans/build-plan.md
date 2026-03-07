# noztr Build Plan (Phase E Final)

Date: 2026-03-07

This artifact is finalized for implementation execution and is aligned to:

- `docs/plans/v1-scope.md`
- `docs/plans/v1-api-contracts.md`
- `docs/research/v1-implementation-decisions.md`
- frozen defaults `D-001`..`D-004` in `docs/plans/nostr-principles.md`

## Decisions

- `PE-001`: freeze implementation sequencing into executable phases with measurable completion gates.
- `PE-002`: keep strict-by-default behavior (`D-003`) as canonical in all core entry points; compatibility
  remains explicit opt-in and must not alter strict defaults.
- `PE-003`: require parity-core `nip11` in the core delivery schedule and gate closure criteria.
- `PE-004`: preserve extension-lane placeholders as documentation-only (`H2/H3` roadmap lanes) with no
  v1 scope expansion.
- `PE-005`: carry only low/medium impact accepted-risk items into Phase F; no high-impact ambiguity may
  remain `decision-needed` at Phase E close.
- `PE-006`: security hardening defaults are frozen for implementation: reduced secp module surface,
  commit-SHA pinning, typed backend outage boundaries, strict transcript/auth wrappers, normalized
  NIP-42 relay path binding, unbracketed IPv6 authority rejection, and strict PoW commitment
  truthfulness/floor policy.
- `PE-007`: maintain a dedicated security hardening register in
  `docs/plans/security-hardening-register.md` and treat it as the canonical status tracker for
  low/edge security follow-ups.

## Implementation Schedule

Note: these are implementation phases, not planning prompt phases.

### Phase I0 - Foundation and Shared Contracts

- Modules/files: `src/root.zig`, `src/limits.zig`, `src/errors.zig`, `build.zig` test wiring.
- Deliverables:
  - root export skeleton aligned to Phase D contract names.
  - shared limits and typed boundary error sets.
  - crypto boundary setup for I1 signatures on resolved default path:
    in-repo thin Zig wrapper over pinned `bitcoin-core/secp256k1` BIP340/Schnorr backend.
  - boundary rule captured: no direct backend calls outside one boundary module.
  - aggregate `zig build` and `zig build test --summary all` steps wired.
- Test/vector plan:
  - compile-time invariants for limits and relation checks.
  - smoke tests for root exports and typed error imports.
- Exit gate:
  - static library builds; tests pass with zero leaks.
  - no public catch-all errors; strict defaults documented in module headers.

### Phase I1 - Core Event and Filter Kernel

- Modules/files: `src/nip01_event.zig`, `src/nip01_filter.zig`.
- Deliverables:
  - deterministic event parse/serialize/verify split (`verify_id`, `verify_signature`, `verify`).
  - deterministic replace decision (`created_at`, lexical `id`).
  - typed verify outage distinction (`BackendUnavailable`) separated from cryptographic invalidity.
  - strict filter grammar and pure match semantics (`AND` within filter, `OR` across filters).
- Test/vector plan:
  - `nip01_event`: minimum `5 valid + 5 invalid`; include duplicate-key reject, invalid hex,
    invalid id/sig, max bounds, tie-break vectors.
  - `nip01_filter`: minimum `5 valid + 5 invalid`; include malformed `#x`, empty `#x` array reject,
    overflow paths,
    `since > until` reject, OR-of-filters behavior.
  - every public error variant has a forcing test.
- Exit gate:
  - canonical serialization and id computation deterministic across repeated runs.
  - strict parser rejects malformed/ambiguous critical fields.
  - signature closure satisfies all required acceptance criteria:
    - backend pinned by commit or tag.
    - boundary-only call graph (no direct backend calls elsewhere).
    - deterministic typed-error mapping for sign/verify/pubkey parse outcomes.
    - explicit backend outage mapped to typed boundary error (no generic verify failure).
    - BIP340 vector suite pass plus required negative corpus.
    - differential verification checks pass against pinned reference behavior.
    - no unbounded runtime allocation in signature paths.

### Phase I2 - Message Grammar, Auth/Protected, and Relay Info Core

- Modules/files: `src/nip01_message.zig`, `src/nip42_auth.zig`, `src/nip70_protected.zig`,
  `src/nip11.zig`.
- Deliverables:
  - typed client/relay union grammar with exact arity checks.
  - strict relay `OK` grammar requires lowercase-hex event id.
  - transcript state enforcement with explicit client marker
    (`transcript_mark_client_req`, `transcript_apply_relay`) and strict flow
    (`REQ -> EVENT* -> EOSE -> CLOSE`).
  - auth challenge validation and bounded authenticated-pubkey state.
  - challenge-set boundary typing distinguishes empty from too-long challenge input.
  - challenge rotation semantics: set-challenge clears authenticated pubkey set.
  - auth required-tag strictness: duplicate `relay`/`challenge` tags are rejected.
  - strict relay origin matching compares normalized scheme/host/port/path, ignores query/fragment,
    normalizes missing path to `/`, supports bracketed IPv6 authorities, and rejects unbracketed
    IPv6 authorities.
  - freshness policy: reject future auth timestamps and stale auth timestamps beyond window.
  - auth backend outage distinction typed separately from invalid signature.
  - protected-event gate with default deny unless auth context matches.
  - `nip11` partial-document parse with strict known-field typing, strict pubkey hex validation,
    and typed bounded caps.
- Test/vector plan:
  - `nip01_message`, `nip42_auth`, `nip70_protected`, `nip11`: each minimum `5 valid + 5 invalid`.
  - transcript forcing tests for invalid order and prefix mapping.
  - NIP-42 vectors include challenge rotation auth-set clear, duplicate required-tag reject, future
    timestamp reject, stale timestamp reject, typed empty-vs-too-long challenge-set failures,
    normalized-path match/mismatch (`/` default, query/fragment ignored), bracketed-IPv6
    origin match/mismatch, unbracketed-IPv6 reject, and backend outage mapping.
  - `nip11` vectors include unknown-field ignore, known-field type mismatch reject, invalid pubkey
    reject, and cap overflow typed errors.
- Exit gate:
  - all parity-core messaging and trust-boundary modules pass deterministic transcript and policy tests.
  - `nip11` included in pass criteria (cannot defer beyond this phase).

### Phase I3 - Core Lifecycle Policy Primitives

- Modules/files: `src/nip09_delete.zig`, `src/nip40_expire.zig`, `src/nip13_pow.zig`.
- Deliverables:
  - author-bound deletion rules for `e`/`a` targets.
  - checked delete extraction wrapper for relay-safe callers (`delete_extract_targets_checked`).
  - strict expiration parse and deterministic boundary helper.
  - deterministic PoW leading-zero and nonce-tag validation.
  - strict PoW commitment policy: `actual_bits >= commitment` and `commitment >= required_bits`
    when nonce commitment is present.
  - checked PoW verification wrapper (`pow_meets_difficulty_verified_id`) to couple id validity with
    difficulty checks.
- Test/vector plan:
  - each module minimum `5 valid + 5 invalid`.
  - boundary vectors: expiration equality second, delete cross-author reject,
    malformed nonce and difficulty range errors, commitment-below-required reject, and
    actual-below-commitment reject.
  - wrapper vectors: checked delete kind guard and checked PoW invalid-id reject.
- Exit gate:
  - pure helper behavior deterministic and side-effect free.
  - lifecycle error-path coverage includes all typed public errors.

### Phase I4 - Optional Identity and Relay Metadata Codecs

- Modules/files: `src/nip19_bech32.zig`, `src/nip21_uri.zig`, `src/nip02_contacts.zig`,
  `src/nip65_relays.zig`.
- Deliverables:
  - strict HRP/TLV codec behavior and URI parsing boundary.
  - strict kind-scoped extraction for contacts and relay lists.
- Test/vector plan:
  - each optional module minimum `3 valid + 3 invalid` (current accepted default).
  - required vectors include checksum/mixed-case/TLV failures, forbidden `nsec`, marker/url rejects.
  - non-interference tests ensure optional paths do not mutate core parser defaults.
- Exit gate:
  - optional modules pass minimum vector gate and keep core ABI/behavior stable.

### Phase I5 - Core Private Messaging Crypto and Wrap

- Modules/files: `src/nip44.zig`, `src/nip59_wrap.zig`.
- Deliverables:
  - stdlib-only NIP-44 v2 implementation with staged decrypt check order:
    `length -> version -> MAC -> decrypt -> padding`.
  - constant-time MAC compare and secret wipe helper usage.
  - staged NIP-59 unwrap (`wrap -> seal -> rumor`) with signature/sender checks.
- Test/vector plan:
  - `nip44`: official vectors plus invalid corpus; minimum `5 valid + 5 invalid` is floor,
    official corpus depth supersedes floor.
  - `nip59_wrap`: minimum `5 valid + 5 invalid`; include spoof and malformed layer failures.
  - deterministic fixed-nonce harness for encryption parity tests.
- Exit gate:
  - pinned NIP-44 vectors pass in full.
  - no runtime dynamic allocation in encrypt/decrypt/unwrap paths.

### Phase I6 - Optional Extension Message Lane (H1 Optional Only)

- Modules/files: `src/nip45_count.zig`, `src/nip50_search.zig`, `src/nip77_negentropy.zig`.
- Deliverables:
  - strict extension parsers and bounded state transitions.
  - explicit feature-gated integration points; no core default mutation.
- Test/vector plan:
  - each module minimum `3 valid + 3 invalid`.
  - `nip77` ordering/session overflow vectors are mandatory.
  - extension gate tests verify disabled-extension core behavior remains unchanged.
- Exit gate:
  - extension modules compile/test under feature gate.
  - disabling extensions keeps all core tests green.

### Phase I7 - Hardening, Conformance Sweep, and Release Candidate Handoff

- Modules/files: all implemented v1 modules.
- Deliverables:
  - full cross-module regression pass.
  - contract-to-implementation trace checklist for every public API.
  - implementation handoff package for Phase F kickoff.
- Test/vector plan:
  - rerun all module vectors and aggregate leak checks.
  - replay deterministic transcript and crypto check-order suites.
  - verify every public error variant still has direct forcing coverage.
- Exit gate:
  - `zig build test --summary all` pass with zero leaks.
  - `zig build` static library artifact produced.
  - implementation kickoff artifact inputs complete for Phase F.

## Per-Phase Build and Quality Gates

- Required for every phase closure:
  - `zig build test --summary all` passes.
  - `zig build` succeeds.
  - no unresolved high-impact ambiguity in `decision-needed` status.
  - TigerStyle constraints remain enforceable (function length, line width, assertion density,
    explicit errors, bounded control flow).

## Risks and Assumptions

- `R-E-001` crypto implementation correctness risk in `nip44` remains high-impact implementation risk;
  mitigated by pinned vectors, invalid corpus, deterministic nonce harness, and staged checks.
- `R-E-004` backend-boundary correctness risk on selected secp256k1/BIP340 path: boundary misuse or
  API leakage can break deterministic and typed-error contracts; mitigated by a single boundary
  module, pinned backend revision, and differential verification corpus.
- `R-E-005` secp hardening drift risk: broadened wrapper/call surface can reintroduce unsafe direct
  backend usage; mitigated by reduced boundary module exports and commit-SHA pinning in canonical
  records.
- `R-E-002` optional-lane drift risk remains medium; mitigated by explicit non-interference tests and
  extension gate checks.
- `R-E-003` bounded capacities may need empirical adjustment; mitigated by typed overflow errors and
  explicit reversal triggers in tradeoff register.
- `A-E-001` assumes Zig stdlib crypto surfaces used by contracts remain stable across implementation.
- `A-E-002` assumes parity source snapshots (`D-001`) remain sufficient for v1 execution window.
- `A-E-003` assumes the selected secp256k1 backend path can be pinned and wrapped without violating
  zero-unbounded-runtime-work and typed-error boundary requirements.
- `A-E-004` notes that H2 NIP-06 requires an explicit build-vs-buy checkpoint for BIP39/BIP32
  correctness and security burden before implementation starts.

## Edge-Case Audit Closure

- Status: edge-case audit is closed with no unresolved Medium+ findings.
- Security hardening register: `docs/plans/security-hardening-register.md`.
- Follow-up observations (low):
  - closed: normalized-path binding in NIP-42 relay origin matching (`/` default;
    query/fragment ignored).
  - closed: unbracketed IPv6 authority rejection in NIP-42 relay origin matching.
  - closed: canonical event runtime shape/UTF-8 validation guards.
  - closed: PoW commitment truthfulness/floor enforcement (`actual_bits >= commitment >=
    required_bits`).
  - open: LLM-first usability evaluation remains pending post-security checkpoint and before
    release-candidate API freeze.

## Unresolved Tradeoff Register

`UT-E-001`
- Topic: optional module vector depth beyond `3 valid + 3 invalid` baseline.
- Impact: medium.
- Status: accepted-risk.
- Default: keep baseline for v1; increase only when parity corpus shows drift.
- Mitigation: gate every optional module with required invalid-path vectors and non-interference tests.
- Reversal Trigger: optional parity regressions or repeated escaped defects.
- Owner: Phase F owner.

`UT-E-002`
- Topic: compatibility API physical placement (`co-located` vs `compat/` namespace).
- Impact: low.
- Status: accepted-risk.
- Default: strict APIs remain canonical; choose file layout in implementation kickoff without behavior
  change.
- Mitigation: enforce identical typed contracts and strict-default path tests regardless of placement.
- Reversal Trigger: measurable maintenance burden or accidental policy leakage.
- Owner: Phase F owner.

`UT-E-003`
- Topic: NIP-44 differential replay depth in CI beyond pinned corpus.
- Impact: medium.
- Status: accepted-risk.
- Default: ship with pinned official vectors first; add cross-language replay in hardening cycle if
  gap evidence appears.
- Mitigation: keep deterministic fixtures and add replay scaffold in Phase F kickoff checklist.
- Reversal Trigger: observed divergence against parity references in integration testing.
- Owner: Phase F owner.

`UT-E-004`
- Topic: differential hardening depth for the selected secp256k1/BIP340 boundary beyond I1 baseline.
- Impact: medium.
- Status: accepted-risk.
- Default: enforce I1 baseline acceptance criteria, then expand differential corpus only when parity or
  integration evidence shows remaining risk.
- Mitigation: keep required I1 acceptance criteria mandatory and schedule extra corpus depth in I7 when
  drift indicators appear.
- Reversal Trigger: observed divergence against pinned references or repeated boundary regressions.
- Owner: Phase I owner.

## Open Questions

- `OQ-E-001`: determine Phase F target threshold for optional vector expansion candidates
  (`nip77_negentropy`, `nip45_count`) based on first implementation corpus outcomes.
- `OQ-E-002`: decide final compatibility namespace placement in implementation kickoff without
  changing strict-default behavior.
- `OQ-E-003`: decide whether to promote NIP-44 cross-language differential replay from optional to
  required CI gate before first release candidate.
- `OQ-E-004`: what additional differential hardening depth beyond I1 baseline should become mandatory
  before first release candidate.
- `OQ-E-005`: for H2 NIP-06, what build-vs-buy threshold is required before selecting in-house
  BIP39/BIP32 implementation versus vetted helper/wrapper.
- `OQ-E-006`: keep LLM-first usability evaluation pending post-security checkpoint, before
  release-candidate API freeze.

## Ambiguity Checkpoint

`A-E-001`
- Topic: optional vector-depth escalation timing.
- Impact: medium.
- Status: accepted-risk.
- Default: keep baseline optional gate in implementation start; escalate on parity evidence.
- Owner: Phase F owner.

`A-E-002`
- Topic: compatibility API file placement.
- Impact: low.
- Status: accepted-risk.
- Default: placement decision deferred to kickoff artifact; strict behavior frozen.
- Owner: Phase F owner.

`A-E-003`
- Topic: NIP-44 cross-language differential replay in CI.
- Impact: medium.
- Status: accepted-risk.
- Default: required pinned corpus now; differential replay conditional on integration evidence.
- Owner: Phase F owner.

Ambiguity checkpoint result: high-impact `decision-needed` count = 0.

## Definition Of Done For Implementation Handoff

- Implementation schedule accepted as executable with no architecture clarification blockers.
- Every v1 module from `docs/plans/v1-api-contracts.md` is mapped to one implementation phase.
- Parity-core gates explicitly include `nip11` completion and tests.
- Strict-vs-compat policy is consistent with frozen default `D-003` (strict default, compat opt-in).
- Unresolved tradeoffs are recorded with status, mitigation, reversal trigger, and owner.
- Extension-lane placeholders remain documentation-only and do not add v1 module scope.
- No high-impact ambiguity remains `decision-needed`.

## Tradeoffs

## Tradeoff T-E-001: Front-load parity-core completion versus mixed core/optional sequencing

- Context: implementation can prioritize full parity-core closure first or interleave optional modules
  early for broader surface progress.
- Options:
  - O1: front-load parity-core and crypto core before optional lanes.
  - O2: interleave optional modules with core phases.
- Decision: O1.
- Benefits: earlier trust-boundary stability and lower risk of core contract drift.
- Costs: optional feature availability arrives later.
- Risks: perceived slower parity breadth.
- Mitigations: keep optional phases explicit and time-bounded with clear gates.
- Reversal Trigger: external integration requires optional module completion before core hardening.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: I1, I2, I3, I5 sequencing.

## Tradeoff T-E-002: Preserve optional vector baseline versus raising all optional modules now

- Context: optional modules currently use `3 valid + 3 invalid`; raising to core-level depth improves
  confidence but increases immediate delivery load.
- Options:
  - O1: keep baseline and escalate based on evidence.
  - O2: raise all optional modules to `5 valid + 5 invalid` immediately.
- Decision: O1.
- Benefits: predictable execution cadence and consistency with Phase D default.
- Costs: lower initial optional corpus depth.
- Risks: optional regressions may be detected later.
- Mitigations: enforce non-interference tests and targeted escalation triggers.
- Reversal Trigger: repeated optional parity defects.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: I4, I6 optional modules.

## Tradeoff T-E-003: Freeze strict/compat policy now versus defer policy reconciliation

- Context: prior artifacts contained stale strict-vs-compat uncertainty in build sequencing text.
- Options:
  - O1: freeze policy now to `D-003` and remove contradiction.
  - O2: defer strict/compat resolution into implementation phase.
- Decision: O1.
- Benefits: prevents default-behavior drift and reduces implementation ambiguity.
- Costs: less flexibility for permissive-default experiments.
- Risks: compatibility work may require extra adapter code.
- Mitigations: explicit compatibility entry points remain available and test-backed.
- Reversal Trigger: frozen default update accepted in decision log.
- Principles Impacted: P01, P03, P05.
- Scope Impacted: all parser/validator module boundaries.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: trust-boundary modules and crypto sequencing are front-loaded with explicit rejection gates.
- `P02`: module schedule remains protocol-kernel focused; extension-lane placeholders stay docs-only.
- `P03`: schedule and vector gates target behavior parity, not API shape mimicry.
- `P04`: relay/auth/protected behavior remains explicit in dedicated module phases.
- `P05`: deterministic behavior and staged-check ordering are phase-gated.
- `P06`: bounded memory/work and caller-buffer contracts remain mandatory in every phase.
