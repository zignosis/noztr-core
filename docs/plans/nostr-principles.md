# Nostr Principles

Canonical design principles for noztr planning and implementation.

## Frozen Defaults

These defaults are frozen for the current planning cycle.
Change requires a new entry in `docs/plans/decision-log.md`.

- `D-001` Parity baseline source:
  - applesauce
    - local: `/workspace/pkgs/applesauce`
    - upstream: `git@github.com:hzrd149/applesauce.git`
    - commit: `5f152fc98e5baa97e8176e54ce9b9345976c8b32`
  - rust-nostr
    - local: `/workspace/pkgs/nostr`
    - upstream: `git@github.com:rust-nostr/nostr.git`
    - commit: `9bcc6cd779a7c6eb41509b37aee4575fa5ae47b9`
  - libnostr-z
    - local: `/workspace/pkgs/libnostr-z`
    - upstream: `git@github.com:privkeyio/libnostr-z.git`
    - commit: `a849dc804521801971f42d71c172aa681ecdc573`
  - pin date: `2026-03-04`
- `D-002` Parity definition:
  - parity means behavior parity (parse, validate, serialize, verify, and tests),
    not API shape parity.
- `D-003` Spec strictness default:
  - strict mode is default.
  - compatibility behavior is only added when explicitly documented with tradeoffs.
- `D-004` Phase gate policy:
  - no phase closes without tradeoff records and ambiguity checkpoint results.

## Decisions

- `P01` Signed event integrity is non-negotiable.
- `P02` Keep protocol core minimal, composable, and transport-agnostic.
- `P03` Prefer stable interoperability over convenience features.
- `P04` Route by explicit heuristics; never hide routing policy implicitly.
- `P05` Preserve deterministic behavior at every public boundary.
- `P06` Keep memory behavior bounded and explicit in all runtime paths.

## Tradeoffs

## Tradeoff T-0-001: Strict default versus broad compatibility

- Context: ecosystem data quality varies; strictness can reject widely-seen input.
- Options:
  - O1: strict by default, scoped compatibility exceptions.
  - O2: compatibility by default, strict mode opt-in.
- Decision: O1.
- Benefits: predictable semantics, lower attack surface, stronger conformance.
- Costs: some ecosystem inputs rejected unless exception is documented.
- Risks: interop friction with permissive clients.
- Mitigations: add narrowly-scoped compatibility rules with tests and rationale.
- Reversal Trigger: compatibility exceptions exceed strict rules in core paths.
- Principles Impacted: P01, P03, P05.
- Scope Impacted: phase A classification, phase B parsing policy, phase D APIs.

## Tradeoff T-0-002: Behavioral parity versus API parity

- Context: libnostr-z API choices include dependency and allocation assumptions.
- Options:
  - O1: match behavior and vectors; keep Zig-native API.
  - O2: clone external API shapes for easier migration.
- Decision: O1.
- Benefits: Zig-native, bounded interfaces aligned with project constraints.
- Costs: migration from external APIs needs adapters.
- Risks: parity claims could be interpreted ambiguously.
- Mitigations: define parity as behavior+tests in scope and decision log.
- Reversal Trigger: adopter demand for API-level parity exceeds maintenance cost.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: phase A scope semantics, C3 parity mapping, D contracts.

## Open Questions

- Should frozen default `D-001` be updated at each phase transition, or only when
  parity-impacting upstream changes are needed?
- Should remote URLs be normalized to HTTPS in planning artifacts?

## Principles Compliance

- Every phase output references impacted principles by ID.
- Every material decision references a tradeoff entry.
- Every unresolved ambiguity is tagged with impact and status.
