# AGENTS.md — noztr-core

Public contributor and LLM guide for this repo.

`noztr-core` is the protocol-kernel layer in the `noztr` Zig ecosystem. `noztr-sdk` is the
complementary higher-level SDK layer built on top of it.

## Start Here

Read these first:

- `README.md`
- `docs/INDEX.md`
- `examples/README.md`
- `CONTRIBUTING.md`

Then choose the right public guide:

- positioning and tradeoffs:
  - `docs/scope-and-tradeoffs.md`
  - `docs/intentional-divergences.md`
- getting started and public contract routing:
  - `docs/getting-started.md`
  - `docs/reference/core-api-contracts.md`
  - `docs/reference/contract-map.md`
  - `docs/reference/api-reference.md`
  - `docs/reference/nip-coverage.md`
- public contributor style:
  - `docs/guides/noztr-style.md`
  - `docs/guides/docs-style-guide.md`
  - `docs/guides/zig-patterns.md`
  - `docs/guides/zig-anti-patterns.md`
- public contract details:
  - `docs/errors-and-ownership.md`
  - `docs/compatibility-and-support.md`
  - `docs/stability-and-versioning.md`
  - `docs/performance.md`

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

If local `.beads/` state exists in that maintainer clone, use `br` for local issue tracking and
keep `.beads/` out of public commits.

If local tracker state does not exist yet, initialize it locally with `br init` and keep that
state untracked in public git history.
