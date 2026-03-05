# v1 Scope Freeze (Phase A)

Date: 2026-03-05

## Decisions

- `A-001`: product target is frozen as a low-level Zig Nostr protocol library with stdlib-only
  dependencies, bounded memory/work, and behavior parity goals (not API-shape parity).
- `A-002`: frozen defaults `D-001`..`D-004` are applied with no changes in Phase A.
- `A-003`: horizon model is frozen:
  - `H1`: protocol support parity with `libnostr-z` for core and optional parity channels.
  - `H2`: expansion to additional stable NIPs after H1 parity surfaces are complete.
- `A-004`: all in-scope planning NIPs are classified into one of `parity-core`,
  `parity-optional`, `expansion-candidate`, `defer`, or `rejected`.
- `A-005`: v1 non-goals are frozen to avoid expanding into app frameworks, relay policy engines,
  or deprecated-by-default compatibility paths.

## Feature Matrix

| NIP | Horizon | Classification | Rationale |
| --- | --- | --- | --- |
| 01 | H1 | parity-core | NIP-01 is the mandatory wire/event foundation and is required by every later phase. |
| 02 | H1 | parity-optional | Contact-list relay hints are useful for routing but are not blocking for core parse/verify correctness. |
| 04 | H2 | defer | NIP-04 is a deprecated legacy DM path and is explicitly scoped as compatibility-only after modern messaging. |
| 05 | H2 | defer | NIP-05 introduces network identity resolution concerns that are not required for v1 protocol-kernel closure. |
| 09 | H1 | parity-core | Delete semantics are core lifecycle policy primitives required for deterministic event handling. |
| 11 | H1 | parity-core | Relay information documents are baseline capability discovery needed for feature negotiation. |
| 12 | H1 | parity-core | NIP-12 behavior is moved into NIP-01 and must ship with the core event model. |
| 13 | H1 | parity-core | PoW difficulty primitives are part of baseline anti-spam validation hooks in the build plan. |
| 16 | H1 | parity-core | NIP-16 semantics are moved into NIP-01 and required for replaceable event correctness. |
| 17 | H2 | defer | NIP-17 full chat conventions are intentionally sequenced after NIP-44 and NIP-59 stabilization. |
| 19 | H1 | parity-optional | Bech32 identity/reference codecs are important interoperability utilities but not v1 kernel prerequisites. |
| 20 | H1 | parity-core | NIP-20 command-result semantics are moved into message baseline behavior and needed for relay interop. |
| 21 | H1 | parity-optional | `nostr:` URI parsing is an ecosystem codec surface that can stay optional without harming core integrity. |
| 33 | H1 | parity-core | NIP-33 addressable event semantics are moved into NIP-01 canonical behavior and cannot be split out. |
| 40 | H1 | parity-core | Expiration filtering is a core lifecycle policy primitive with deterministic boundary behavior. |
| 42 | H1 | parity-core | AUTH challenge handling is a core trust-boundary requirement and prerequisite for protected events. |
| 44 | H1 | parity-core | NIP-44 v2 cryptography is the mandatory modern private-transport primitive for v1. |
| 45 | H1 | parity-optional | COUNT query extension is valuable parity surface but does not alter core event correctness contracts. |
| 50 | H1 | parity-optional | Search extension is relay-specific and intentionally optional to keep deterministic core behavior narrow. |
| 59 | H1 | parity-core | Gift-wrap/seal baseline unwrap behavior is required to make NIP-44 practical in protocol workflows. |
| 65 | H1 | parity-optional | Relay list metadata improves routing quality but is optional relative to core parse/verify semantics. |
| 70 | H1 | parity-core | Protected-event enforcement is a required access-control rule linked to NIP-42 session state. |
| 77 | H1 | parity-optional | Negentropy channel support is an extension capability and is intentionally isolated from core contracts. |

## v1 Non-Goals

- No high-level application framework abstractions, reactive state stores, or UI lifecycle integration
  in core protocol modules.
- No relay policy engine beyond deterministic protocol primitives and validators.
- No default enablement of deprecated NIP-04 messaging paths.
- No full NIP-17 outbound orchestration/fan-out workflows in v1 core.
- No external dependencies, C wrappers, OpenSSL linkage, or post-init unbounded allocations.

## Ambiguity Checkpoint

`A-A-001`
- Topic: classification of NIP-70 as parity-core versus parity-optional.
- Impact: high.
- Status: resolved.
- Resolution: NIP-70 is parity-core because protected-event acceptance is a trust-boundary rule.
- Owner: active phase owner.

`A-A-002`
- Topic: inclusion of NIP-05 in H1 versus H2.
- Impact: medium.
- Status: resolved.
- Resolution: NIP-05 is deferred to H2 to keep v1 focused on protocol-kernel behavior.
- Owner: active phase owner.

`A-A-003`
- Topic: legacy NIP-04 compatibility depth in v1.
- Impact: medium.
- Status: resolved.
- Resolution: NIP-04 is deferred to H2 and treated as compatibility-only, not default messaging.
- Owner: active phase owner.

