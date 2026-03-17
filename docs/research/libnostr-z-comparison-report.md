---
title: libnostr-z Comparison Report
doc_type: report
status: active
owner: noztr
read_when:
  - evaluating_zig_implementation_posture
  - comparing_against_libnostr_z
depends_on:
  - docs/research/libnostr-z-study.md
  - docs/research/v1-libnostr-z-deep-study.md
canonical: true
---

# libnostr-z Comparison Report

Date: 2026-03-17

Purpose: evaluate `noztr` against `libnostr-z` as a Zig implementation reference and decide
whether the current `noztr` posture needs evidence-backed correction before freeze work.

## Provenance

- local mirror path:
  - `/workspace/pkgs/nostr/libnostr-z`
- origin URL:
  - `git@github.com:privkeyio/libnostr-z.git`
- evaluated commit:
  - `a849dc804521801971f42d71c172aa681ecdc573`
- note:
  - earlier historical notes used `/workspace/pkgs/libnostr-z`; the current mirror lives under the
    nested `nostr/` path above

## Executive Result

- `noztr` currently has the stronger kernel posture for its stated goals.
- `libnostr-z` remains useful as a behavior and packaging reference, not as a runtime or memory
  model reference.
- this comparison does not justify widening `noztr`, loosening its trust-boundary contracts, or
  changing its current crypto/runtime split
- no immediate code change is required from this lane alone

## Good

- `libnostr-z` has a clean public facade in `src/root.zig`
  - it is easy to discover capability entry points from one import surface
- feature-oriented file layout is good
  - one file per protocol surface remains the right default for `noztr`
- explicit message-family separation is good
  - `messages.zig` keeps client and relay grammar distinct and is a useful parity reference for
    transcript shape

## Bad

- `libnostr-z` defaults public parse entry points to heap-backed ownership
  - `event.zig`, `messages.zig`, and `pow.zig` use `std.heap.page_allocator` on default paths
- hot protocol paths are allocator-heavy
  - `filter.zig`, `messages.zig`, and `negentropy.zig` rely on `ArrayListUnmanaged`,
    `allocator.alloc`, and `allocator.dupe`
- parser posture is more permissive than `noztr` wants
  - examples include uppercase single-letter compatibility in event/tag handling and malformed
    optional metadata tolerated as absence instead of typed invalid input
- root scope is broader than a protocol kernel
  - runtime and transport surfaces like relay pools, websocket clients, and signer/runtime helpers
    are exported alongside core protocol helpers

## Ugly

- crypto/runtime coupling is global and stateful
  - `src/crypto.zig` keeps a mutable global crypto context with init/cleanup behavior
- the dependency/runtime model is outside `noztr` policy
  - `build.zig` and `build.zig.zon` pull in `noscrypt`, `stringzilla`, a C wrapper, and
    OpenSSL system libraries
- websocket/TLS support is directly coupled into the repo surface
  - `src/ws/ssl.zig` uses `@cImport` and OpenSSL APIs

## What This Says About noztr

## Strengths

- `noztr` is closer to a true protocol-kernel library
  - `src/root.zig` exports protocol modules and typed trust-boundary helpers, not relay runtime or
    websocket clients
- `noztr` has better public error discipline
  - strict typed invalid-input and checked-wrapper posture is materially stronger than permissive
    skip-or-null parsing
- `noztr` keeps cryptography behind a narrow typed boundary
  - the current backend wrapper in `src/crypto/secp256k1_backend.zig` is still an approved pinned
    exception rather than ambient runtime state
- `noztr` generally uses bounded caller-owned memory
  - message, filter, URI, PoW, and most event surfaces are fixed-capacity or scratch-bounded rather
    than heap-first by default

## Cautions

- `noztr` is not literally allocation-free everywhere
  - shape-heavy modules still use caller-owned scratch arenas or bounded `scratch.alloc` paths,
    especially in `NIP-05`, `NIP-11`, `NIP-46`, and `NIP-77`
- this is acceptable for the current kernel posture because:
  - ownership is explicit
  - limits are bounded
  - failures stay typed
- but it remains a real review target
  - keep challenging whether new parser state can stay fixed-capacity before accepting new scratch
    allocation

## Comparison Verdict By Axis

| Axis | libnostr-z | noztr | Result |
| --- | --- | --- | --- |
| Public API discoverability | strong root facade | strong, narrower root facade | near parity; `noztr` is cleaner for kernel scope |
| Protocol-kernel scope discipline | mixed with runtime/service layers | intentionally separated from SDK/runtime workflow | `noztr` stronger |
| Memory discipline | heap-first in many public/runtime paths | caller-owned scratch and fixed-capacity defaults | `noztr` stronger |
| Trust-boundary behavior | more permissive / tolerant | strict typed errors and checked wrappers | `noztr` stronger |
| Crypto/runtime isolation | global mutable context and external deps | narrow backend boundary with typed outage/errors | `noztr` stronger |
| Zig patterns worth emulating | facade layout, file-per-feature, explicit message families | already adopted in most important places | no change required |

## Decision

- keep the current `noztr` posture
- do not add transport/runtime surfaces just because `libnostr-z` includes them
- do not relax public parser contracts to mimic permissive reference behavior by default
- keep using `libnostr-z` as:
  - behavior evidence
  - edge-case inspiration
  - packaging/API-shape signal
- do not use it as authority for:
  - memory model
  - dependency model
  - crypto runtime architecture
  - kernel-vs-runtime scope

## Watchlist

- keep reviewing scratch-allocation-heavy `noztr` modules for possible further fixed-capacity
  tightening
- keep the root facade protocol-only; do not let websocket, relay-pool, storage, or session layers
  drift into `src/root.zig`
- if backend strategy changes later, preserve:
  - typed backend-unavailable outcomes
  - no global mutable crypto lifecycle
  - no system-library or C-wrapper requirement on the public kernel surface

## Closeout Call

- this lane is report-only and closes with no immediate kernel correction required
- the result supports the existing Phase H boundary-validation posture
- reopen only if:
  - later SDK pressure finds a concrete kernel boundary miss, or
  - RC-freeze review finds a release-facing concern not covered here
