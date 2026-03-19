# noztr-core

Pure Zig Nostr protocol library with a stdlib-first dependency policy and approved pinned crypto
backend exceptions.

## What noztr-core is

`noztr-core` is the public library name for this protocol-kernel layer.

The Zig package/import name in examples remains `noztr`.

- A deterministic, bounded, compatibility-aware protocol-kernel implementation for Nostr.
- Built as a static library with deterministic, bounded behavior targets.
- Focused on protocol parsing, validation, serialization, and trust-boundary helpers.
- Keeps non-crypto surfaces stdlib-first and isolates approved crypto backends behind narrow boundary
  modules.

For the release-facing explanation of what `noztr-core` is trying to do, why it exists, its benefits
and limitations, and how it compares to more mature libraries, start with
[`docs/release/noztr-positioning.md`](/workspace/projects/noztr/docs/release/noztr-positioning.md).
For the public docs route as a whole, start with
[`docs/index.md`](/workspace/projects/noztr/docs/index.md).
For the technical public docs set, continue with:
- [`docs/release/getting-started.md`](/workspace/projects/noztr/docs/release/getting-started.md)
- [`docs/release/noztr-style.md`](/workspace/projects/noztr/docs/release/noztr-style.md)
- [`docs/release/docs-style-guide.md`](/workspace/projects/noztr/docs/release/docs-style-guide.md)
- [`docs/release/zig-patterns.md`](/workspace/projects/noztr/docs/release/zig-patterns.md)
- [`docs/release/zig-anti-patterns.md`](/workspace/projects/noztr/docs/release/zig-anti-patterns.md)
- [`docs/release/technical-guides.md`](/workspace/projects/noztr/docs/release/technical-guides.md)
- [`docs/release/errors-and-ownership.md`](/workspace/projects/noztr/docs/release/errors-and-ownership.md)
- [`docs/release/performance.md`](/workspace/projects/noztr/docs/release/performance.md)
- [`docs/release/stability-and-versioning.md`](/workspace/projects/noztr/docs/release/stability-and-versioning.md)
- [`docs/release/compatibility-and-support.md`](/workspace/projects/noztr/docs/release/compatibility-and-support.md)
- [`docs/release/release-notes-template.md`](/workspace/projects/noztr/docs/release/release-notes-template.md)
- [`docs/release/api-reference.md`](/workspace/projects/noztr/docs/release/api-reference.md)
- [`docs/release/nip-coverage.md`](/workspace/projects/noztr/docs/release/nip-coverage.md)

## Current status

- Current posture: the local RC-facing review is positive, but final closure remains pending
  downstream `noztr-sdk` feedback.
- `noztr-core` and `noztr-sdk` are intended to be complementary layers:
  - `noztr-core` owns deterministic protocol-kernel work
  - `noztr-sdk` owns higher-level workflow, transport, and application-facing composition
- Public versioning policy is now explicit:
  - treat the current line as pre-release
  - start the first intentional public release at `0.1.0`
  - reserve `1.0.0` for the point where the RC-facing contract is no longer provisional
- Completed major checkpoints include:
  - exhaustive audit and meta-analysis
  - LLM structured usability supplement
  - empirical benchmark supplement
  - external crypto/backend assurance supplement
  - remediation and freeze recheck
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
- Public docs routing:
  - docs router: [`docs/index.md`](/workspace/projects/noztr/docs/index.md)
  - release docs router: [`docs/release/README.md`](/workspace/projects/noztr/docs/release/README.md)

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

## Why noztr-core

Short version:

- `noztr-core` is trying to be a Zig-native protocol kernel, not a batteries-included Nostr app
  stack
- it favors deterministic, bounded, typed trust-boundary behavior over permissive convenience
- it is a better fit when you want to build your own SDK or app architecture on top of a narrow
  core

For the full positioning and comparison note, read
[`docs/release/noztr-positioning.md`](/workspace/projects/noztr/docs/release/noztr-positioning.md).

## RC quick start

Use this route if you want the shortest path into the current public surface.

1. Add the `noztr` Zig package dependency for `noztr-core`.
2. Pick the right symbol family:
   - core event/filter/message work:
     [`docs/release/core-api-contracts.md`](/workspace/projects/noztr/docs/release/core-api-contracts.md)
   - post-core jobs like `NIP-05`, `NIP-46`, `NIP-47`, `NIP-59`, `NIP-98`, `NIP-29`, `NIP-88`:
     [`docs/release/contract-map.md`](/workspace/projects/noztr/docs/release/contract-map.md)
3. Start from one direct example and, when available, one hostile example in
   [`examples/README.md`](/workspace/projects/noztr/examples/README.md).

## Public docs vs internal docs

This repo contains both public-facing release docs and extensive internal working docs.

