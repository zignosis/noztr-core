---
title: noztr Positioning
doc_type: release_note
status: active
owner: noztr
read_when:
  - evaluating_noztr_for_use
  - comparing_noztr_to_other_nostr_libraries
  - explaining_why_noztr_exists
canonical: true
---

# noztr Positioning

This document answers the release-facing questions:

- what `noztr` is trying to do
- how it does it
- why someone would choose it
- its main benefits and limitations
- how it compares to more mature libraries

## What noztr is trying to do

`noztr` is trying to be a strong Layer 1 Nostr protocol library for Zig.

That means:

- deterministic and bounded protocol behavior
- explicit trust-boundary helpers for parsing, validation, serialization, verification, and pure
  reduction
- a narrow kernel that stops before workflow, transport, storage, and policy layers
- a library that is simple for SDKs and applications to build on without inheriting runtime or
  orchestration assumptions

`noztr` is not trying to be an all-in-one Nostr application stack, relay runtime, or opinionated
client SDK.

## How noztr does it

`noztr` takes a protocol-kernel approach.

- One module per NIP or feature in `src/`
- Bounded, caller-owned, or fixed-capacity data handling by default
- Typed public trust-boundary errors instead of permissive skip-or-null parsing
- Checked helper surfaces for high-risk boundaries
- Stdlib-first dependency policy, with approved pinned crypto backend exceptions kept behind narrow
  wrappers
- Examples and hostile examples used as part of the public contract surface, not just as demos

The design rule is simple:

- if the logic is pure, deterministic, bounded, and reusable across many callers, it is a kernel
  candidate
- if it needs networking, workflow orchestration, retries, storage, UI policy, or app-level
  convenience, it belongs outside `noztr`

## Why this library exists

There are already mature Nostr libraries. `noztr` exists because those libraries usually optimize
for a different center of gravity:

- broader SDK/runtime surfaces
- more permissive parser defaults
- application convenience over strict trust-boundary behavior
- dependency and runtime choices that are reasonable for apps, but not ideal for a small Zig
  protocol kernel

`noztr` exists to provide a different option:

- Zig-first
- protocol-kernel scoped
- deterministic
- bounded
- explicit about what it accepts, rejects, and intentionally leaves to higher layers

## Why choose noztr

Choose `noztr` if you want:

- a Zig-native Nostr library instead of binding through a larger runtime stack
- a narrow protocol kernel, not a full relay/client framework
- strict typed trust-boundary behavior
- explicit kernel-vs-SDK boundaries
- good local performance for bounded protocol work
- a library that is designed to compose into your own SDK or app architecture

## Benefits

- narrow and coherent scope
  - easier to reason about than a library that mixes protocol helpers with runtime workflow
- stronger trust-boundary posture
  - malformed or contradictory input is more likely to fail early and explicitly
- bounded memory posture
  - avoids a heap-first public API style in most protocol paths
- deterministic helper design
  - especially useful for SDKs, tooling, reducers, and controlled integration points
- good Zig engineering discipline
  - explicit widths, explicit boundaries, and strong control over the public surface
- good local performance for a protocol kernel
  - reducer and helper hotspots are comfortably in fast local-library territory

## Limitations

- narrower than mature application-facing libraries
  - many higher-level conveniences are intentionally absent
- stricter than permissive libraries
  - some malformed or ambiguous input that other libraries tolerate will be rejected
- not a network/runtime stack
  - callers still need an SDK, transport layer, or application layer
- crypto backend exceptions still exist
  - `noztr` is not literally stdlib-only today
- newer and less battle-hardened than the oldest widely used Nostr libraries
  - the scope and quality bar are strong, but ecosystem tenure still matters

## Tradeoffs

What you gain by choosing `noztr`:

- tighter protocol-kernel scope
- stronger typed trust-boundary behavior
- fewer runtime and dependency assumptions
- clearer separation between kernel logic and SDK/application workflow
- a Zig-native foundation that is easier to embed into your own architecture

What you give up:

- fewer built-in workflows and conveniences
- less permissive behavior on malformed or ambiguous input
- a younger ecosystem and fewer long-lived downstream integrations
- more responsibility at the SDK or application layer

That trade is intentional. `noztr` is trying to be a strong substrate, not the broadest possible
user-facing library.

## When noztr is the wrong choice

Do not choose `noztr` if you mainly want:

- a full relay runtime
- websocket/TLS client/server infrastructure
- network fetch helpers and orchestration
- wallet, mailbox, or session workflow out of the box
- a large ecosystem of prebuilt app-facing conveniences today
- the safest choice for “widest existing deployment” rather than “narrower, stricter kernel”

If your primary goal is to move fast with a broad application-facing Nostr stack, one of the more
mature libraries is probably the better fit.

## Comparison To Other Libraries

## Against `rust-nostr` and `nostr-tools`

Those libraries are stronger ecosystem references for active interoperability and broad deployed
usage.

Relative to them, `noztr` is:

- narrower
- more kernel-oriented
- more explicit about trust-boundary contracts
- less interested in permissive convenience behavior by default

That is a tradeoff, not a universal win.

If you want mature, broad, batteries-included application ecosystems, those libraries remain
stronger choices.

If you want a smaller Zig protocol kernel that can sit underneath your own SDK or controlled app
architecture, `noztr` is the better fit.

See also:

- `docs/release/intentional-divergences.md`

## Against `libnostr-z`

`libnostr-z` is the most relevant Zig comparison, but it is not trying to be exactly the same kind
of library.

Relative to `libnostr-z`, `noztr` is intentionally:

- narrower in scope
- stricter at trust boundaries
- less runtime-coupled
- less dependency-heavy
- more disciplined about keeping websocket, TLS, and service layers out of the protocol kernel

`libnostr-z` remains useful as a packaging and behavior reference, but it is not the memory,
runtime, or dependency model `noztr` is aiming for.

## Against TigerBeetle

TigerBeetle is not a Nostr library and not a feature comparison target. It is an engineering
quality reference for Zig.

`noztr` uses TigerBeetle mainly as a pressure test for:

- function shape
- assertion density
- explicit state
- bounded memory
- strong systems-style Zig discipline

That lens helped tighten `noztr`, but `noztr` remains a protocol library, not a database or
systems runtime.

## Bottom Line

`noztr` is for people who want a Zig-native Nostr protocol kernel with:

- deterministic behavior
- bounded and explicit trust-boundary surfaces
- strong kernel-vs-SDK separation
- good local performance
- fewer runtime assumptions than the more mature, broader libraries

Its main cost is that it is intentionally narrower, stricter, and younger than the most widely
used Nostr libraries. If that tradeoff matches your architecture, `noztr` is what it is trying to
be.
