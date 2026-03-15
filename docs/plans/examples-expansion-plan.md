# noztr Examples Expansion Plan

Date: 2026-03-15

## Goal

Make `examples/` the canonical downstream-consumer package for `noztr`, with concise, technical,
flat examples that cover every implemented NIP surface that belongs in the kernel.

## Baseline Audit

Current example quality issues identified before this pass:

- layout was initially too nested for quick consumer discovery
- current examples covered only a small SDK-facing subset
- scenario intent was visible, but coverage was not comprehensive enough for `nzdk`
- examples were executable and useful, but not yet a full reference map across implemented kernel
  surfaces

## Accepted Structure

- keep a single top-level `examples/` package
- no nested `recipes/` package
- no `src/` directory unless Zig requires it, which it does not here
- one dedicated `examples/examples.zig` root that imports all example files
- one top-level README that tells consumers which example to open first
- example files remain technical and to the point; comments explain scope and boundary, not basics

## Coverage Target

Coverage target for this pass:

- one meaningful example per implemented NIP
- one separate `consumer_smoke.zig` file for minimal package usage
- one separate `bip85_example.zig` file for the accepted non-NIP wallet subset
- keep scenario-oriented recipe files as a second layer on top of the direct per-NIP examples

## Example Rules

- examples must compile under the downstream package as part of `zig build test --summary all`
- examples should demonstrate public entry points, not private internals
- examples should prefer one obvious helper, plus one paired validation/roundtrip helper where
  that materially clarifies usage
- examples should not introduce SDK orchestration, networking, or storage concerns
- examples should stay bounded and caller-buffer oriented where the public API does

## Execution Order

1. lock structure and README guidance
2. add examples for core/event/filter/message and metadata/validation NIPs
3. add examples for threading/content/identity surfaces
4. add examples for encryption/private/discovery surfaces
5. add examples for delegation/reporting/badges/highlights/admin surfaces
6. add optional I6 examples behind build-time availability checks
7. run full gates
8. close tracker and sync `.beads/`
