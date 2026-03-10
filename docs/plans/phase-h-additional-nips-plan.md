# Phase H Additional NIPs Plan

Date: 2026-03-10

Purpose: classify and sequence the requested additional NIPs for Phase H planning without changing
frozen defaults or the current deterministic-and-compatible Layer 1 kernel posture.

## Decisions

- `H-ANIP-001`: this plan covers only NIPs `03`, `06`, `07`, `10`, `17`, `18`, `22`, `23`, `24`,
  `25`, `27`, `29`, `39`, `46`, `51`.
- `H-ANIP-002`: frozen defaults remain unchanged; `D-036` deterministic-and-compatible Layer 1
  posture remains canonical.
- `H-ANIP-003`: expansion work is limited to bounded protocol-kernel additions and explicit
  trust-boundary contracts.
- `H-ANIP-004`: app-runtime/platform integration surfaces remain out-of-scope for core library scope.
- `H-ANIP-005`: NIP-06 uses the vetted `libwally-core` path under the approved pinned crypto backend
  policy rather than an in-house BIP39/BIP32 implementation.
- `H-ANIP-006`: Phase H NIP-06 scope is limited to the minimum fully functional Nostr key-derivation
  boundary: mnemonic validation, mnemonic plus optional passphrase to seed, BIP32 master-key
  creation, and derivation of Nostr keys at `m/44'/1237'/<account>'/0/0`.
- `H-ANIP-007`: NIP-06 acceptance requires strict zeroization for sensitive temporary material and
  typed errors for every public boundary failure; parity and edge-case follow-up beyond the initial
  boundary remains a later-phase expansion lane.

## Decision Framing And Constraints

- No unapproved dependencies; stdlib-first policy remains in force and approved pinned crypto backend
  exceptions require a decision-log entry.
- No policy drift from current Layer 1 posture, typed errors, and bounded-memory requirements.
- Behavior parity remains the target, not API-shape parity.
- Sequencing favors lower-ambiguity protocol primitives before high-ambiguity trust/policy surfaces.

## NIP Classification Matrix

| NIP | Classification | Rationale |
| --- | --- | --- |
| 03 | defer | OpenTimestamps verification is useful but needs tighter bounded-proof validation scope before implementation. |
| 06 | h0-complete | Phase H0 is now complete: the `libwally-core` pin target, one-module boundary, typed error posture, and vector corpus floor are frozen for later implementation. |
| 07 | rejected | Browser `window.nostr` capability is runtime/platform integration, outside protocol-kernel scope. |
| 10 | wave-1-complete | Strict kind-1 thread/reply helpers are now implemented with marked-tag parsing, positional fallback, typed malformed-tag failures, legacy `mention` compatibility handling, and accepted four-slot pubkey fallback. |
| 17 | defer | Private DM conventions add orchestration and policy complexity beyond current NIP-44/NIP-59 kernel baseline. |
| 18 | wave-1-complete | Strict repost parsing/helpers are now implemented with deterministic embedded-event consistency checks across `e`, `p`, `k`, and `a` data. |
| 22 | wave-1-complete | Strict comment root/parent linkage helpers are now implemented with mandatory `K/k`, author linkage, and NIP-73-consistent external validation. |
| 23 | expansion-candidate | Long-form metadata is implementable with strict field and tag validation bounds. |
| 24 | defer | Extra metadata/tag conventions are lower priority and can follow higher-interoperability items. |
| 25 | wave-1-complete | Native kind-7 reaction parsing/helpers are now implemented with strict last-target semantics, typed malformed-tag failures, and strict custom-emoji validation; kind-17 external reactions remain deferred with NIP-73. |
| 27 | wave-1-complete | Strict inline `nostr:` reference extraction is now implemented with stable spans, decoded NIP-21 entities, and malformed-fragment fallback. |
| 29 | defer | Relay-based groups introduce state/policy complexity that exceeds current maintenance-phase expansion scope. |
| 39 | defer | External identity claims expand trust-policy surface and need explicit verification-policy decisions first. |
| 46 | expansion-candidate | Nostr Connect is strategically important and can be modeled via explicit message/verification boundaries. |
| 51 | wave-1-complete | Strict public-list extraction for the common rust-backed NIP-51 kinds is implemented with explicit set metadata handling, coordinate-kind validation, bounded broader bookmark/emoji emission helpers, and deferred private/extraction-widening follow-up in `no-e7b`. |

