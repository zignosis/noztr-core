# noztr

Pure Zig Nostr protocol library with a stdlib-first dependency policy and approved pinned crypto
backend exceptions.

## What noztr is

- A deterministic, bounded, compatibility-aware protocol-kernel implementation for Nostr.
- Built as a static library with deterministic, bounded behavior targets.
- Focused on protocol parsing, validation, serialization, and trust-boundary helpers.
- Keeps non-crypto surfaces stdlib-first and isolates approved crypto backends behind narrow boundary
  modules.

## Current status

- Current baseline: post-Phase-H kernel expansion completion on top of a completed local-only
  Phase G closure (`docs/plans/phase-h-kickoff.md`).
- Implemented NIPs from `src/root.zig` exports:
  - `NIP-01` (event, filter, message)
  - `NIP-02`, `NIP-03`, `NIP-05`, `NIP-06`, `NIP-09`, `NIP-10`, `NIP-11`, `NIP-13`
  - `NIP-17`, `NIP-18`, `NIP-19`, `NIP-21`, `NIP-22`, `NIP-23`, `NIP-24`, `NIP-25`, `NIP-27`
  - `NIP-26`, `NIP-29`, `NIP-32`, `NIP-36`, `NIP-39`, `NIP-40`, `NIP-42`, `NIP-44`, `NIP-46`
  - `NIP-51` (bounded public/private list helpers)
  - `NIP-56`, `NIP-59`, `NIP-65`, `NIP-70`, `NIP-73`
  - Optional I6 extension exports (build-flag gated): `NIP-45`, `NIP-50`, `NIP-77`
- Current prep focus: continue the kernel-first sequence before SDK work; next serial item is
  `NIP-37` (`docs/plans/phase-h-kickoff.md`).

## Build and test

```bash
zig build test --summary all
zig build
```

## Repo layout

- `src/` - protocol modules and root exports
- `docs/plans/` - canonical planning and execution artifacts
- `docs/guides/` - style and implementation guidance
- `docs/research/` - study artifacts and parity references
- `tools/interop/` - parity harnesses and interop tooling

## Planning documents

- Build baseline: `docs/plans/build-plan.md`
- Phase G closure baseline: `docs/plans/phase-g-kickoff.md`
- Phase H kickoff baseline: `docs/plans/phase-h-kickoff.md`
- Additional NIP planning (Phase H): `docs/plans/phase-h-additional-nips-plan.md`
- Phase H Wave 1 execution loop: `docs/plans/phase-h-wave1-loop.md`
