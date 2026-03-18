---
title: Release Docs Index
doc_type: release_index
status: active
owner: noztr
read_when:
  - evaluating_noztr_publicly
  - onboarding_external_consumers
  - routing_public_release_docs
canonical: true
---

# Release Docs Index

This is the public-facing documentation route for `noztr`.

Use these docs if you are evaluating the library, comparing it to other Nostr libraries, or trying
to understand the current release-facing contract at a high level.

## Start Here

- `README.md`
  - short overview, status, build/test commands, and quick-start routing
- `docs/release/noztr-positioning.md`
  - what `noztr` is trying to do, why it exists, tradeoffs, limitations, and comparisons
- `docs/release/intentional-divergences.md`
  - release-facing behavior differences that are intentional in Layer 1
- `docs/release/noztr-process-slide.html`
  - one-slide presentation page for the planning, execution, teaching, and audit loop

## Public Technical Entry Points

- `docs/release/getting-started.md`
  - install/import path and first examples
- `docs/release/technical-guides.md`
  - narrative job-oriented routes through the library
- `docs/release/errors-and-ownership.md`
  - public memory, scratch, and typed-failure model
- `docs/release/performance.md`
  - benchmark and stress evidence, with scope notes
- `docs/release/stability-and-versioning.md`
  - public stability posture, versioning policy, and release expectations
- `docs/release/compatibility-and-support.md`
  - Zig floor, optional/split surfaces, backend posture, and support expectations
- `examples/README.md`
  - task-oriented example routing
- `docs/release/core-api-contracts.md`
  - public route for events, filters, messages, auth, delete, and PoW surfaces
- `docs/release/contract-map.md`
  - public task-to-symbol route for the main post-core public surfaces
- `docs/release/api-reference.md`
  - module-by-module public export reference
- `docs/release/nip-coverage.md`
  - public support matrix across exported NIP surfaces

## Important Note On Internal Docs

This repo also contains extensive internal working documents under local-only `.private-docs/`.

Those documents are valuable for provenance and engineering rigor, but they are not the primary
public documentation surface.

In general:

- `docs/release/` is public-facing release documentation
- `examples/` is public-facing usage material
- `.private-docs/` is mostly internal planning, audit, process, and provenance material

If you are not actively contributing to `noztr`, start with the release docs and examples first.
