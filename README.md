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
[`docs/scope-and-tradeoffs.md`](docs/scope-and-tradeoffs.md).
For the public docs route as a whole, start with
[`docs/INDEX.md`](docs/INDEX.md).
Key public entry points:
- [`docs/getting-started.md`](docs/getting-started.md)
- [`docs/reference/contract-map.md`](docs/reference/contract-map.md)
- [`docs/reference/api-reference.md`](docs/reference/api-reference.md)
- [`examples/README.md`](examples/README.md)

## Public release posture

- `noztr-core` and `noztr-sdk` are intended to be complementary layers:
  - `noztr-core` owns deterministic protocol-kernel work
  - `noztr-sdk` owns higher-level workflow, transport, and application-facing composition
- Public versioning policy is conservative:
  - treat the current line as pre-`1.0.0`
  - start the first intentional public release at `0.1.0`
  - reserve `1.0.0` for the point where the project is ready to defend the public contract as
    stable by default
- Selected implemented surfaces:

| Surface | Short scope |
| --- | --- |
| `NIP-01` | core events, filters, and relay message grammar |
| `NIP-05`, `NIP-11`, `NIP-42`, `NIP-98` | identity lookup, relay info, auth, and HTTP auth helpers |
| `NIP-06`, `NIP-49`, `BIP-85` subset | bounded wallet, mnemonic, and key-encryption helpers |
| `NIP-17`, `NIP-44`, `NIP-59` | private-message unwrap, gift wrap, and one-recipient outbound helpers |
| `NIP-46`, `NIP-47`, `NIP-86` | remote-signing, wallet-connect, and relay-admin typed contracts |
| `NIP-29`, `NIP-72`, `NIP-88` | bounded reducers and community/group/poll helper flows |
| `NIP-52`, `NIP-53`, `NIP-54`, `NIP-71` | calendar, live-activity, wiki, and video metadata helpers |
| `NIP-61`, `NIP-66`, `NIP-75`, `NIP-89`, `NIP-91` | nutzap, relay-discovery, zap-goal, handler, and AND-filter helpers |

For the full implemented surface, including narrower and optional/gated modules, see
[`docs/reference/nip-coverage.md`](docs/reference/nip-coverage.md).

- Optional I6 extension exports (build-flag gated): `NIP-45`, `NIP-50`, `NIP-77`
- Non-NIP bounded wallet helpers: Nostr-relevant `BIP-85` subset for lowercase-hex entropy text
  and English BIP39 child mnemonic/entropy

## Build and test

```bash
zig build test --summary all
zig build
```

The test gate currently includes the full root-module suite, a core-only root-module suite, and
the downstream `examples/` suite. Those counts overlap across configurations, so they should be
read as execution totals rather than unique logical test cases.

## Benchmark evidence

Published performance checks can be rerun with:

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
[`docs/scope-and-tradeoffs.md`](docs/scope-and-tradeoffs.md).

## Quick start

Use this route if you want the shortest path into the public surface.

1. Add the `noztr` Zig package dependency for `noztr-core`.
2. Pick the right symbol family:
   - core event/filter/message work:
     [`docs/reference/core-api-contracts.md`](docs/reference/core-api-contracts.md)
   - post-core jobs like `NIP-05`, `NIP-46`, `NIP-47`, `NIP-59`, `NIP-98`, `NIP-29`, `NIP-88`:
     [`docs/reference/contract-map.md`](docs/reference/contract-map.md)
3. Start from one direct example and, when available, one hostile example in
   [`examples/README.md`](examples/README.md).

## Public docs vs internal docs

Public-facing docs live in [`docs/INDEX.md`](docs/INDEX.md), [`docs/`](docs), and
[`examples/README.md`](examples/README.md). Internal working material lives in local-only
`.private-docs/` and is not part of the public documentation route.

## Common jobs

| Job | Start here | Example |
| --- | --- | --- |
| Parse, serialize, sign, or verify events | [`docs/reference/core-api-contracts.md`](docs/reference/core-api-contracts.md) | [`examples/nip01_example.zig`](examples/nip01_example.zig) |
| Identity lookup and bunker discovery | [`docs/reference/contract-map.md`](docs/reference/contract-map.md) | [`examples/discovery_recipe.zig`](examples/discovery_recipe.zig) |
| One-recipient gift wrap build and unwrap | [`docs/reference/contract-map.md`](docs/reference/contract-map.md) | [`examples/nip17_wrap_recipe.zig`](examples/nip17_wrap_recipe.zig) |
| Wallet Connect parsing and typed JSON contracts | [`docs/reference/contract-map.md`](docs/reference/contract-map.md) | [`examples/nip47_example.zig`](examples/nip47_example.zig) |
| HTTP auth event and header helpers | [`docs/reference/contract-map.md`](docs/reference/contract-map.md) | [`examples/nip98_example.zig`](examples/nip98_example.zig) |
| Group replay and poll tally reduction | [`docs/reference/contract-map.md`](docs/reference/contract-map.md) | [`examples/nip29_reducer_recipe.zig`](examples/nip29_reducer_recipe.zig), [`examples/nip88_example.zig`](examples/nip88_example.zig) |

## Use as a local Zig dependency

For local `noztr-sdk` or other downstream bootstrap work, consume the `noztr` Zig package as the
normal dependency for `noztr-core`.

`build.zig.zon`:

```zig
.{
    .dependencies = .{
        .noztr = .{
            .path = "../noztr-core",
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

- [`examples`](examples)
  - `consumer_smoke.zig` for the minimal dependency/import path
  - reference examples covering the implemented kernel NIP surface
  - dedicated adversarial examples for the highest-risk SDK-facing boundaries
  - a small public `nostr_keys` helper surface for x-only pubkey derivation and event signing
  - scenario-oriented recipe files for `NIP-03`, `NIP-05`, `NIP-06`, `NIP-17`, `BIP-85`,
    `NIP-39`, `NIP-46`, `NIP-51`, and `NIP-86`
  - open [`examples/README.md`](examples/README.md) for the SDK job map
  - open [`docs/reference/contract-map.md`](docs/reference/contract-map.md) for a task-to-symbol
    route across the main post-core surfaces
  - intended as the main downstream example surface for `noztr-sdk` and other SDK consumers

## Current Kernel Notes

- `NIP-06` now applies full BIP39-compatible `NFKD` normalization before mnemonic/passphrase seed
  derivation.
- Deprecated `NIP-04` private-list compatibility remains intentionally deferred; current private
  list support is `NIP-44`-first.

## Repo layout

- `src/` - protocol modules and root exports
- `docs/` - public-facing documentation
- official NIP texts - use the upstream repository at `https://github.com/nostr-protocol/nips`
- `.private-docs/` - local-only internal planning, audit, and process material
- `tools/interop/` - parity harnesses and interop tooling
- `CONTRIBUTING.md` - repo contribution guide
- `CHANGELOG.md` - public release history