- Public-facing docs:
  - [`docs/index.md`](/workspace/projects/noztr/docs/index.md)
  - [`docs/release/README.md`](/workspace/projects/noztr/docs/release/README.md)
  - [`docs/release/getting-started.md`](/workspace/projects/noztr/docs/release/getting-started.md)
  - [`docs/release/noztr-style.md`](/workspace/projects/noztr/docs/release/noztr-style.md)
  - [`docs/release/docs-style-guide.md`](/workspace/projects/noztr/docs/release/docs-style-guide.md)
  - [`docs/release/zig-patterns.md`](/workspace/projects/noztr/docs/release/zig-patterns.md)
  - [`docs/release/zig-anti-patterns.md`](/workspace/projects/noztr/docs/release/zig-anti-patterns.md)
  - [`docs/release/noztr-positioning.md`](/workspace/projects/noztr/docs/release/noztr-positioning.md)
  - [`docs/release/intentional-divergences.md`](/workspace/projects/noztr/docs/release/intentional-divergences.md)
  - [`docs/release/technical-guides.md`](/workspace/projects/noztr/docs/release/technical-guides.md)
  - [`docs/release/errors-and-ownership.md`](/workspace/projects/noztr/docs/release/errors-and-ownership.md)
  - [`docs/release/performance.md`](/workspace/projects/noztr/docs/release/performance.md)
  - [`docs/release/stability-and-versioning.md`](/workspace/projects/noztr/docs/release/stability-and-versioning.md)
  - [`docs/release/compatibility-and-support.md`](/workspace/projects/noztr/docs/release/compatibility-and-support.md)
  - [`docs/release/release-notes-template.md`](/workspace/projects/noztr/docs/release/release-notes-template.md)
  - [`docs/release/core-api-contracts.md`](/workspace/projects/noztr/docs/release/core-api-contracts.md)
  - [`docs/release/contract-map.md`](/workspace/projects/noztr/docs/release/contract-map.md)
  - [`docs/release/api-reference.md`](/workspace/projects/noztr/docs/release/api-reference.md)
  - [`docs/release/nip-coverage.md`](/workspace/projects/noztr/docs/release/nip-coverage.md)
  - [`examples/README.md`](/workspace/projects/noztr/examples/README.md)
  - [`CONTRIBUTING.md`](/workspace/projects/noztr/CONTRIBUTING.md)
  - [`CHANGELOG.md`](/workspace/projects/noztr/CHANGELOG.md)
- Internal working docs:
  - local-only `.private-docs/`

The internal docs are kept locally for provenance and engineering rigor, but they are not the main
public documentation surface and are not intended for remote publication.

## Common jobs

| Job | Start here | Example |
| --- | --- | --- |
| Parse, serialize, sign, or verify events | [`docs/release/core-api-contracts.md`](/workspace/projects/noztr/docs/release/core-api-contracts.md) | [`examples/nip01_example.zig`](/workspace/projects/noztr/examples/nip01_example.zig) |
| Identity lookup and bunker discovery | [`docs/release/contract-map.md`](/workspace/projects/noztr/docs/release/contract-map.md) | [`examples/discovery_recipe.zig`](/workspace/projects/noztr/examples/discovery_recipe.zig) |
| One-recipient gift wrap build and unwrap | [`docs/release/contract-map.md`](/workspace/projects/noztr/docs/release/contract-map.md) | [`examples/nip17_wrap_recipe.zig`](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig) |
| Wallet Connect parsing and typed JSON contracts | [`docs/release/contract-map.md`](/workspace/projects/noztr/docs/release/contract-map.md) | [`examples/nip47_example.zig`](/workspace/projects/noztr/examples/nip47_example.zig) |
| HTTP auth event and header helpers | [`docs/release/contract-map.md`](/workspace/projects/noztr/docs/release/contract-map.md) | [`examples/nip98_example.zig`](/workspace/projects/noztr/examples/nip98_example.zig) |
| Group replay and poll tally reduction | [`docs/release/contract-map.md`](/workspace/projects/noztr/docs/release/contract-map.md) | [`examples/nip29_reducer_recipe.zig`](/workspace/projects/noztr/examples/nip29_reducer_recipe.zig), [`examples/nip88_example.zig`](/workspace/projects/noztr/examples/nip88_example.zig) |

## Use as a local Zig dependency

For local `noztr-sdk` or other downstream bootstrap work, consume the `noztr` Zig package as the
normal dependency for `noztr-core`.

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
  - open [`docs/release/contract-map.md`](/workspace/projects/noztr/docs/release/contract-map.md) for a task-to-symbol route across the main post-core surfaces
  - intended as the main downstream example surface for `noztr-sdk` and other SDK consumers

## Current Kernel Notes

- `NIP-06` now applies full BIP39-compatible `NFKD` normalization before mnemonic/passphrase seed
  derivation.
- Deprecated `NIP-04` private-list compatibility remains intentionally deferred; current private
  list support is `NIP-44`-first.

## Repo layout

- `src/` - protocol modules and root exports
- `docs/release/` - public-facing release documentation
- official NIP texts - use the upstream repository at `https://github.com/nostr-protocol/nips`
- `.private-docs/` - local-only internal planning, audit, and process material
- `tools/interop/` - parity harnesses and interop tooling
- `CONTRIBUTING.md` - repo contribution guide
- `CHANGELOG.md` - public release history