## Proposed Implementation Waves

- Wave 0 (required checkpoint): NIP-06 `libwally-core` pin, boundary contract, and acceptance-criteria
  freeze before coding. Status: complete.
- Wave 1 (high-value low-ambiguity): `25`, `10`, `18`, `22`, `27`, `51`.
- Wave 2 (higher-complexity expansion): `46`.
- Wave 3 (security-sensitive expansion after checkpoint): `06`.
- Deferred backlog (no implementation start in this plan): `03`, `17`, `24`, `29`, `39`.
- Rejected hold: `07`.

## Per-Wave Exit Gates

- Tests
  - Minimum vector floor per new module/API surface: valid + invalid corpus with typed error forcing.
  - Determinism checks for parse/serialize/validation behavior on repeated inputs.
  - Non-interference checks proving unchanged Layer 1 defaults in existing core modules.
- Parity evidence
  - Comparative behavior notes against pinned parity references for every implemented wave item.
  - Explicit mismatch ledger entries if ecosystem behavior diverges from current Layer 1 defaults.
  - Documentation evidence
  - Update contracts/build-plan references for accepted wave outputs.
  - Record any default-affecting choice in `docs/plans/decision-log.md` before adoption.

## Wave 1 Status Snapshot

- Complete:
  - `51`
    - implemented scope: strict public-list extraction for the common rust-backed NIP-51 kinds plus
      bounded bookmark/emoji tag builders in `src/nip51_lists.zig`
    - accepted semantics:
      - supported strict kinds are `10000`, `10001`, `10003`, `10004`, `10005`, `10006`, `10007`,
        `10015`, `10030`, `30000`, `30002`, `30003`, `30004`, `30015`, `30030`
      - set kinds require exactly one non-empty `d` identifier and may carry one each of `title`,
        `image`, and `description`
      - public list items are extracted in encounter order with typed errors on malformed or
        disallowed tag families
      - bookmark and bookmark-set strict extraction follows the NIP-51 table (`e` and `a` only)
        rather than the broader rust struct shape
      - bounded builder helpers now support broader bookmark emission (`e`, `a`, `t`, `url`)
        without widening strict extraction
      - coordinate-backed lists enforce the expected coordinate kind where NIP-51 specifies one
        (`34550`, `30023`, `30015`, `30030`)
      - `emoji` items accept the optional NIP-30 emoji-set address and require it to be a
        `30030:pubkey:d` coordinate when present
      - builder helpers now emit the optional fourth-slot NIP-30 emoji-set coordinate when present
      - encrypted private list content in `event.content` is intentionally ignored by this Wave 1
        helper and tracked for follow-up in `no-e7b`
    - review outcome:
      - rust parity harness now covers all supported rust-backed public-list builders at `DEEP`
        depth
      - rust-nostr bookmark builders still expose broader hashtag/url bookmark shapes than the
        current strict Wave 1 extractor; that narrower boundary remains intentional
      - optional fourth-slot NIP-30 emoji-set builder support remains Zig/spec-driven coverage only
        because rust-nostr standardizes three-item `emoji` tags
  - `27`
    - implemented scope: strict inline `nostr:` URI extraction from readable content with decoded
      NIP-21 entities and stable byte spans
    - accepted semantics:
      - only strict lowercase `nostr:` NIP-21 references are extracted
      - duplicate references are preserved in encounter order
      - bracketed and punctuation-adjacent references produce stable spans for the URI itself
      - malformed, uppercase, or forbidden `nostr:` fragments are ignored as plain text rather than
        failing the whole content scan
      - per-reference TLV scratch ownership is explicit and bounded by caller-provided capacity
    - review outcome:
      - no accepted intentional divergence was needed beyond preserving rust-style lexical boundary
        behavior for `nostr:` URIs
  - `22`
    - implemented scope: strict kind-1111 comment root/parent linkage parsing for event,
      coordinate, and external targets
    - accepted semantics:
      - one uppercase root target and one lowercase parent target are required on every comment
      - `K` and `k` are mandatory and must match the referenced target class
      - Nostr event and coordinate targets require explicit author linkage via `P` and `p`
      - address-scoped comments may carry a companion concrete event id via `E/e` without being
        treated as duplicate targets
      - replaceable coordinates accept an empty trailing `d` component
      - coordinate targets require exact `K/k` kind consistency with the coordinate itself
      - kind-1 text-note targets are rejected so NIP-10 remains the canonical reply path
      - external targets validate `I/i` and `K/k` as a consistent NIP-73 pair and ignore `p/P`
        mention tags rather than misclassifying them as authors
      - malformed trailing fields on NIP-22 linkage tags are rejected rather than ignored
    - accepted strict divergence:
      - `noztr` rejects rust-style permissive NIP-22 extraction that tolerates missing root scope,
        optional `K/k`, or ambiguous competing target families
  - `18`
    - implemented scope: strict kind-6 and kind-16 repost parsing/helpers with deterministic tag
      extraction and embedded-event consistency checks
    - accepted semantics:
      - `kind 6` requires an `e` tag and a relay hint
      - `kind 16` requires either an address coordinate or an embedded event payload
      - when embedded event JSON is present, target `e`, `p`, `k`, and `a` data must agree with the
        embedded event rather than being accepted as loosely related hints
      - address coordinates are matched only when the embedded event has a unique `d` tag and the
        coordinate tuple is exact
      - empty optional relay-hint fields normalize to absent
    - review outcome:
      - no accepted intentional divergence was needed for the strict parser itself
      - rust parity harness covers core kind-6 and kind-16 builder semantics
      - addressable repost builder shape remains source-reviewed from `rust-nostr` rather than
        independently exercised in the parity harness
  - `10`
    - implemented scope: strict kind-1 thread/reply helper extraction from `e` tags
    - accepted semantics:
      - marked `root` and `reply` tags are parsed explicitly
      - duplicate `root` or `reply` tags are rejected
      - a root-only marked reply is treated as a direct reply to the root target
      - legacy `mention` markers are accepted as explicit mention references rather than rejecting
        the extract path
      - four-slot `e` tags with a valid pubkey in slot four are accepted as bounded compatibility
        input, and `noztr` preserves that author pubkey in the extracted reference
      - when no marked tags are present, positional fallback resolves `root`, `reply`, and middle
        mentions deterministically
      - empty optional relay-hint fields normalize to absent
    - audit result:
      - previous strict rejection of legacy `mention` and four-slot pubkey fallback was judged to
        create unnecessary ecosystem friction and was removed
  - `25`
    - implemented scope: native kind-7 reaction parsing/helpers only
    - accepted semantics:
      - last `e` tag selects the reaction target event
      - last `p` tag selects the target author pubkey when present
      - `e`-tag author pubkey is fallback-only and must not leak across later `e` tags
      - custom emoji requires exactly one matching `emoji` tag with a NIP-30-valid shortcode and a
        URL-shaped image field
      - empty optional relay-hint fields normalize to absent
    - accepted quality judgment: this strict custom-emoji validation is retained as a material
      trust-boundary improvement rather than a parity deviation to roll back
    - deferred scope: kind-17 external reactions pending NIP-73 support