## Tradeoffs

## Tradeoff T-A-001: Include NIP-70 in H1 core scope

- Context: NIP-70 protected-event handling can be treated as optional policy or core trust behavior.
- Options:
  - O1: classify NIP-70 as parity-core in H1.
  - O2: classify NIP-70 as parity-optional in H1.
- Decision: O1.
- Benefits: preserves explicit trust-boundary semantics and aligns AUTH-protected behavior with P01.
- Costs: additional state-machine and test complexity in H1.
- Risks: stricter enforcement may reject events accepted by permissive ecosystems.
- Mitigations: keep error mapping explicit and add relay transcript vectors for allowed/denied paths.
- Reversal Trigger: evidence that most parity targets treat NIP-70 as non-essential optional metadata.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: NIP-42, NIP-70, Phase 2 message/auth modules.

## Tradeoff T-A-002: Defer NIP-04 while prioritizing NIP-44 and NIP-59

- Context: v1 cannot maximize both modern private transport and deprecated compatibility depth.
- Options:
  - O1: prioritize NIP-44 and NIP-59; defer NIP-04.
  - O2: include NIP-04 in H1 alongside NIP-44 and NIP-59.
- Decision: O1.
- Benefits: concentrates validation effort on current cryptographic pathways and reduces attack surface.
- Costs: legacy DM interop is postponed.
- Risks: some migrations may require temporary adapter logic outside core.
- Mitigations: document NIP-04 as H2 compatibility scope and keep interfaces ready for add-on module.
- Reversal Trigger: blocker interoperability requirement where NIP-04 is mandatory for target adopters.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: NIP-04, NIP-44, NIP-59, v1 private messaging boundary.

## Tradeoff T-A-003: Keep extension channels parity-optional in H1

- Context: NIP-45, NIP-50, and NIP-77 increase interop coverage but are extension surfaces.
- Options:
  - O1: classify 45/50/77 as parity-optional in H1.
  - O2: classify 45/50/77 as parity-core in H1.
  - O3: defer 45/50/77 to H2.
- Decision: O1.
- Benefits: retains parity trajectory while protecting core delivery schedule and API stability.
- Costs: two-tier validation profile (`core-mandatory` and `extensions-optional`) must be maintained.
- Risks: optional profile drift if extension tests are under-maintained.
- Mitigations: maintain explicit feature matrix and enforce extension vectors in dedicated test classes.
- Reversal Trigger: repeated extension regressions or maintenance overhead beyond parity value.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: NIP-45, NIP-50, NIP-77, Phase 6 extension modules.

## Tradeoff T-A-004: Defer network identity resolution (NIP-05) from v1 core

- Context: NIP-05 requires remote fetch and trust-policy handling that can broaden core scope.
- Options:
  - O1: defer NIP-05 to H2.
  - O2: include NIP-05 as parity-optional in H1.
- Decision: O1.
- Benefits: keeps v1 focused on deterministic protocol primitives and bounded local verification.
- Costs: identity resolution convenience is not in first release scope.
- Risks: consumers may implement inconsistent ad-hoc NIP-05 logic externally.
- Mitigations: specify a strict no-redirect validation contract for planned H2 implementation.
- Reversal Trigger: v1 adoption blocked by inability to verify NIP-05 identities in core library.
- Principles Impacted: P02, P03, P06.
- Scope Impacted: NIP-05 and identity/routing roadmap boundaries.

## Open Questions

- `OQ-A-001`: determine by end of Phase B whether H1 parity-optional NIPs need hard minimum vector
  counts in phase gates to prevent optional-profile drift.
- `OQ-A-002`: decide in Phase B whether NIP-77 should remain framing-only in early implementation
  phases or include full negentropy algorithm in first extension milestone.

## Principles Compliance

- Required sections are present: `Decisions`, `Tradeoffs`, `Open Questions`,
  `Principles Compliance`.
- Scope freeze preserves cryptographic trust boundaries and invalid-signature rejection (`P01`) via
  parity-core classification of NIP-42/NIP-44/NIP-59/NIP-70.
- Scope remains protocol-kernel and transport-agnostic (`P02`) by deferring framework patterns and
  network-identity resolution from v1 core.
- Interop convergence is prioritized over API mimicry (`P03`) through H1 behavior-parity focus and
  explicit parity-core/parity-optional classes.
- Relay/access behavior is explicit and auditable (`P04`) through fixed inclusion of NIP-11/NIP-42
  and optional extension isolation.
- Deterministic parse/serialize/verify paths are preserved (`P05`) by keeping moved NIPs
  (12/16/20/33) inside NIP-01 core behavior.
- Bounded memory/work constraints are preserved (`P06`) by rejecting dependency-heavy or unbounded
  expansion in v1 non-goals.
- Ambiguity checkpoint result: no high-impact ambiguities remain in `decision-needed` status.
