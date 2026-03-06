# Implementation Kickoff (Phase F)

Date: 2026-03-05

Purpose: implementation-ready handoff for the first coding slice only (`I0`/`I1`) with strict phase
gates, exact file targets, and deterministic verification cadence.

## Decisions

- `PF-001`: start implementation with `I0` then `I1` only; do not begin `I2+` until `I1` exit gate
  is passed.
- `PF-002`: keep strict-by-default behavior (`D-003`) as canonical in all first-slice APIs;
  compatibility paths are out of scope for `I0`/`I1`.
- `PF-003`: enforce typed boundary errors and deterministic behavior checks before adding any optional
  extension behavior.
- `PF-004`: treat ambiguity discovery as a hard stop when it affects trust boundaries, crypto
  correctness, or frozen defaults (`D-001`..`D-004`).
- `PF-005`: close I1 signatures on the resolved default crypto path: in-repo thin Zig wrapper over
  pinned `bitcoin-core/secp256k1` BIP340/Schnorr backend, with all backend calls behind one boundary
  module.

## First Implementation Slice (I0/I1)

### I0: Foundation and Shared Contracts

Ordered coding steps:

1. Create `src/limits.zig` with shared caps/constants used by Phase D contracts.
2. Create `src/errors.zig` with shared typed error groups used by `I0`/`I1` modules.
3. Create `src/root.zig` export skeleton for `limits`, `errors`, `nip01_event`, `nip01_filter`
   symbols (stubs allowed in `I0`, real bindings in `I1`).
4. Update `build.zig` so static library build and test targets include `src/root.zig` and co-located
   tests.
5. Add compile-time limit invariants and relation checks in `src/limits.zig` tests.
6. Add smoke tests in `src/root.zig` for export availability and typed error import usage.

Exact files for I0:

- Create: `src/limits.zig`
- Create: `src/errors.zig`
- Create: `src/root.zig`
- Update: `build.zig`

I0 gate checks:

- `zig build test --summary all`
- `zig build`

### I1: Core Event and Filter Kernel

Ordered coding steps:

1. Create `src/nip01_event.zig` with typed parse/verify APIs and deterministic replacement helper:
   `event_parse_json`, `event_serialize_canonical`, `event_compute_id`, `event_verify_id`,
   `event_verify_signature`, `event_verify`, `event_replace_decision`.
2. Implement the resolved crypto boundary for signature closure:
   - add one in-repo boundary module that wraps pinned `bitcoin-core/secp256k1` BIP340/Schnorr calls.
   - enforce "no direct backend calls outside boundary module" as an implementation constraint.
   - map backend outcomes to deterministic typed errors for sign/verify/pubkey parse paths.
3. Implement strict event-field checks and typed failures per contract (`duplicate key`, `invalid hex`,
   bounds violations, id/sig/pubkey failures).
4. Create `src/nip01_filter.zig` with strict parser and pure match functions:
   `filter_parse_json`, `filter_matches_event`, `filters_match_event`.
5. Implement deterministic AND-within-filter / OR-across-filters behavior and strict `#x` key
   validation.
6. Update `src/root.zig` exports from I0 stubs to concrete `nip01_event` and `nip01_filter` symbols.
7. Add co-located forcing tests for every public error variant in both files.

Exact files for I1:

- Create: `src/nip01_event.zig`
- Create: `src/nip01_filter.zig`
- Update: `src/root.zig`

I1 gate checks:

- `zig build test --summary all`
- `zig build`
- I1 signature closure acceptance criteria are satisfied:
  - backend is pinned by commit or tag and recorded in implementation notes.
  - boundary-only call graph is enforced; no direct backend calls outside one boundary module.
  - sign/verify/pubkey parse outcomes use deterministic typed-error mapping.
  - BIP340 vector suite passes with required negative corpus coverage.
  - differential verification checks pass against pinned reference behavior.
  - signature paths perform no unbounded runtime allocation.

## Required Verification And Vector Checks

- Run after each material change: `zig build test --summary all`.
- Run on slice closure: `zig build`.
- I0 checks:
  - compile-time assertions prove limits relation invariants.
  - root export smoke tests prove `root -> limits/errors` wiring.
- I1 vector floor:
  - `nip01_event`: minimum `5 valid + 5 invalid`.
  - `nip01_filter`: minimum `5 valid + 5 invalid`.
- Required I1 invalid vectors:
  - event duplicate critical key reject.
  - event invalid lowercase-hex/length reject.
  - event invalid id and invalid signature reject.
  - event max-bounds failures (tags/content).
  - event tie-break determinism (`created_at` equal -> lexical `id`).
  - filter malformed `#x` key reject.
  - filter overflow/capacity rejects.
  - filter `since > until` reject.
  - filter OR-across-filters deterministic behavior.
- Forcing rule: every public error variant in `EventParseError`, `EventVerifyError`,
  `FilterParseError` has at least one direct forcing test.

## High-Risk Guardrails For Later Phases

- `nip44` (`I5`): preserve strict staged decrypt invariants in exact order
  (`length -> version -> MAC -> decrypt -> padding`) with typed stage errors and invalid corpus
  coverage for every stage.
- `nip59_wrap` (`I5`): preserve strict staged verification order (`wrap -> seal -> rumor`) and require
  typed failure by stage for malformed/signature/sender mismatch cases.
