# noztr

Pure Zig Nostr protocol library with zero external dependencies (`@import("std")` only).

## What noztr is

- A strict-by-default protocol-kernel implementation for Nostr.
- Built as a static library with deterministic, bounded behavior targets.
- Focused on protocol parsing, validation, serialization, and trust-boundary helpers.

## Current status

- Current baseline: Phase G maintenance mode (`docs/plans/phase-g-kickoff.md`).
- Implemented NIPs from `src/root.zig` exports:
  - `NIP-01` (event, filter, message)
  - `NIP-02`, `NIP-09`, `NIP-11`, `NIP-13`
  - `NIP-19`, `NIP-21`, `NIP-40`, `NIP-42`
  - `NIP-44`, `NIP-59`, `NIP-65`, `NIP-70`
  - Optional I6 extension exports (build-flag gated): `NIP-45`, `NIP-50`, `NIP-77`

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
- Phase G kickoff baseline: `docs/plans/phase-g-kickoff.md`
- Additional NIP planning (Phase G): `docs/plans/phase-g-additional-nips-plan.md`
