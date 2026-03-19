---
title: Stability And Versioning
doc_type: release_note
status: active
owner: noztr
read_when:
  - evaluating_release_stability
  - understanding_public_versioning
  - preparing_public_adoption
canonical: true
---

# Stability And Versioning

This page explains the public release posture for `noztr-core` and the versioning policy the project
should follow for public releases.

## Current Stability Posture

Current status is intentionally conservative:

- the current line should still be treated as pre-`1.0.0`
- the public contract is intentionally shaped and documented
- compatibility promises should remain conservative until the project is ready to defend the
  current surface as stable by default

## Versioning Policy

`noztr-core` should use SemVer-style release numbering with a strict pre-`1.0.0` posture.

Recommended policy:

- first intentional public release: `0.1.0`
- pre-`1.0.0` public releases use `0.y.z`
- release candidates use `-rc.N`
  - example: `0.1.0-rc.1`
- `1.0.0` is reserved for the point where:
  - release-facing validation is complete
  - the public contract is no longer provisional
  - the project is willing to defend the public surface as stable by default

## What Changes A Version

Patch release, `0.y.z -> 0.y.(z+1)`:

- docs-only improvements
- tests, benchmarks, and harness improvements
- internal refactors with no intended public contract change
- non-breaking bug fixes

Minor release, `0.y.z -> 0.(y+1).0`:

- additive public API growth
- contract clarifications that affect public callers
- pre-`1.0.0` breaking changes

Even before `1.0.0`, breaking changes should not be casual. They should be deliberate, documented,
and treated as notable release events.

## What Counts As A Breaking Change

For `noztr-core`, breaking change means more than renaming a symbol.

It includes:

- changing a public symbol name or module route
- changing typed public error behavior in a way downstream callers must handle differently
- changing ownership or buffer/scratch expectations
- changing a deterministic builder/parser contract in a way that breaks accepted caller behavior
- moving functionality out of the kernel or into the kernel in a way that changes public scope

In other words:

- error contracts count
- ownership contracts count
- deterministic surface shape counts

## Release Discipline

Public release notes should always state:

- whether the release is additive, corrective, or breaking
- whether any typed error contracts changed
- whether any ownership or scratch expectations changed
- whether any surface moved between kernel and higher-layer responsibility

If a release changes public behavior, the docs and examples should be updated in the same release.

## What This Means Right Now

Right now the best public reading is:

- the current public line should be read as a release-candidate or pre-`1.0.0` line, not a
  finished long-term stable line
- the project should not pretend to have a mature long-lived public compatibility promise yet
- the first public release should start with a clearly named `0.1.0` line

## Recommended Path

1. Cut the first public release as `0.1.0-rc.1` or directly as `0.1.0`, depending on release
   packaging needs.
2. Treat subsequent public contract changes conservatively, even while still pre-`1.0.0`.
3. Promote to `1.0.0` only after the project is ready to treat the current public surface as the
   default compatibility baseline.

## Related Pages

- [scope-and-tradeoffs.md](scope-and-tradeoffs.md)
- [errors-and-ownership.md](errors-and-ownership.md)
- [performance.md](performance.md)
