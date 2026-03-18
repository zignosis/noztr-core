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

This is the shortest public path from "I want to try `noztr`" to the right module and example.

## What You Get

`noztr` is a Zig-native Nostr protocol kernel.

It gives you:

- strict protocol parsing and serialization
- typed trust-boundary helpers
- deterministic reducers and fixed-purpose helpers
- a narrow surface meant to sit under your SDK or app

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

## Choose Your Starting Point

| If you want to... | Open first | Then open |
| --- | --- | --- |
| understand what `noztr` is and whether it fits | [noztr-positioning.md](/workspace/projects/noztr/docs/release/noztr-positioning.md) | [intentional-divergences.md](/workspace/projects/noztr/docs/release/intentional-divergences.md) |
| do core event/filter/message work | [core-api-contracts.md](/workspace/projects/noztr/docs/release/core-api-contracts.md) | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| route a post-core task to the right module | [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md) | [examples/README.md](/workspace/projects/noztr/examples/README.md) |
| browse all public modules | [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md) | the linked example for the module you want |
| confirm NIP support coverage | [nip-coverage.md](/workspace/projects/noztr/docs/release/nip-coverage.md) | the linked example for the NIP you want |
| start from a scenario-oriented guide | [technical-guides.md](/workspace/projects/noztr/docs/release/technical-guides.md) | the linked example or hostile fixture |

## Best First Examples

- [consumer_smoke.zig](/workspace/projects/noztr/examples/consumer_smoke.zig)
  - minimal dependency/import check
- [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig)
  - strict event, message, transcript, and checked-wrapper flows
- [discovery_recipe.zig](/workspace/projects/noztr/examples/discovery_recipe.zig)
  - identity lookup and bunker discovery
- [remote_signing_recipe.zig](/workspace/projects/noztr/examples/remote_signing_recipe.zig)
  - remote-signing request, URI, and typed-response flow
- [wallet_recipe.zig](/workspace/projects/noztr/examples/wallet_recipe.zig)
  - deterministic mnemonic, keys, and wallet-adjacent helpers

## Read The Failure Contract Too

For boundary-heavy surfaces, open the hostile example immediately after the happy-path example.

Useful first hostile examples:

- [nip42_adversarial_example.zig](/workspace/projects/noztr/examples/nip42_adversarial_example.zig)
- [remote_signing_adversarial_example.zig](/workspace/projects/noztr/examples/remote_signing_adversarial_example.zig)
- [nip59_adversarial_example.zig](/workspace/projects/noztr/examples/nip59_adversarial_example.zig)
- [wallet_connect_adversarial_example.zig](/workspace/projects/noztr/examples/wallet_connect_adversarial_example.zig)
- [http_auth_adversarial_example.zig](/workspace/projects/noztr/examples/http_auth_adversarial_example.zig)

## Next Step

- For curated narrative routes, go to [technical-guides.md](/workspace/projects/noztr/docs/release/technical-guides.md)
- For full public surface coverage, go to [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md)
- For NIP-by-NIP coverage, go to [nip-coverage.md](/workspace/projects/noztr/docs/release/nip-coverage.md)
