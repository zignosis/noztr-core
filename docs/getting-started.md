---
title: Getting Started
doc_type: release_guide
status: active
owner: noztr
read_when:
  - onboarding_public_consumers
  - installing_noztr
  - choosing_a_first_example
canonical: true
---

# Getting Started

This is the shortest public path from "I want to try `noztr-core`" to the right module and
example.

## What You Get

`noztr-core` is a Zig-native Nostr protocol kernel.

It gives you:

- strict protocol parsing and serialization
- typed trust-boundary helpers
- deterministic reducers and fixed-purpose helpers
- a narrow surface meant to sit under your SDK or app

In the `noztr` ecosystem, `noztr-core` is the lower layer and `noztr-sdk` is the higher-level SDK
layer built on top of it.

It does not try to be a full relay runtime, websocket client, or application workflow framework.

## Build And Test

```bash
zig build test --summary all
zig build
```

## Add As A Local Dependency

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

## Choose Your Starting Point

| If you want to... | Open first | Then open |
| --- | --- | --- |
| understand what `noztr` is and whether it fits | [scope-and-tradeoffs.md](scope-and-tradeoffs.md) | [intentional-divergences.md](intentional-divergences.md) |
| understand public ownership, scratch, and failure expectations | [errors-and-ownership.md](errors-and-ownership.md) | [strict_core_recipe.zig](../examples/strict_core_recipe.zig) |
| understand current release posture and versioning | [stability-and-versioning.md](stability-and-versioning.md) | [scope-and-tradeoffs.md](scope-and-tradeoffs.md) |
| understand build floor, optional modules, and split support | [compatibility-and-support.md](compatibility-and-support.md) | [nip-coverage.md](reference/nip-coverage.md) |
| contribute public docs or examples coherently | [docs-style-guide.md](guides/docs-style-guide.md) | [examples/README.md](../examples/README.md) |
| do core event/filter/message work | [core-api-contracts.md](reference/core-api-contracts.md) | [nip01_example.zig](../examples/nip01_example.zig) |
| route a post-core task to the right module | [contract-map.md](reference/contract-map.md) | [examples/README.md](../examples/README.md) |
| browse all public modules | [api-reference.md](reference/api-reference.md) | the linked example for the module you want |
| confirm NIP support coverage | [nip-coverage.md](reference/nip-coverage.md) | the linked example for the NIP you want |
| start from a scenario-oriented guide | [technical-guides.md](guides/technical-guides.md) | the linked example or hostile fixture |

## Best First Examples

- [consumer_smoke.zig](../examples/consumer_smoke.zig)
  - minimal dependency/import check
- [strict_core_recipe.zig](../examples/strict_core_recipe.zig)
  - strict event, message, transcript, and checked-wrapper flows
- [discovery_recipe.zig](../examples/discovery_recipe.zig)
  - identity lookup and bunker discovery
- [remote_signing_recipe.zig](../examples/remote_signing_recipe.zig)
  - remote-signing request, URI, and typed-response flow
- [wallet_recipe.zig](../examples/wallet_recipe.zig)
  - deterministic mnemonic, keys, and wallet-adjacent helpers

## Read The Failure Contract Too

For boundary-heavy surfaces, open the hostile example immediately after the happy-path example.

Useful first hostile examples:

- [nip42_adversarial_example.zig](../examples/nip42_adversarial_example.zig)
- [remote_signing_adversarial_example.zig](../examples/remote_signing_adversarial_example.zig)
- [nip59_adversarial_example.zig](../examples/nip59_adversarial_example.zig)
- [wallet_connect_adversarial_example.zig](../examples/wallet_connect_adversarial_example.zig)
- [http_auth_adversarial_example.zig](../examples/http_auth_adversarial_example.zig)

## Next Step

- For curated narrative routes, go to [technical-guides.md](guides/technical-guides.md)
- For error and ownership expectations, go to [errors-and-ownership.md](errors-and-ownership.md)
- For performance evidence and scope, go to [performance.md](performance.md)
- For stability and versioning posture, go to [stability-and-versioning.md](stability-and-versioning.md)
- For compatibility, optional modules, and support expectations, go to [compatibility-and-support.md](compatibility-and-support.md)
- For full public surface coverage, go to [api-reference.md](reference/api-reference.md)
- For NIP-by-NIP coverage, go to [nip-coverage.md](reference/nip-coverage.md)
