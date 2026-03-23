---
title: Release Signoff Checklist
doc_type: guide
status: active
owner: noztr
read_when:
  - cutting_a_public_release
  - deciding_if_an_rc_is_ready
canonical: true
---

# Release Signoff Checklist

Use this before cutting a public `noztr-core` tag.

This is intentionally short. It is a release-confidence gate, not a history dump.

## Release Gates

Run:

```bash
zig build lint
zig build test --summary all
zig build
zig build release-check
```

`zig build release-check` currently includes:

- the normal test suites
- the downstream `examples/` suite
- the deterministic imported-input property lane
- the empirical benchmark supplement
- the RC stress/throughput supplement
- release artifact generation under `zig-out/release/`

## Required Checks

- public docs route is current:
  - `README.md`
  - `docs/INDEX.md`
  - `examples/README.md`
- public API docs and examples teach the canonical names
- breaking changes are called out honestly in:
  - `CHANGELOG.md`
  - release notes
  - migration guides when needed
- critical consumer flows still have runnable examples
- hostile/boundary-heavy surfaces still have adversarial or property coverage
- dependency and license posture has been reviewed for the current release candidate:
  - `build.zig.zon`
  - interop harness lockfiles under `tools/interop/`
- residual risks are recorded explicitly in the release notes or migration docs

## Release Artifacts

Before release publication, verify:

- `zig-out/release/SHA256SUMS`
- `zig-out/release/release-manifest.json`

The release manifest should match the intended public release state:

- package version
- current commit
- Zig version
- generated artifacts and checksums

## Publication Checks

- tag the intended release commit, not a later follow-up docs commit
- prefer annotated tags such as `v0.1.0-rc.2`
- do not move a public tag casually after publication
- use the GitHub Release body for the human-facing summary if the in-repo note must stay shorter

## RC Readiness Question

Before tagging, answer this directly:

> Can an external user evaluate this repo honestly as a release candidate without needing private
> maintainer context?

If the answer is no, do not tag yet.
