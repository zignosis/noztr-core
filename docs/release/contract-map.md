---
title: Public Contract Map
doc_type: release_reference
status: active
owner: noztr
read_when:
  - routing_public_noztr_jobs
  - finding_post_core_symbols
  - onboarding_public_consumers
canonical: true
---

# Public Contract Map

This is the public task-to-symbol map for the main non-core `noztr` surfaces.

Use it when you know the job you want to do, but do not yet know which module or example to open.

## Routing Table

| Job | Module | Start here | Example | Hostile example |
| --- | --- | --- | --- | --- |
| Identity lookup and bunker discovery | `nip05_identity`, `nip46_remote_signing` | `noztr.nip05_identity`, `noztr.nip46_remote_signing` | [discovery_recipe.zig](/workspace/projects/noztr/examples/discovery_recipe.zig) | [nip05_adversarial_example.zig](/workspace/projects/noztr/examples/nip05_adversarial_example.zig) |
| Remote-signing requests, responses, URIs, and discovery | `nip46_remote_signing` | `noztr.nip46_remote_signing` | [remote_signing_recipe.zig](/workspace/projects/noztr/examples/remote_signing_recipe.zig) | [remote_signing_adversarial_example.zig](/workspace/projects/noztr/examples/remote_signing_adversarial_example.zig) |
| One-recipient gift-wrap outbound build and unwrap | `nip59_wrap`, `nip17_private_messages` | `noztr.nip59_wrap`, `noztr.nip17_private_messages` | [nip17_wrap_recipe.zig](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig) | [nip59_adversarial_example.zig](/workspace/projects/noztr/examples/nip59_adversarial_example.zig) |
| Wallet Connect URI, envelopes, and typed JSON contracts | `nip47_wallet_connect` | `noztr.nip47_wallet_connect` | [nip47_example.zig](/workspace/projects/noztr/examples/nip47_example.zig) | [wallet_connect_adversarial_example.zig](/workspace/projects/noztr/examples/wallet_connect_adversarial_example.zig) |
| Relay-admin JSON-RPC helpers | `nip86_relay_management` | `noztr.nip86_relay_management` | [relay_admin_recipe.zig](/workspace/projects/noztr/examples/relay_admin_recipe.zig) | [relay_admin_adversarial_example.zig](/workspace/projects/noztr/examples/relay_admin_adversarial_example.zig) |
| HTTP auth event and header helpers | `nip98_http_auth` | `noztr.nip98_http_auth` | [nip98_example.zig](/workspace/projects/noztr/examples/nip98_example.zig) | [http_auth_adversarial_example.zig](/workspace/projects/noztr/examples/http_auth_adversarial_example.zig) |
| Private-key encryption boundary | `nip49_private_key_encryption` | `noztr.nip49_private_key_encryption` | [nip49_example.zig](/workspace/projects/noztr/examples/nip49_example.zig) | [private_key_encryption_adversarial_example.zig](/workspace/projects/noztr/examples/private_key_encryption_adversarial_example.zig) |
| Group replay and poll tally reduction | `nip29_groups`, `nip88_polls` | `noztr.nip29_groups`, `noztr.nip88_polls` | [nip29_reducer_recipe.zig](/workspace/projects/noztr/examples/nip29_reducer_recipe.zig), [nip88_example.zig](/workspace/projects/noztr/examples/nip88_example.zig) | [nip29_adversarial_example.zig](/workspace/projects/noztr/examples/nip29_adversarial_example.zig), [polls_adversarial_example.zig](/workspace/projects/noztr/examples/polls_adversarial_example.zig) |

## Scope Note

These surfaces are still protocol-kernel helpers.

They do not own:

- network fetches
- session orchestration
- relay-management workflow
- storage or cache policy
- UI or application flow
