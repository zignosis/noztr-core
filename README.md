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
- Supported NIP surface snapshot:
  - use [`docs/reference/nip-coverage.md`](docs/reference/nip-coverage.md) for the detailed
    export/status/example matrix
  - use [`docs/reference/contract-map.md`](docs/reference/contract-map.md) and
    [`examples/README.md`](examples/README.md) when you want the right route or example for a job
  - `✓` means supported in `noztr-core`; `✗` means intentionally not supported here

| Status | NIP | Title | Short description |
| --- | --- | --- | --- |
| ✓ | `NIP‑01` | Basic protocol flow | core events, filters, relay messages, and AND-filter support |
| ✓ | `NIP‑02` | Contacts | contact entries and contact-list helpers |
| ✓ | `NIP‑03` | OpenTimestamps | bounded proof extraction and verification helpers |
| ✓ | `NIP‑04` | Encrypted direct messages | strict legacy kind-4 crypto, payload, and event-shape helpers |
| ✓ | `NIP‑05` | Mapping Nostr keys to DNS | identity lookup and profile mapping helpers |
| ✓ | `NIP‑06` | Basic key derivation from mnemonic seed phrase | bounded mnemonic and seed derivation helpers |
| ✓ | `NIP‑09` | Event deletion request | deletion target extraction and checked deletion helpers |
| ✓ | `NIP‑10` | Text notes and threads | reply and thread extraction helpers |
| ✓ | `NIP‑11` | Relay information document | relay metadata parsing helpers |
| ✓ | `NIP‑13` | Proof of work | event proof-of-work verification helpers |
| ✓ | `NIP‑14` | Subject tag in text events | subject-tag helpers |
| ✓ | `NIP‑17` | Private direct messages | deterministic private-message unwrap and file-tag helpers |
| ✓ | `NIP‑18` | Reposts | repost target extraction helpers |
| ✓ | `NIP‑19` | bech32 entities | bech32 identity encode/decode helpers |
| ✓ | `NIP‑21` | `nostr:` URI scheme | URI parse and validation helpers |
| ✓ | `NIP‑22` | Comment | root/parent comment target extraction helpers |
| ✓ | `NIP‑23` | Long-form content | long-form metadata extract/build helpers |
| ✓ | `NIP‑24` | Extra metadata fields and tags | common metadata tag helpers |
| ✓ | `NIP‑25` | Reactions | reaction target extraction helpers |
| ✗ | `NIP‑26` | Delegated event signing | intentionally not supported |
| ✓ | `NIP‑27` | Text note references | text-reference parsing helpers |
| ✓ | `NIP‑28` | Public chat | public-channel metadata and moderation helpers |
| ✓ | `NIP‑29` | Relay-based groups | pure reducer and bounded group helpers |
| ✓ | `NIP‑30` | Custom emoji | custom-emoji tag helpers |
| ✓ | `NIP‑31` | Dealing with unknown events | alt-tag helpers |
| ✓ | `NIP‑32` | Labeling | label parsing and target extraction helpers |
| ✓ | `NIP‑34` | Git stuff | repository metadata and state helpers |
| ✓ | `NIP‑36` | Sensitive content | content-warning helpers |
| ✓ | `NIP‑37` | Draft events | private draft and relay-list storage helpers |
| ✓ | `NIP‑38` | User status | status metadata helpers |
| ✓ | `NIP‑39` | External identities in profiles | identity-claim helpers |
| ✓ | `NIP‑40` | Expiration timestamp | expiration helpers |
| ✓ | `NIP‑42` | Client authentication | relay auth helpers |
| ✓ | `NIP‑44` | Encrypted payloads | deterministic NIP-44 crypto helpers |
| ✓ | `NIP‑46` | Nostr Connect | remote-signing URI, request, response, and discovery helpers |
| ✓ | `NIP‑47` | Wallet Connect | wallet-connect URI, envelope, and typed JSON helpers |
| ✓ | `NIP‑49` | Private key encryption | encrypted key-export helpers |
| ✓ | `NIP‑51` | Lists | public and private list helpers |
| ✓ | `NIP‑52` | Calendar events | calendar, event, and RSVP helpers |
| ✓ | `NIP‑53` | Live activities | live-activity and live-chat helpers |
| ✓ | `NIP‑54` | Wiki | article, merge-request, and redirect helpers |
| ✓ | `NIP‑56` | Reporting | bounded report extraction and tag helpers |
| ✓ | `NIP‑57` | Lightning zaps | zap request and receipt helpers |
| ✓ | `NIP‑58` | Badges | badge definition, award, and profile helpers |
| ✓ | `NIP‑59` | Gift wrap | deterministic one-recipient wrap helpers |
| ✓ | `NIP‑61` | Nutzaps | nutzap event and redemption helpers |
| ✓ | `NIP‑64` | Chess | PGN and chess metadata helpers |
| ✓ | `NIP‑65` | Relay list metadata | relay metadata helpers |
| ✓ | `NIP‑66` | Relay discovery and liveness monitoring | relay-discovery and monitor helpers |
| ✓ | `NIP‑70` | Protected events | protected-event helpers |
| ✓ | `NIP‑71` | Video events | video metadata and imported-origin helpers |
| ✓ | `NIP‑72` | Moderated communities | community definition, post, and approval helpers |
| ✓ | `NIP‑73` | External content IDs | external-ID helpers |
| ✓ | `NIP‑75` | Zap goals | zap-goal helpers |
| ✓ | `NIP‑78` | Application-specific data | opaque app-data helpers |
| ✓ | `NIP‑84` | Highlights | highlight source and attribution helpers |
| ✓ | `NIP‑86` | Relay management API | relay-admin request/response helpers |
| ✓ | `NIP‑88` | Polls | poll extraction and tally helpers |
| ✓ | `NIP‑89` | Recommended application handlers | handler recommendation helpers |
| ✓ | `NIP‑91` | Unknown event kind filters | AND-filter support in the filter surface |
| ✓ | `NIP‑92` | Media attachments | media attachment metadata helpers |
| ✓ | `NIP‑94` | File metadata | file metadata and dimensions helpers |
| ✓ | `NIP‑98` | HTTP auth | event/header auth helpers |
| ✓ | `NIP‑99` | Classified listings | listing metadata helpers |
| ✓ | `NIP‑B0` | Web bookmarks | bookmark helpers |
| ✓ | `NIP‑B7` | Blossom | blossom server and blob-reference helpers |
| ✓ | `NIP‑C0` | Code snippets | code-snippet and repository-reference helpers |

