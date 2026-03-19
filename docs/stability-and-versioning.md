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
should follow as it moves from local RC review into public release.

## Current Stability Posture

Current status is intentionally conservative:

- the local RC-facing review is positive
- major audit and remediation work is complete
- final RC closure is still pending downstream `noztr-sdk` implementation feedback

So the honest current state is:

- the public contract is intentionally shaped and reviewed
- but the project should still treat the current line as pre-release until that downstream feedback
  closes

## Versioning Policy

`noztr-core` should use SemVer-style release numbering with a strict pre-`1.0.0` posture.

Recommended policy:

- first intentional public release: `0.1.0`
- pre-`1.0.0` public releases use `0.y.z`
- release candidates use `-rc.N`
  - example: `0.1.0-rc.1`
- `1.0.0` is reserved for the point where:
  - downstream validation is complete
  - the RC-facing contract is no longer provisional
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

- `HEAD` is a reviewed RC candidate, not a finished long-term stable line
- the project should not pretend to have a mature long-lived public compatibility promise yet
- existing repo metadata should not be read as proof that a deliberate public release line already
  existed
- the right first public release should start with a clearly named `0.1.0` line rather than
  implying a silent stable contract already existed

## Recommended Path

1. Keep `no-6e6p` open until `noztr-sdk` feedback closes.
2. If that feedback does not reveal a new blocker, cut the first public release as `0.1.0-rc.1` or
   directly as `0.1.0`, depending on release packaging needs.
3. Treat subsequent public contract changes conservatively, even while still pre-`1.0.0`.
4. Promote to `1.0.0` only after the project is ready to treat the current public surface as the
   default compatibility baseline.

## Related Pages

- [scope-and-tradeoffs.md](/workspace/projects/noztr/docs/scope-and-tradeoffs.md)
- [errors-and-ownership.md](/workspace/projects/noztr/docs/errors-and-ownership.md)
- [performance.md](/workspace/projects/noztr/docs/performance.md)
