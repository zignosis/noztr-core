# NOZTR Style

Date: 2026-03-07

This document defines noztr's engineering style and strictness profile for protocol-kernel modules.
It complements TigerStyle and v1 planning artifacts with project-specific defaults.

## Core Style Profile

- Build a strict protocol kernel first: parse, validate, serialize, and verify with deterministic
  behavior for identical inputs.
- Keep trust boundaries typed and explicit: public APIs return typed error sets, never broad
  catch-all failures.
- Enforce bounded memory and bounded work on runtime paths.
- Keep ownership explicit: runtime encode/decode paths are caller-buffer-first; no hidden allocation
  growth.
- Prefer pure helpers plus explicit state transition points so behavior remains testable and auditable.

## Zig Tenets

- Explicit memory management: why it matters is predictable resource limits; noztr applies this with
  caller-owned buffers, bounded state, and no hidden runtime allocation growth.
- No hidden control flow: why it matters is auditability under failure; noztr applies this with staged
  checks and canonical checked entry points at trust boundaries.
- Errors are values: why it matters is making failure part of the contract; noztr applies this with
  typed error sets and forcing tests for strict and compatibility branches.
- Simplicity over abstraction bloat: why it matters is fewer misuse paths; noztr applies this with one
  obvious strict kernel path and Layer 2 adapters for permissive behavior.
- Deterministic behavior: why it matters is reproducible vectors and parity checks; noztr applies this
  by guaranteeing same input yields same output, including typed errors.
- Compile-time power without runtime tax: why it matters is stronger guarantees with bounded cost;
  noztr applies this with explicit types and compile-time shaping while keeping runtime paths bounded.
- Pragmatic interop: why it matters is integration with mixed clients/relays; noztr applies this with
  strict defaults plus explicit, opt-in compatibility adapters.

## Strictness Policy Notes

- Hex casing (`id`, `pubkey`, `sig`, relay `OK` ids): strict kernel default is lowercase-only hex.
  - Why: preserves canonical representation and removes case-normalization ambiguity in critical
    identifiers.
  - Tradeoff: stricter rejection versus wider permissive interop.
  - Guarantee posture: stronger determinism in Layer 1; case-tolerant behavior belongs in Layer 2.
- Unknown filter fields: strict kernel default is reject unknown fields.
  - Why: catches schema drift and malformed producer behavior at the trust boundary.
  - Tradeoff: reduced forward-compat permissiveness versus stronger typed failure guarantees.
  - Ecosystem posture: future/legacy field tolerance is handled by Layer 2 compatibility adapters,
    not by silent kernel acceptance.

## Two-Layer Model

- Layer 1 (current noztr): strict protocol kernel for parse/validate/serialize/verify with typed
  deterministic failures and bounded runtime behavior.
- Layer 2 (planned adapter): optional compatibility and ergonomic SDK layer that can normalize
  ecosystem variance without weakening Layer 1 guarantees.
- Separation rationale: isolates permissive behavior to explicit adapters, preserves auditable strict
  defaults, and reduces interop friction for real-world integrations.

## Compatibility Profile

- Core defaults remain strict (`D-003`).
- Compatibility behavior is explicit, isolated, and opt-in.
- Compatibility adapters must not change strict-default semantics.
- Every compatibility branch requires typed outcomes, forcing tests, and a tradeoff record.

## One Obvious Way At Trust Boundaries

- Each module should expose canonical safe entry points for trust-boundary calls.
- Multi-step safety checks should be collapsed into one obvious checked call when misuse risk is high.
- Existing canonical wrappers include:
  - `pow_meets_difficulty_verified_id`
  - `delete_extract_targets_checked`
  - `transcript_mark_client_req`
  - `transcript_apply_relay`
- New wrappers should be added only when they reduce ambiguity and preserve typed strict behavior.

## Ecosystem Positioning (High Level)

- `rust-nostr`: broad ecosystem ergonomics and feature breadth; noztr keeps stricter kernel defaults,
  tighter typed boundaries, and stronger bounded-runtime constraints.
- `libnostr-z`: low-level Zig alignment and useful parity reference; noztr differentiates with stricter
  default rejection policy, explicit compatibility isolation, and canonical checked entry points.
- `applesauce`: strong DX-oriented app/client patterns; noztr treats it as behavior-reference input,
  not a driver for permissive kernel defaults.

## LLM Usability And Strictness Evaluation

- LLM usability work evaluates strict APIs as shipped surfaces, not pre-hardening drafts (`D-014`).
- Strictness-profile candidates are evaluated as a controlled loop:
  1) identify the boundary choice and expected strict behavior,
  2) define explicit compatibility adapter behavior if needed,
  3) add forcing vectors for strict and compatibility branches,
  4) run LLM usability tasks against canonical safe entry points,
  5) accept/freeze via decision-log entry and update build-plan/handoff artifacts.
- The release-candidate strictness profile closes only when `OQ-E-006` criteria are complete.

## Practical Checklist

- Deterministic outputs for same input.
- Typed errors at every public boundary.
- Caller-owned buffers for runtime output.
- Explicit bounds and fixed-capacity runtime state.
- One obvious safe trust-boundary call per misuse-prone module.
- Compatibility behavior isolated and opt-in.
