---
title: NOZTR Style
doc_type: release_guide
status: active
owner: noztr
read_when:
  - contributing_code
  - understanding_noztr_engineering_defaults
  - reviewing_protocol_kernel_changes
canonical: true
---

# NOZTR Style

This is the public contributor-facing style guide for `noztr`.

It explains how the library is supposed to feel and why some changes fit the repo while others do
not.

For contribution workflow, start with [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Integration Rule

`NOZTR Style` is not separate from Tiger-style engineering discipline.

For public contributors, the right mental model is:

- Tiger provides the engineering pressure:
  - simple control flow
  - explicit state
  - strong invariants
  - bounded behavior
  - code that is hard to misunderstand
- `noztr` adds the protocol-kernel posture:
  - strict trust boundaries
  - explicit ownership
  - compatibility without hidden permissiveness
  - kernel-vs-SDK scope discipline

So the intended style is:

- Tiger-style engineering discipline
- applied to a narrow Nostr protocol kernel

## What This Library Optimizes For

`noztr` is trying to be:

- a deterministic Nostr protocol kernel
- bounded in memory and runtime behavior
- explicit about trust boundaries
- simple to audit and simple to build on

That means code should prefer:

- explicit contracts
- explicit ownership
- explicit failure modes
- narrow scope

It should avoid:

- hidden allocation growth
- hidden workflow assumptions
- permissive parsing for convenience alone
- broad helpers that mix protocol logic with application policy

## Core Style Rules

- keep protocol behavior deterministic for the same input
- keep public trust-boundary failures typed and explicit
- keep ownership explicit and caller-buffer-first on runtime paths
- keep runtime work bounded
- keep kernel logic separate from SDK, transport, storage, and UI policy
- prefer the simplest behavior that is correct, bounded, and ecosystem-compatible
- prefer explicit state over hidden mutable state
- prefer simple branch structure over clever compactness
- make invariants obvious in code, not only in comments
- inside module namespaces, prefer descriptive public names over repeating numeric NIP ids
- apply consistency in the direction of clarity, not in the direction of mechanical numbering

## Tiger-Style Engineering Defaults

Contributors should assume these defaults unless a specific change clearly justifies an exception:

- small functions with one clear job
- explicit state transitions
- explicit preconditions and postconditions
- straightforward control flow
- no hidden resource growth
- code that makes the negative space obvious, not just the happy path

In practice this means:

- avoid sprawling coordinator functions
- split boundary stages so review can see where shape checking ends and semantic checking begins
- keep state cells and backend seams explicit instead of ambient
- make failure reasons visible at the public boundary

## Scope Discipline

Good kernel work:

- parsing
- validation
- serialization
- verification
- pure reducers
- deterministic protocol glue

Bad kernel creep:

- session orchestration
- relay workflow
- redirects or app launch behavior
- storage or cache policy
- UI policy
- broad convenience wrappers that hide higher-layer decisions

If a change feels like app or SDK workflow, it probably does not belong in `noztr`.

## Memory And Ownership

The default runtime posture is:

- caller-owned buffers
- explicit output slices
- fixed-capacity or bounded state
- no heap-first public API style

Contributors should preserve that feel unless there is strong evidence that a different approach is
worth the cost.

See also:

- [errors-and-ownership.md](../errors-and-ownership.md)

One important lesson from the audit work:

- explicit state beats hidden mutable state, especially around backend seams

If a helper quietly depends on ambient mutable state, challenge it.

## Error Style

`noztr` prefers typed boundary errors over vague failure funnels.

Public callers should be able to tell the difference between:

- invalid input
- capacity failure
- backend outage
- intentionally unsupported behavior

Do not collapse those into one generic error unless the surface truly has no more precise public
contract.

Another audit lesson:

- invalid input should not reach deeper helper invariants before typed validation

That means contributors should treat public-path assertion leaks as real design bugs, not as debug
mode trivia.

## Strictness Without Fussiness

`noztr` is strict by default, but it should not become fussy for its own sake.

Good strictness:

- rejecting malformed or contradictory input
- preserving canonical emitted output
- keeping trust-boundary behavior explicit

Bad fussiness:

- adding narrow special-case rules without clear value
- rejecting harmless valid variation just to express purity
- widening the typed error surface when one existing error already says enough

The goal is an auditable kernel, not a performative one.

One practical test:

- if a rule makes the contract safer, clearer, or more deterministic, it is probably justified
- if it mainly makes the code “feel stricter” while reducing compatibility and adding complexity, it
  probably is not

## Compatibility Model

The library uses a two-layer idea:

- Layer 1: strict protocol kernel
- higher layers: adapters, SDK ergonomics, and workflow behavior

Compatibility should be explicit and isolated. Do not quietly smuggle permissive behavior into the
default kernel path.

## Practical Review Questions

Before landing a change, ask:

- does this stay inside protocol-kernel scope?
- does it keep ownership and failure contracts explicit?
- does it improve correctness, determinism, or downstream usability?
- does it add complexity that the trust boundary does not justify?
- does it belong in `noztr`, or in a higher layer?
- does it keep the code simple in the Tiger sense, or does it only make it more ornate?

## Review Heuristics

These heuristics should guide contributor review:

- watch for public-path assertion leaks
- keep invalid-input and capacity-failure handling distinct
- keep scan regions explicit and bounded
- do not let canonicalization quietly become over-strict input rejection
- treat examples as contract-bearing artifacts, not presentation extras
- prefer explicit backend seams over hidden mutable cross-cutting state

## Next Pages

- [zig-patterns.md](zig-patterns.md)
- [zig-anti-patterns.md](zig-anti-patterns.md)
- [compatibility-and-support.md](../compatibility-and-support.md)