- `nip42_auth` (`I2`): enforce strict challenge/relay/timestamp checks with no permissive fallback and
  explicit stale/mismatch typed failures.
- Security-sensitive behavior must carry both negative corpus tests and differential checks against
  pinned references before phase closure.

## Tradeoffs

## Tradeoff T-F-001: I0/I1 focus versus parallel multi-phase coding

- Context: coding can proceed narrowly through foundational/core modules, or parallelize across later
  modules for faster breadth.
- Options:
  - O1: strict `I0 -> I1` sequencing with gate closure between slices.
  - O2: parallelize `I0/I1/I2` to increase implementation throughput.
- Decision: O1.
- Benefits: lower contract drift risk, easier deterministic verification, cleaner defect isolation.
- Costs: less short-term breadth.
- Risks: perceived slower visible progress.
- Mitigations: enforce small ordered steps and strict gate cadence per slice.
- Reversal Trigger: repeated evidence that sequential gating blocks delivery without reducing rework.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: `I0`, `I1`.

## Tradeoff T-F-002: Co-located vector tests versus external fixture files in first slice

- Context: vectors can live in dedicated files or directly in module test blocks.
- Options:
  - O1: co-located vectors/tests in `src/nip01_event.zig` and `src/nip01_filter.zig` first.
  - O2: introduce external fixture corpus files immediately.
- Decision: O1.
- Benefits: faster local review and direct contract-to-test traceability.
- Costs: potential later migration cost if fixture corpus grows.
- Risks: test readability pressure as corpus expands.
- Mitigations: keep deterministic helper functions and promote to fixtures in hardening when needed.
- Reversal Trigger: vector corpus growth materially harms readability or review speed.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: `I1` tests.

## Unresolved Tradeoffs (Carried Forward)

- `UT-E-001` (optional vector depth): impact radius is optional modules (`I4`, `I6`), no block on
  `I0`/`I1`; mitigation is to preserve strict core vector floors now and reassess when optional modules
  begin.
- `UT-E-002` (compatibility API placement): impact radius begins at modules that add compat entries,
  not `I0`/`I1`; mitigation is to keep strict APIs canonical and avoid compat file-layout decisions in
  this slice.
- `UT-E-003` (NIP-44 differential replay depth): impact radius starts in `I5`; mitigation is to
  retain deterministic harness assumptions in current docs and defer execution to crypto phase.

## Open Questions

- `OQ-E-001`: optional vector-depth escalation threshold for `nip77_negentropy`/`nip45_count`.
  - Impact radius: optional extension lanes (`I6`) and long-tail regression confidence.
  - Current handling in this kickoff: accepted-risk, no `I0`/`I1` block.
- `OQ-E-002`: compatibility namespace placement (`co-located` vs `compat/`).
  - Impact radius: future source tree organization and compat discoverability.
  - Current handling in this kickoff: accepted-risk, strict-default behavior unchanged.
- `OQ-E-003`: whether NIP-44 differential replay becomes required CI before RC.
  - Impact radius: crypto CI runtime and parity assurance in `I5/I7`.
  - Current handling in this kickoff: accepted-risk, pinned vectors remain mandatory baseline.

## Ambiguity Checkpoint

`A-F-001`
- Topic: potential mismatch between contract-level allocator signatures and TigerStyle static-allocation
  posture in runtime paths.
- Impact: medium.
- Status: accepted-risk.
- Default: implement contracts exactly as written for `I0`/`I1`; defer any contract-level allocator
  policy revision to a later phase artifact.
- Owner: Phase I owner.

`A-F-002`
- Topic: strict file-layout decision for future compatibility entry points.
- Impact: low.
- Status: accepted-risk.
- Default: avoid compat layout changes in `I0`/`I1`; preserve strict API naming now.
- Owner: Phase I owner.

`A-F-003`
- Topic: first-slice vector corpus physical format (co-located-only vs fixture split).
- Impact: low.
- Status: resolved.
- Default: co-located tests for `I1`; revisit in hardening if corpus growth requires extraction.
- Owner: Phase I owner.

Ambiguity checkpoint result: high-impact `decision-needed` count = 0.

## Stop Conditions

- Stop immediately and log a `decision-needed` ambiguity if any required behavior would force a frozen
  default (`D-001`..`D-004`) change.
- Stop immediately if a trust-boundary correctness rule from `v1-api-contracts.md` cannot be enforced
  with typed errors and deterministic output.
- Stop immediately if event signature/id verification cannot be satisfied on the resolved backend path
  (one-module in-repo wrapper over pinned `bitcoin-core/secp256k1`) under strict deterministic,
  typed-error, and bounded-work contracts.
- Stop immediately if any public API would require catch-all error variants or unbounded runtime
  allocation to proceed.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: first slice prioritizes strict trust-boundary checks in `nip01_event`.
- `P02`: work remains protocol-kernel focused (`limits/errors/event/filter`) with no transport coupling.
- `P03`: implementation ordering and vector gates preserve behavior-parity-first execution.
- `P04`: no implicit relay/auth policy shortcuts introduced in first slice.
- `P05`: deterministic serialization, replacement ordering, and filter semantics are explicit gates.
- `P06`: bounded caps, typed over-bound failures, and strict gate commands are required.