- Wave 1 status:
  - Wave 1 is complete.
  - Next phase-order item is Wave 2 / `46`.

## NIP-06 Phase H Boundary Scope

- Public boundary target for Phase H:
  - mnemonic validation
  - mnemonic plus optional passphrase to seed
  - BIP32 master key creation from seed
  - Nostr key derivation at `m/44'/1237'/<account>'/0/0`
  - account support floor: `account = 0` required, higher accounts deterministic through the same
    derivation path
- Explicitly out of Phase H scope:
  - broad wallet-management APIs
  - generalized BIP32 path parser surface beyond the canonical Nostr path
  - non-Nostr coin/application derivation helpers
  - convenience stateful key stores or orchestration helpers
- Follow-up note: broader rust-nostr parity and deep edge-case expansion for NIP-06 remains a later
  phase after the initial narrow boundary is stable.

## NIP-06 H0 Freeze Snapshot

- Selected integration target
  - upstream: `ElementsProject/libwally-core`
  - selected release tag: `release_1.5.2`
  - selected commit: `6439e6e3262c47ce0e51aa95d7b4ff67d9952c52`
- Frozen file target
  - `src/nip06_mnemonic.zig`
- Frozen public surface
  - `mnemonic_validate`
  - `mnemonic_to_seed`
  - `derive_nostr_secret_key_from_seed`
  - `derive_nostr_secret_key`
