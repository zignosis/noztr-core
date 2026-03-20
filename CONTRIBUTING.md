# Contributing To noztr

Thanks for contributing to `noztr`.

This repo is a Zig Nostr protocol library with a deliberately narrow kernel scope. The best
contributions are the ones that keep that scope clear while improving correctness, determinism,
docs, and downstream usability.

## Before You Start

Run `./agent-brief` first if you want the public startup route in one place.

Read these first:

- [README.md](README.md)
- [docs/INDEX.md](docs/INDEX.md)
- [AGENTS.md](AGENTS.md)

Then load role-specific guides as needed:

- for public docs work: [docs/guides/docs-style-guide.md](docs/guides/docs-style-guide.md)
- for code work: [docs/guides/noztr-style.md](docs/guides/noztr-style.md),
  [docs/guides/zig-patterns.md](docs/guides/zig-patterns.md), and
  [docs/guides/zig-anti-patterns.md](docs/guides/zig-anti-patterns.md)

If you are working as a maintainer or local automation agent and `.private-docs/AGENTS.md` exists,
continue there for the internal maintainer workflow. Internal working material lives in local-only
`.private-docs/`, while `docs/` and `examples/` are the public docs surface.

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

Public docs should stay suitable for users, downstream SDKs, and future website publication.
Internal planning, audit, and process material belongs in local-only `.private-docs/`.
Do not route external readers into `.private-docs/`.

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

## Issue Tracking

This repo encourages local `br` usage during development.

Typical local flow:

```bash
br ready --json
br update <id> --claim --json
# do the work
br close <id> --reason "Completed" --json
br sync --flush-only
```

`.beads/` and `.private-docs/` are maintainer-local state. Use them locally, but do not add them
to public commits.

Local setup note:

```bash
br init
```

If your clone already has local `.beads/` state, reuse it. If you are not acting as a maintainer,
do not commit `.beads/` or `.private-docs/` to the public repo.

Do not create parallel markdown TODO systems in tracked public docs.

## Commit Subjects

Prefer scoped conventional subjects.

- maintainer commits should use: `<type>:<issue-id>: <summary>`
- allowed maintainer types: `feat`, `fix`, `doc`, `ref`, `chore`
- public contributors without a maintainer-local issue id may use: `<type>: <summary>`

Examples:

```text
feat:<issue-id>: add a bounded helper for relay discovery parsing
doc:<issue-id>: tighten public docs routing for examples
ref:<issue-id>: simplify a parser without changing the public contract
```

## Public Release Docs Contributions

If you touch public docs, prefer improving:

- `docs/getting-started.md`
- `docs/guides/noztr-style.md`
- `docs/guides/zig-patterns.md`
- `docs/guides/zig-anti-patterns.md`
- `docs/guides/technical-guides.md`
- `docs/reference/core-api-contracts.md`
- `docs/reference/contract-map.md`
- `docs/reference/api-reference.md`
- `docs/reference/nip-coverage.md`
- `docs/errors-and-ownership.md`
- `docs/performance.md`
- `docs/stability-and-versioning.md`
- `docs/compatibility-and-support.md`
- `examples/README.md`

Keep docs and examples linked both ways whenever it materially helps users or LLMs navigate.

## Code Contributions

For code work:

- keep functions small and explicit
- keep behavior bounded
- prefer typed trust-boundary failures
- do not add broad dependencies
- do not widen kernel scope casually

Public style references:

- [docs/guides/noztr-style.md](docs/guides/noztr-style.md)
- [docs/guides/docs-style-guide.md](docs/guides/docs-style-guide.md)
- [docs/guides/zig-patterns.md](docs/guides/zig-patterns.md)
- [docs/guides/zig-anti-patterns.md](docs/guides/zig-anti-patterns.md)

Before closing a protocol slice, make sure the work includes:

- tests
- negative cases
- symmetry checks where applicable
- examples or hostile examples for boundary-heavy surfaces

## Release And Versioning

Current public versioning posture is conservative.

See:

- [docs/stability-and-versioning.md](docs/stability-and-versioning.md)
- [docs/release-notes-template.md](docs/release-notes-template.md)
- [CHANGELOG.md](CHANGELOG.md)

Short version:

- current line is still effectively pre-release
- first intentional public release should start at `0.1.0`
- `1.0.0` should wait until the project is ready to defend the public contract as stable by default

## Questions To Ask Before Landing A Change

- does this keep `noztr` inside protocol-kernel scope?
- does it improve correctness, determinism, clarity, or downstream usability?
- does it preserve or improve typed trust-boundary behavior?
- does it need a public docs update?
- does it need an example or hostile example?

If the answer to those questions is weak, the change probably needs more refinement before landing.
