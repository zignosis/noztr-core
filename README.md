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
  - `NIP-26`, `NIP-29`, `NIP-32`, `NIP-36`, `NIP-37`, `NIP-39`, `NIP-40`, `NIP-42`, `NIP-44`,
    `NIP-46`
  - `NIP-51` (bounded public/private list helpers)
  - `NIP-56`, `NIP-57`, `NIP-58`, `NIP-59`, `NIP-65`, `NIP-70`, `NIP-73`, `NIP-84`, `NIP-86`,
    `NIP-92`, `NIP-94`
  - Optional I6 extension exports (build-flag gated): `NIP-45`, `NIP-50`, `NIP-77`
  - Non-NIP bounded wallet helpers: Nostr-relevant `BIP-85` subset for lowercase-hex entropy text
    and English BIP39 child mnemonic/entropy
- Current prep focus: kernel-side split work is complete; next recommended focus is `nzdk`
  planning/execution (`docs/plans/phase-h-kickoff.md`).

## Build and test

```bash
zig build test --summary all
zig build
```

## Use as a local Zig dependency

For local SDK/bootstrap work, consume `noztr` as a normal Zig package dependency.

`build.zig.zon`:

```zig
.{
    .dependencies = .{
        .noztr = .{
            .path = "../noztr",
        },
    },
}
```

`build.zig`:

```zig
const noztr_dependency = b.dependency("noztr", .{});
const noztr_module = noztr_dependency.module("noztr");
exe.root_module.addImport("noztr", noztr_module);
```

This repo now carries one downstream examples package and wires it into
`zig build test --summary all` so SDK-style local consumption stays checked:

- [`examples`](/workspace/projects/noztr/examples)
  - `consumer_smoke.zig` for the minimal dependency/import path
  - direct per-NIP reference examples across all implemented kernel NIPs
  - scenario-oriented recipe files for `NIP-05`, `NIP-06`, `BIP-85`, `NIP-39`, `NIP-46`,
    `NIP-51`, and `NIP-86`
  - open [`examples/README.md`](/workspace/projects/noztr/examples/README.md) for the SDK job map
  - intended as the main downstream example surface for `nzdk` and other SDK consumers

## Current Kernel Notes

- `NIP-06` now applies full BIP39-compatible `NFKD` normalization before mnemonic/passphrase seed
  derivation.
- Deprecated `NIP-04` private-list compatibility remains intentionally deferred; current private
  list support is `NIP-44`-first.
- The crypto boundary remains inside `noztr` for now; see
  [`docs/plans/crypto-boundary-evaluation.md`](/workspace/projects/noztr/docs/plans/crypto-boundary-evaluation.md)
  for the current standalone-library evaluation.

## Repo layout

- `src/` - protocol modules and root exports
- `docs/plans/` - canonical planning and execution artifacts
- `docs/guides/` - style and implementation guidance
- `docs/research/` - study artifacts and parity references
- `tools/interop/` - parity harnesses and interop tooling

## Planning documents

- Build baseline: `docs/plans/build-plan.md`
- Phase H kickoff baseline: `docs/plans/phase-h-kickoff.md`
- Additional NIP planning (Phase H): `docs/plans/phase-h-additional-nips-plan.md`
- Phase H Wave 1 execution loop: `docs/plans/phase-h-wave1-loop.md`
- Historical phase evidence: `docs/archive/plans/`
