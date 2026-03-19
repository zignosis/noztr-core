# AGENTS.md — noztr-core

Public contributor and LLM guide for this repo.

`noztr-core` is the protocol-kernel layer in the `noztr` Zig ecosystem. `noztr-sdk` is the
complementary higher-level SDK layer built on top of it.

## Start Here

Read these first:

- `README.md`
- `docs/index.md`
- `docs/release/README.md`
- `examples/README.md`
- `CONTRIBUTING.md`

Then choose the right public guide:

- positioning and tradeoffs:
  - `docs/release/noztr-positioning.md`
  - `docs/release/intentional-divergences.md`
- getting started and public contract routing:
  - `docs/release/getting-started.md`
  - `docs/release/core-api-contracts.md`
  - `docs/release/contract-map.md`
  - `docs/release/api-reference.md`
  - `docs/release/nip-coverage.md`
- public contributor style:
  - `docs/release/noztr-style.md`
  - `docs/release/docs-style-guide.md`
  - `docs/release/zig-patterns.md`
  - `docs/release/zig-anti-patterns.md`
- public contract details:
  - `docs/release/errors-and-ownership.md`
  - `docs/release/compatibility-and-support.md`
  - `docs/release/stability-and-versioning.md`
  - `docs/release/performance.md`

## Scope

`noztr-core` is trying to be:

- a deterministic, bounded Nostr protocol kernel
- explicit about trust boundaries, typed errors, and ownership
- a strong Zig foundation for `noztr-sdk`, other SDKs, and applications

`noztr-core` is not trying to be:

- a relay runtime
- a websocket or TLS stack
- a storage layer
- a full workflow or application framework

If a proposed change adds network orchestration, app workflow, or session policy, challenge the
scope first.

## Build And Test

Run these after code changes:

```bash
zig build test --summary all
zig build
```

For docs-only changes, at minimum run:

```bash
git diff --check
```

## Public Docs Versus Internal Docs

This repo intentionally keeps two documentation layers:

- public tracked docs:
  - `README.md`
  - `docs/`
  - `examples/README.md`
  - `CONTRIBUTING.md`
- internal local-only docs:
  - `.private-docs/`

Do not route public readers into `.private-docs/`.

## Maintainers And Local Automation

If you are working in a local maintainer clone and `.private-docs/AGENTS.md` exists, continue
there for the internal operator workflow, current phase routing, and local execution state.