- Frozen boundary rule
  - `libwally-core` is used only for mnemonic validation, mnemonic-to-seed conversion, master-key
    creation from seed, and derivation along `m/44'/1237'/<account>'/0/0`
  - public-key derivation stays on the existing secp boundary
  - no direct `libwally-core` usage is allowed outside `src/nip06_mnemonic.zig`
- Frozen public failure surface
  - malformed mnemonic length
  - unknown mnemonic word
  - checksum mismatch
  - invalid UTF-8 / normalization failure
  - invalid account (`account >= 2^31`)
  - buffer too small
  - backend unavailable / boundary failure where observable
- Frozen zeroization set
  - mnemonic-derived seed
  - master key material
  - derived child private keys
  - temporary secret staging before copy-out
- Frozen vector corpus floor
  - valid:
    - official BIP39 mnemonic-to-seed vectors
    - both official NIP-06 vectors from `docs/nips/06.md`
    - the additional pinned rust-nostr mnemonic-to-secret-key vector in
      `/workspace/pkgs/nostr/crates/nostr/src/nips/nip06/mod.rs`
    - at least one `account = 1` derivation vector
  - invalid:
    - malformed mnemonic length
    - unknown word
    - checksum mismatch
    - invalid UTF-8 / normalization failure
    - invalid account (`account >= 2^31`)
    - seed/output buffer too small
- Result
  - Wave 0 gate is satisfied; later NIP-06 coding remains deferred to its own implementation lane.

## NIP-06 Acceptance Criteria

- Pinning and boundary
  - `libwally-core` source identity is pinned before implementation starts.
  - all NIP-06 external calls stay behind one narrow boundary module.
  - no direct `libwally-core` usage outside that boundary module.
- Public API and failure contracts
  - every public NIP-06 boundary returns typed errors only.
  - no catch-all invalid/error funnels are allowed.
  - typed errors distinguish malformed mnemonic, invalid checksum/word, invalid passphrase/seed
    boundary, derivation failure, buffer-too-small, and backend-unavailable style failures where
    observable.
- Secret handling
  - mnemonic-derived seed, master key material, derived private keys, and intermediate sensitive
    buffers are zeroized with strict `defer`-backed wipe paths.
  - early returns must not bypass zeroization.
- Vector corpus floor
  - valid vectors:
    - official BIP39 mnemonic-to-seed vectors
    - valid canonical NIP-06 derivation for `account = 0`
    - at least one higher-account derivation vector
  - invalid vectors:
    - malformed mnemonic length
    - unknown word reject
    - checksum mismatch reject
    - malformed derivation/account reject
    - output buffer too small reject
