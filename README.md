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

- Current baseline: Phase H RC API-freeze review on top of a completed local-only Phase G
  closure.
- Completed major checkpoints:
  - requested-NIP loop complete through `NIP-B7`
  - exhaustive pre-freeze audit and meta-analysis complete
  - LLM structured usability supplement complete
  - empirical benchmark supplement complete
  - external crypto/backend assurance supplement complete
  - post-exhaustive remediation program complete
  - post-remediation freeze recheck complete
- Current active work:
  - RC API-freeze review in `docs/plans/phase-h-rc-api-freeze.md`
  - current Phase H packet in `docs/plans/phase-h-remaining-work.md`
  - local RC-facing review result in `docs/research/rc-api-freeze-review-report.md`
- Implemented NIPs from `src/root.zig` exports:
  - `NIP-01` (event, filter, message)
  - `NIP-02`, `NIP-03`, `NIP-05`, `NIP-06`, `NIP-09`, `NIP-10`, `NIP-11`, `NIP-13`
- `NIP-17`, `NIP-18`, `NIP-19`, `NIP-21`, `NIP-22`, `NIP-23`, `NIP-24`, `NIP-25`, `NIP-27`
- `NIP-26`, `NIP-29`, `NIP-32`, `NIP-36`, `NIP-37`, `NIP-39`, `NIP-40`, `NIP-42`, `NIP-44`,
  `NIP-46`
- `NIP-51` (bounded public/private list helpers)
- `NIP-56`, `NIP-57`, `NIP-58`, `NIP-59`, `NIP-65`, `NIP-70`, `NIP-73`, `NIP-84`, `NIP-86`,
  `NIP-92`, `NIP-94`, `NIP-99`, `NIP-B0`
  - Optional I6 extension exports (build-flag gated): `NIP-45`, `NIP-50`, `NIP-77`
  - Non-NIP bounded wallet helpers: Nostr-relevant `BIP-85` subset for lowercase-hex entropy text
    and English BIP39 child mnemonic/entropy
- Current routing:
  - repo docs router: [`docs/README.md`](/workspace/projects/noztr/docs/README.md)
  - current state: [`handoff.md`](/workspace/projects/noztr/handoff.md)
  - active baseline: [`docs/plans/build-plan.md`](/workspace/projects/noztr/docs/plans/build-plan.md)
  - current post-core symbol map: [`docs/plans/post-core-contract-map.md`](/workspace/projects/noztr/docs/plans/post-core-contract-map.md)

## Build and test

```bash
zig build test --summary all
zig build
```

## Benchmark evidence

Current local performance evidence can be rerun with:

```bash
zig build empirical-benchmark -Doptimize=ReleaseFast
zig build rc-stress-throughput -Doptimize=ReleaseFast
zig build rc-stress-throughput-soak -Doptimize=ReleaseFast
zig build rc-stress-throughput-csv -Doptimize=ReleaseFast
zig build rc-stress-throughput-markdown -Doptimize=ReleaseFast
```

## RC quick start

Use this route if you want the shortest path into the current public surface.

1. Add `noztr` as a Zig dependency.
2. Pick the right symbol family:
   - core event/filter/message work:
     [`docs/plans/v1-api-contracts.md`](/workspace/projects/noztr/docs/plans/v1-api-contracts.md)
   - post-core jobs like `NIP-05`, `NIP-46`, `NIP-47`, `NIP-59`, `NIP-98`, `NIP-29`, `NIP-88`:
     [`docs/plans/post-core-contract-map.md`](/workspace/projects/noztr/docs/plans/post-core-contract-map.md)
3. Start from one direct example and, when available, one hostile example in
   [`examples/README.md`](/workspace/projects/noztr/examples/README.md).

## Common jobs

| Job | Start here | Example |
| --- | --- | --- |
| Parse, serialize, sign, or verify events | [`docs/plans/v1-api-contracts.md`](/workspace/projects/noztr/docs/plans/v1-api-contracts.md) | [`examples/nip01_example.zig`](/workspace/projects/noztr/examples/nip01_example.zig) |
| Identity lookup and bunker discovery | [`docs/plans/post-core-contract-map.md`](/workspace/projects/noztr/docs/plans/post-core-contract-map.md) | [`examples/discovery_recipe.zig`](/workspace/projects/noztr/examples/discovery_recipe.zig) |
| One-recipient gift wrap build and unwrap | [`docs/plans/post-core-contract-map.md`](/workspace/projects/noztr/docs/plans/post-core-contract-map.md) | [`examples/nip17_wrap_recipe.zig`](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig) |
| Wallet Connect parsing and typed JSON contracts | [`docs/plans/post-core-contract-map.md`](/workspace/projects/noztr/docs/plans/post-core-contract-map.md) | [`examples/nip47_example.zig`](/workspace/projects/noztr/examples/nip47_example.zig) |
| HTTP auth event and header helpers | [`docs/plans/post-core-contract-map.md`](/workspace/projects/noztr/docs/plans/post-core-contract-map.md) | [`examples/nip98_example.zig`](/workspace/projects/noztr/examples/nip98_example.zig) |
| Group replay and poll tally reduction | [`docs/plans/post-core-contract-map.md`](/workspace/projects/noztr/docs/plans/post-core-contract-map.md) | [`examples/nip29_reducer_recipe.zig`](/workspace/projects/noztr/examples/nip29_reducer_recipe.zig), [`examples/nip88_example.zig`](/workspace/projects/noztr/examples/nip88_example.zig) |

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
  - dedicated adversarial examples for the highest-risk SDK-facing boundaries
  - a small public `nostr_keys` helper surface for x-only pubkey derivation and event signing
  - scenario-oriented recipe files for `NIP-03`, `NIP-05`, `NIP-06`, `NIP-17`, `BIP-85`,
    `NIP-39`, `NIP-46`, `NIP-51`, and `NIP-86`
  - open [`examples/README.md`](/workspace/projects/noztr/examples/README.md) for the SDK job map
  - open [`docs/plans/post-core-contract-map.md`](/workspace/projects/noztr/docs/plans/post-core-contract-map.md) for a task-to-symbol route across the main post-core surfaces
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
- Current Phase H packet: `docs/plans/phase-h-remaining-work.md`
- Current RC API-freeze packet: `docs/plans/phase-h-rc-api-freeze.md`
- Completed remediation packet: `docs/plans/post-exhaustive-audit-remediation-plan.md`
- Freeze-recheck decision: `docs/research/post-remediation-freeze-recheck-report.md`
- Current docs router: `docs/README.md`
- Current post-core symbol map: `docs/plans/post-core-contract-map.md`
- Historical phase evidence: `docs/archive/plans/`
