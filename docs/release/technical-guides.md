---
title: Technical Guides
doc_type: release_guide_index
status: active
owner: noztr
read_when:
  - learning_noztr_by_job
  - finding_release_guides
  - onboarding_llms_and_humans
canonical: true
---

# Technical Guides

These are the public technical routes through the library.

They do not try to turn every supported NIP into a long-form narrative page. Instead:

- guides go deep where depth is useful
- reference pages cover the full supported surface
- examples and hostile examples show the exact usage and failure contract

Use this page when you know the job shape but not yet the exact symbol.

If you already know the symbol family, use
[api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md).
If you want a fast task-to-symbol route, use
[contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md).

Cross-cutting public notes:

- [errors-and-ownership.md](/workspace/projects/noztr/docs/release/errors-and-ownership.md)
- [performance.md](/workspace/projects/noztr/docs/release/performance.md)
- [stability-and-versioning.md](/workspace/projects/noztr/docs/release/stability-and-versioning.md)

## Core Protocol Flows

- strict event, filter, message, transcript, and checked-wrapper flow
  - guide entry: [core-api-contracts.md](/workspace/projects/noztr/docs/release/core-api-contracts.md)
  - example: [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig)
  - hostile example: [nip42_adversarial_example.zig](/workspace/projects/noztr/examples/nip42_adversarial_example.zig)

## Identity, Discovery, And Proofs

- NIP-05 identity parsing and bunker discovery
  - route: [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)
  - example: [discovery_recipe.zig](/workspace/projects/noztr/examples/discovery_recipe.zig)
  - hostile example: [nip05_adversarial_example.zig](/workspace/projects/noztr/examples/nip05_adversarial_example.zig)
- NIP-39 deterministic proof helpers
  - example: [identity_proof_recipe.zig](/workspace/projects/noztr/examples/identity_proof_recipe.zig)
  - hostile example: [identity_proof_adversarial_example.zig](/workspace/projects/noztr/examples/identity_proof_adversarial_example.zig)
- NIP-03 local OpenTimestamps verification floor
  - example: [nip03_verification_recipe.zig](/workspace/projects/noztr/examples/nip03_verification_recipe.zig)
  - hostile example: [nip03_adversarial_example.zig](/workspace/projects/noztr/examples/nip03_adversarial_example.zig)

## Signing, Wallet, And Private Material

- NIP-06 mnemonics, `nostr_keys`, and bounded BIP-85 helpers
  - route: [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md)
  - example: [wallet_recipe.zig](/workspace/projects/noztr/examples/wallet_recipe.zig)
  - references: [nip06_example.zig](/workspace/projects/noztr/examples/nip06_example.zig), [nostr_keys_example.zig](/workspace/projects/noztr/examples/nostr_keys_example.zig), [bip85_example.zig](/workspace/projects/noztr/examples/bip85_example.zig)
- NIP-49 private-key encryption
  - route: [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)
  - example: [nip49_example.zig](/workspace/projects/noztr/examples/nip49_example.zig)
  - hostile example: [private_key_encryption_adversarial_example.zig](/workspace/projects/noztr/examples/private_key_encryption_adversarial_example.zig)

## Private Messaging And Gift Wrap

- deterministic one-recipient outbound build and unwrap
  - route: [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)
  - example: [nip17_wrap_recipe.zig](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig)
  - hostile example: [nip59_adversarial_example.zig](/workspace/projects/noztr/examples/nip59_adversarial_example.zig)

## Remote Signing And Wallet Connect

- NIP-46 remote-signing URI and typed request/response contracts
  - route: [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)
  - example: [remote_signing_recipe.zig](/workspace/projects/noztr/examples/remote_signing_recipe.zig)
  - hostile example: [remote_signing_adversarial_example.zig](/workspace/projects/noztr/examples/remote_signing_adversarial_example.zig)
- NIP-47 Wallet Connect URI, envelope, and typed JSON contracts
  - route: [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)
  - example: [nip47_example.zig](/workspace/projects/noztr/examples/nip47_example.zig)
  - hostile example: [wallet_connect_adversarial_example.zig](/workspace/projects/noztr/examples/wallet_connect_adversarial_example.zig)

## HTTP Auth, Relay Admin, And Operational Boundaries

- NIP-98 HTTP auth event and header helpers
  - route: [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)
  - example: [nip98_example.zig](/workspace/projects/noztr/examples/nip98_example.zig)
  - hostile example: [http_auth_adversarial_example.zig](/workspace/projects/noztr/examples/http_auth_adversarial_example.zig)
- NIP-86 relay-admin JSON-RPC helpers
  - route: [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md)
  - example: [relay_admin_recipe.zig](/workspace/projects/noztr/examples/relay_admin_recipe.zig)
  - hostile example: [relay_admin_adversarial_example.zig](/workspace/projects/noztr/examples/relay_admin_adversarial_example.zig)

## Reducers, Media, Listings, And Specialized Surfaces

- NIP-29 reducer replay
  - route: [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md)
  - example: [nip29_reducer_recipe.zig](/workspace/projects/noztr/examples/nip29_reducer_recipe.zig)
  - hostile example: [nip29_adversarial_example.zig](/workspace/projects/noztr/examples/nip29_adversarial_example.zig)
- NIP-88 poll parse/build/tally
  - route: [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md)
  - example: [nip88_example.zig](/workspace/projects/noztr/examples/nip88_example.zig)
  - hostile example: [polls_adversarial_example.zig](/workspace/projects/noztr/examples/polls_adversarial_example.zig)
- media metadata, listings, Blossom helpers, code snippets, chess PGN
  - references: [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md), [nip-coverage.md](/workspace/projects/noztr/docs/release/nip-coverage.md)

## Full Coverage

These guides are selective. Full supported-surface coverage lives in:

- [api-reference.md](/workspace/projects/noztr/docs/release/api-reference.md)
- [nip-coverage.md](/workspace/projects/noztr/docs/release/nip-coverage.md)
- [examples/README.md](/workspace/projects/noztr/examples/README.md)