- Determinism and parity
  - repeated runs on identical input yield identical seed, derived key, and typed failure behavior.
  - Phase H parity expectation is the canonical Nostr derivation result; broader rust-nostr parity
    replay and deeper edge corpus remain follow-up work after the initial boundary lands.

## Tradeoffs

## Tradeoff T-H-ANIP-001: Sequence low-ambiguity interop helpers before identity/signing surfaces

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

## Tradeoff T-H-ANIP-002: Adopt vetted `libwally-core` boundary for NIP-06

- Context: NIP-06 introduces BIP39/BIP32 correctness and security burden that can be implemented
  in-house or delegated to a vetted boundary.
- Options:
  - O1: implement BIP39/BIP32 in-house.
  - O2: adopt `libwally-core` behind a pinned narrow boundary.
- Decision: O2.
- Benefits: lower cryptographic implementation risk and faster convergence on a testable boundary.
- Costs: added supply-chain surface and boundary maintenance.
- Risks: boundary sprawl or dependency-policy drift if integration is not kept narrow.
- Mitigations: enforce `D-029`/`D-030`, pin source identity, keep one boundary module, and require
  deterministic vectors plus typed error mapping.
- Reversal Trigger: `libwally-core` cannot satisfy bounded-runtime, typed-error, or deterministic
  corpus requirements.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: NIP-06 planning and future boundary implementation.

## Tradeoff T-H-ANIP-003: Limit initial NIP-06 delivery to the canonical Nostr derivation boundary

- Context: NIP-06 can be delivered as a narrow Nostr-focused derivation boundary or as a broader
  wallet/key-management API.
- Options:
  - O1: ship only the canonical Nostr derivation boundary in Phase H.
  - O2: add broader wallet-management and general BIP32 helper surfaces in the same phase.
- Decision: O1.
- Benefits: lower trust-boundary complexity, tighter review surface, and faster convergence on a
  defensible minimum useful implementation.
- Costs: less ergonomic breadth for callers wanting broader wallet primitives.
- Risks: callers may want more path/generalization helpers earlier.
- Mitigations: document later-phase expansion explicitly and keep the boundary narrow but complete for
  Nostr use.
- Reversal Trigger: actual integrator demand shows the narrow boundary is insufficient for core Nostr
  workflows.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: NIP-06 Phase H boundary shape and acceptance corpus.

## Open Questions And Risks

- `OQ-H-ANIP-001` (NIP-06, medium): what additional rust-nostr parity cases and edge-case vectors
  should be promoted into the required corpus after the initial canonical Nostr derivation boundary
  lands.
- `OQ-H-ANIP-002` (NIP-17, medium): which subset (decode/verify-only vs broader workflow helpers)
  can be added without introducing orchestration semantics into Layer 1.
- `OQ-H-ANIP-003` (NIP-29, high): what fixed-capacity state model is acceptable for relay-group
  semantics without unbounded or policy-coupled behavior.
- `OQ-H-ANIP-004` (NIP-39, high): what trust model and verification policy are acceptable for
  external identity claims under current Layer 1 defaults.
- `OQ-H-ANIP-005` (NIP-03, medium): what bounded proof-shape and verification-depth floor is required
  for deterministic OpenTimestamps validation.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: cryptographic and trust-boundary-heavy items (`03`, `06`, `39`, `46`) are gated with
  explicit risk framing.
- `P02`: platform/runtime integration (`07`) remains rejected to preserve protocol-kernel boundaries.
- `P03`: sequencing prioritizes interoperability primitives and behavior parity evidence.
- `P04`: relay/group and connection semantics (`29`, `46`) remain explicit policy surfaces.
- `P05`: deterministic parse/validation and typed-error forcing are required in wave exits.
- `P06`: bounded memory/work and Layer 1 defaults remain unchanged across all classifications.
