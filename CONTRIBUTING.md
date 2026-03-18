# Contributing To noztr

Thanks for contributing to `noztr`.

This repo is a Zig Nostr protocol library with a deliberately narrow kernel scope. The best
contributions are the ones that keep that scope clear while improving correctness, determinism,
docs, and downstream usability.

## Before You Start

Read these first:

- [README.md](/workspace/projects/noztr/README.md)
- [AGENTS.md](/workspace/projects/noztr/AGENTS.md)
- [handoff.md](/workspace/projects/noztr/handoff.md)

If you are working as a maintainer or automation agent, follow the startup routing in
[AGENTS.md](/workspace/projects/noztr/AGENTS.md). Internal working material now lives in local-only
`.private-docs/`, while `docs/release/` and `examples/` are the public docs surface.

## Scope

`noztr` is trying to be:

- a deterministic, bounded protocol kernel
- a strong Zig foundation for SDKs and apps
- explicit about trust boundaries and ownership

`noztr` is not trying to be:

- a relay runtime
- a websocket/TLS stack
- a storage layer
- a full application or session framework

If a proposed change adds workflow, network orchestration, or app-level convenience, challenge the
scope first.

## Public Docs Versus Internal Docs

This repo intentionally keeps two documentation layers:

- public tracked docs:
  - `README.md`
  - `docs/release/`
  - `examples/README.md`
- internal local-only docs:
  - `.private-docs/`

Public docs should stay suitable for users, downstream SDKs, and future website publication.

Internal docs are for:

- planning
- audit history
- process control
- provenance

Do not route external readers into `.private-docs/`.

## Website Note

The future website will live in a different repo.

That means docs in this repo should be:

- technically accurate
- self-contained enough to publish later
- written so they can be imported or adapted into the website without depending on internal docs

When in doubt:

- keep canonical technical content here
- keep website presentation concerns out of this repo

## Build And Test

Run these after code changes:

```bash
zig build test --summary all
zig build
```

For docs-only changes, at minimum run:

```bash
git diff --check
./agent-brief
```

## Issue Tracking

This repo uses `br` for all task tracking.

Typical flow:

```bash
br ready --json
br update <id> --claim --json
# do the work
br close <id> --reason "Completed" --json
br sync --flush-only
git add .beads/
git commit -m "sync beads"
```

Do not create parallel markdown TODO systems.

## Public Release Docs Contributions

If you touch public docs, prefer improving:

- `docs/release/getting-started.md`
- `docs/release/technical-guides.md`
- `docs/release/core-api-contracts.md`
- `docs/release/contract-map.md`
- `docs/release/api-reference.md`
- `docs/release/nip-coverage.md`
- `docs/release/errors-and-ownership.md`
- `docs/release/performance.md`
- `docs/release/stability-and-versioning.md`
- `docs/release/compatibility-and-support.md`
- `examples/README.md`

Keep docs and examples linked both ways whenever it materially helps users or LLMs navigate.

## Code Contributions

For code work:

- keep functions small and explicit
- keep behavior bounded
- prefer typed trust-boundary failures
- do not add broad dependencies
- do not widen kernel scope casually

Before closing a protocol slice, make sure the work includes:

- tests
- negative cases
- symmetry checks where applicable
- examples or hostile examples for boundary-heavy surfaces

## Release And Versioning

Current public versioning posture is conservative.

See:

- [docs/release/stability-and-versioning.md](/workspace/projects/noztr/docs/release/stability-and-versioning.md)

Short version:

- current line is still effectively pre-release
- first intentional public release should start at `0.1.0`
- `1.0.0` should wait until the RC-facing contract is no longer provisional

## Questions To Ask Before Landing A Change

- does this keep `noztr` inside protocol-kernel scope?
- does it improve correctness, determinism, clarity, or downstream usability?
- does it preserve or improve typed trust-boundary behavior?
- does it need a public docs update?
- does it need an example or hostile example?

If the answer to those questions is weak, the change probably needs more refinement before landing.