- Optional I6 extension exports (build-flag gated): `NIP-45`, `NIP-50`, `NIP-77`
- Non-NIP bounded wallet helpers: Nostr-relevant `BIP-85` subset for lowercase-hex entropy text
  and English BIP39 child mnemonic/entropy

## Build and test

```bash
zig build lint
zig build test --summary all
zig build
```

The test gate currently includes the full root-module suite, a core-only root-module suite, and
the downstream `examples/` suite. Those counts overlap across configurations, so they should be
read as execution totals rather than unique logical test cases.

The lint gate is intentionally narrow and functional:

- `zig build lint` runs `zig fmt --check` across the tracked Zig/ZON surface
- build/test correctness remains enforced by `zig build test --summary all` and `zig build`

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
  - scenario-oriented recipe files for `NIP-03`, `NIP-04`, `NIP-05`, `NIP-06`, `NIP-17`, `BIP-85`,
    `NIP-39`, `NIP-46`, `NIP-51`, and `NIP-86`
  - open [`examples/README.md`](examples/README.md) for the SDK job map
  - open [`docs/reference/contract-map.md`](docs/reference/contract-map.md) for a task-to-symbol
    route across the main post-core surfaces
  - intended as the main downstream example surface for `noztr-sdk` and other SDK consumers

## Current Kernel Notes

- `NIP-06` now applies full BIP39-compatible `NFKD` normalization before mnemonic/passphrase seed
  derivation.
- Legacy `NIP-04` kind-4 direct-message helpers are available for strict local crypto, payload,
  and event-shape work.
- The `NIP-04` surface is DM-focused:
  - local encrypt/decrypt helpers target legacy kind-4 DM content
  - decrypt is intended for DM plaintext and rejects non-UTF-8 output
  - this does not widen `NIP-04` into a general raw-bytes or private-content compatibility layer
- Deprecated `NIP-04` private-list compatibility remains intentionally deferred; current private
  list support remains `NIP-44`-first.

## Repo layout

- `src/` - protocol modules and root exports
- `docs/` - public-facing documentation
- official NIP texts - use the upstream repository at `https://github.com/nostr-protocol/nips`
- `.private-docs/` - local-only internal planning, audit, and process material
- `tools/interop/` - parity harnesses and interop tooling
- `CONTRIBUTING.md` - repo contribution guide
- `CHANGELOG.md` - public release history
