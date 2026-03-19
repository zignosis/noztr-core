---
title: Zig Anti-Patterns
doc_type: release_guide
status: active
owner: noztr
read_when:
  - contributing_zig_code
  - reviewing_trust_boundary_risks
  - avoiding_noztr_footguns
canonical: true
---

# Zig Anti-Patterns

These are the common implementation shapes contributors should avoid in `noztr`.

The issue is not “style preference.” These patterns usually make the public contract less bounded,
less auditable, or less deterministic.

Several of these are not hypothetical. They are generalized from real audit findings and cleanup
work in `noztr`.

## Avoid These Patterns

### 1. Broad error funnels

Avoid:

- collapsing many public failure causes into one vague error
- `catch` paths that hide the real cause at the trust boundary

Why:

- downstream callers lose the real contract
- invalid input, capacity failure, and backend outage become harder to distinguish

### 2. Heap-first runtime paths

Avoid:

- implicit growth containers in core runtime paths
- public APIs that quietly allocate to make boundary calls “easy”

Why:

- ownership gets blurry
- bounded-memory expectations weaken

### 3. Parse-and-mutate in one pass

Avoid:

- mutating output or state before shape and semantic checks are complete

Why:

- malformed input can leave partial state behind
- review and tests get harder

### 4. Hidden compatibility in the default path

Avoid:

- silently accepting legacy or alternate shapes in the strict default path

Why:

- the kernel contract becomes fuzzy
- callers no longer know what the default surface really promises

### 5. `usize` in protocol-facing contracts

Avoid:

- storing or serializing protocol state with architecture-dependent widths

Why:

- it weakens portability and contract clarity

### 6. Silent truncation or clamping

Avoid:

- quietly clipping lengths, tags, or identifiers

Why:

- malformed input gets normalized into surprising behavior
- caller mistakes become harder to detect

### 7. Bool-only boundary validators

Avoid:

- public validators that only return `bool` when the failure reason materially matters

Why:

- callers lose useful diagnostics
- test coverage gets weaker

### 8. Shared mutable scratch

Avoid:

- global or shared mutable decode scratch for runtime operations

Why:

- aliasing and stale-state bugs become easier to introduce
- explicit ownership is lost

### 9. Hidden mutable backend state

Avoid:

- backend assumptions that live implicitly across unrelated helpers

Why:

- outage and readiness behavior becomes harder to classify correctly
- review cannot see the true seam clearly

### 10. Whole-string opportunistic scans

Avoid:

- searching more text than the contract actually permits

Why:

- lookalike tokens outside the intended region can become false positives
- extractors become harder to reason about

### 11. Public-path assertion leaks

Avoid:

- allowing malformed caller input to reach internal invariants or debug assertions before typed
  validation

Why:

- the public contract changes between “real error” and “debug-only panic”
- invalid input can be misclassified or crash in ways callers should never rely on

### 12. Invalid-vs-capacity confusion

Avoid:

- returning capacity errors for invalid input
- returning invalid-input errors for too-small caller buffers

Why:

- downstream callers lose the real contract
- tests stop proving the right thing

### 13. Contract-layer confusion in examples

Avoid:

- examples that mix full object JSON, canonical preimage, envelopes, and checked wrappers as if
  they were the same thing

Why:

- examples become plausible but wrong
- downstream users learn the wrong mental model

## Review Smells

If you see these, stop and challenge the change:

- “it’s easier if we just allocate here”
- “we can normalize that malformed input silently”
- “the exact error probably doesn’t matter”
- “the helper scans the whole string, but it’s fine”
- “the example is close enough”
- “the state can just live here for now”
- “it only asserts in debug mode”

Those are the kinds of shortcuts that create drift later.

## Related Pages

- [NOZTR Style](/workspace/projects/noztr/docs/guides/noztr-style.md)
- [zig-patterns.md](/workspace/projects/noztr/docs/guides/zig-patterns.md)
- [errors-and-ownership.md](/workspace/projects/noztr/docs/errors-and-ownership.md)
