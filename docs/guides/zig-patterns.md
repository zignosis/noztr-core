---
title: Zig Patterns
doc_type: release_guide
status: active
owner: noztr
read_when:
  - contributing_zig_code
  - reviewing_implementation_shape
  - learning_noztr_safe_defaults
canonical: true
---

# Zig Patterns

These are the preferred implementation patterns for `noztr`.

They are intentionally practical. This page is for contributors who need to know what “good
noztr-style Zig” looks like in code review.

These patterns also reflect what the TigerBeetle-style audit pressure and the later full-library
audit taught us about what keeps this repo strong.

## Preferred Patterns

### 1. Caller-owned output

Preferred:

- caller provides output storage
- function returns the written slice or typed success value

Why:

- ownership stays explicit
- runtime memory stays bounded
- output sizing problems stay visible

### 2. Staged boundary checks

Preferred order:

1. size or cap check
2. shape parse
3. semantic validation
4. mutation, verification, or cryptographic work

Why:

- malformed input is rejected before deeper invariants matter
- partial mutation bugs are easier to avoid
- error contracts stay clearer

### 3. Typed error surfaces

Preferred:

- precise error unions at public boundaries
- explicit mapping for invalid input, capacity, and backend failures

Why:

- the failure contract becomes part of the API
- downstream callers and tests can reason about the surface directly

### 4. Explicit integer widths

Preferred:

- `u16`, `u32`, `u64` where the protocol or bounds are known

Why:

- protocol state and serialization stay architecture-stable
- contracts are easier to audit than `usize`-shaped surfaces

### 5. Small pure helpers

Preferred:

- small helpers that do one bounded thing
- state transitions at explicit edges

Why:

- tests get simpler
- review gets simpler
- deterministic behavior is easier to prove

Tiger-style lesson:

- if a function is trying to parse, validate, normalize, and mutate all at once, it is usually too
  wide

### 6. Explicit state cells and seams

Preferred:

- one obvious state owner for a backend or mutable subsystem
- explicit seam modules for exceptional dependencies

Why:

- hidden mutable state is easier to misuse
- outages and state assumptions are easier to map correctly at the boundary
- review can see where responsibility starts and ends

### 7. Checked entry points for risky boundaries

Preferred:

- one obvious safe trust-boundary call when misuse risk is high

Why:

- callers have a canonical safe path
- review and examples can teach one clear boundary contract

### 8. Region-bounded scans

Preferred:

- extractors and scanners that operate only in the intended syntactic region

Why:

- lookalike tokens outside the real parse region stop being accidental matches
- boundary review becomes more mechanical and trustworthy

### 9. Invalid-vs-capacity separation

Preferred:

- explicit handling for malformed input versus too-small caller buffers

Why:

- public contracts stay honest
- downstream callers do not have to reverse-engineer whether a failure was their input or their
  storage

### 10. `defer` and `errdefer` for cleanup

Preferred:

- `defer` for normal cleanup
- `errdefer` for error-path cleanup

Why:

- secret handling and temporary buffers are easier to keep correct
- cleanup logic stays local to the resource it protects

### 11. Hostile examples for boundary-heavy surfaces

Preferred:

- one direct example
- one hostile example where the boundary is easy to misuse

Why:

- the intended failure contract becomes visible to humans and LLMs

### 12. Example-layer clarity

Preferred:

- examples that name the contract layer they are demonstrating

Why:

- full object JSON, canonical preimage, envelopes, and checked wrappers are easy to confuse if the
  example is only “roughly right”

## Practical Module Patterns

Good `noztr`-style module behavior usually looks like:

- parse/build helpers that stay deterministic
- explicit checked wrappers at dangerous boundaries
- pure reducers for replay/state-application logic
- compatibility behavior isolated instead of silently folded into the default path
- backend seams that are obvious and narrow
- reviewable scan regions instead of whole-string opportunism

## Review Heuristics

In review, good Zig for `noztr` usually feels like:

- obvious control flow
- explicit ownership
- explicit limits
- explicit error meaning
- bounded helper shape
- explicit state
- explicit negative space

If the code feels clever, hidden, or sprawling, it is probably drifting away from the style we
want.

## Related Pages

- [NOZTR Style](/workspace/projects/noztr/docs/guides/noztr-style.md)
- [zig-anti-patterns.md](/workspace/projects/noztr/docs/guides/zig-anti-patterns.md)
- [errors-and-ownership.md](/workspace/projects/noztr/docs/errors-and-ownership.md)
