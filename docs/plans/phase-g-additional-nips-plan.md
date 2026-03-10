# Phase G Additional NIPs Plan

Date: 2026-03-10

Purpose: classify and sequence the requested additional NIPs for Phase G planning without changing
frozen defaults or current strict kernel behavior.

## Decisions

- `G-ANIP-001`: this plan covers only NIPs `03`, `06`, `07`, `10`, `17`, `18`, `22`, `23`, `24`,
  `25`, `27`, `29`, `39`, `46`, `51`.
- `G-ANIP-002`: frozen defaults remain unchanged (`D-001`..`D-004`); strict-by-default behavior
  remains canonical.
- `G-ANIP-003`: expansion work is limited to bounded protocol-kernel additions and explicit
  trust-boundary contracts.
- `G-ANIP-004`: app-runtime/platform integration surfaces remain out-of-scope for core library scope.

## Decision Framing And Constraints

- No external dependencies; stdlib-only policy remains in force.
- No policy drift from current strict defaults, typed errors, and bounded-memory requirements.
- Behavior parity remains the target, not API-shape parity.
- Sequencing favors lower-ambiguity protocol primitives before high-ambiguity trust/policy surfaces.

## NIP Classification Matrix

| NIP | Classification | Rationale |
| --- | --- | --- |
| 03 | defer | OpenTimestamps verification is useful but needs tighter bounded-proof validation scope before implementation. |
| 06 | expansion-candidate | High-value key-derivation primitive, but requires explicit BIP39/BIP32 strategy and strict boundary contracts. |
| 07 | rejected | Browser `window.nostr` capability is runtime/platform integration, outside protocol-kernel scope. |
| 10 | expansion-candidate | Thread/reply conventions map to deterministic tag validation helpers with bounded parsing. |
| 17 | defer | Private DM conventions add orchestration and policy complexity beyond current NIP-44/NIP-59 kernel baseline. |
| 18 | expansion-candidate | Repost semantics are common and fit strict event/tag validation helpers. |
| 22 | expansion-candidate | Comment semantics can be represented as explicit bounded event linkage validation. |
| 23 | expansion-candidate | Long-form metadata is implementable with strict field and tag validation bounds. |
| 24 | defer | Extra metadata/tag conventions are lower priority and can follow higher-interoperability items. |
| 25 | expansion-candidate | Reaction semantics are high-interop and fit deterministic event/tag checks. |
| 27 | expansion-candidate | Text note reference parsing is protocol-adjacent and bounded by strict token/shape checks. |
| 29 | defer | Relay-based groups introduce state/policy complexity that exceeds current maintenance-phase expansion scope. |
| 39 | defer | External identity claims expand trust-policy surface and need explicit verification-policy decisions first. |
| 46 | expansion-candidate | Nostr Connect is strategically important and can be modeled via explicit message/verification boundaries. |
| 51 | expansion-candidate | Lists are common interoperability primitives with deterministic event encoding/validation expectations. |

## Proposed Implementation Waves

- Wave 0 (required checkpoint): NIP-06 build-vs-buy and acceptance-criteria freeze before coding.
- Wave 1 (high-value low-ambiguity): `10`, `18`, `22`, `25`, `27`, `51`.
- Wave 2 (higher-complexity expansion): `46`.
- Wave 3 (security-sensitive expansion after checkpoint): `06`.
- Deferred backlog (no implementation start in this plan): `03`, `17`, `24`, `29`, `39`.
- Rejected hold: `07`.

## Per-Wave Exit Gates

- Tests
  - Minimum vector floor per new module/API surface: valid + invalid corpus with typed error forcing.
  - Determinism checks for parse/serialize/validation behavior on repeated inputs.
  - Non-interference checks proving unchanged strict defaults in existing core modules.
- Parity evidence
  - Comparative behavior notes against pinned parity references for every implemented wave item.
  - Explicit mismatch ledger entries if ecosystem behavior diverges from strict defaults.
- Documentation evidence
  - Update contracts/build-plan references for accepted wave outputs.
  - Record any default-affecting choice in `docs/plans/decision-log.md` before adoption.

## Tradeoffs

## Tradeoff T-G-ANIP-001: Sequence low-ambiguity interop helpers before identity/signing surfaces

- Context: requested NIPs include both simple event/tag semantics and higher-risk signing/identity work.
- Options:
  - O1: implement all expansion-candidates in request order.
  - O2: sequence lower-ambiguity semantics first, then higher-risk signing/identity items.
- Decision: O2.
- Benefits: faster stable coverage, lower trust-boundary risk early.
- Costs: delayed delivery for complex high-priority items.
- Risks: perceived imbalance in roadmap urgency.
- Mitigations: keep explicit Wave 0/2/3 checkpoints and rationale.
- Reversal Trigger: parity evidence shows delayed items are blocking critical interoperability.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: NIPs `06`, `10`, `18`, `22`, `23`, `25`, `27`, `46`, `51`.

## Open Questions And Risks

- `OQ-G-ANIP-001` (NIP-06, high): should BIP39/BIP32 be implemented in-house or via a vetted,
  bounded boundary approach under zero-dependency policy constraints.
- `OQ-G-ANIP-002` (NIP-17, medium): which subset (decode/verify-only vs broader workflow helpers)
  can be added without introducing orchestration semantics into Layer 1.
- `OQ-G-ANIP-003` (NIP-29, high): what fixed-capacity state model is acceptable for relay-group
  semantics without unbounded or policy-coupled behavior.
- `OQ-G-ANIP-004` (NIP-39, high): what trust model and verification policy are acceptable for
  external identity claims under strict defaults.
- `OQ-G-ANIP-005` (NIP-03, medium): what bounded proof-shape and verification-depth floor is required
  for deterministic OpenTimestamps validation.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: cryptographic and trust-boundary-heavy items (`03`, `06`, `39`, `46`) are gated with
  explicit risk framing.
- `P02`: platform/runtime integration (`07`) remains rejected to preserve protocol-kernel boundaries.
- `P03`: sequencing prioritizes interoperability primitives and behavior parity evidence.
- `P04`: relay/group and connection semantics (`29`, `46`) remain explicit policy surfaces.
- `P05`: deterministic parse/validation and typed-error forcing are required in wave exits.
- `P06`: bounded memory/work and strict defaults remain unchanged across all classifications.
