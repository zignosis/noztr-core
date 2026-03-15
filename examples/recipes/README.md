# noztr Recipes

Scenario-oriented downstream examples for SDK consumers.

These recipes are intentionally organized by job, not by file-per-NIP. The goal is to help a
consumer decide "what do I open first?" and reach a working flow quickly.

## Start Here

- `sdk_consumer_smoke`
  - open [`../sdk_consumer_smoke/src/smoke.zig`](../sdk_consumer_smoke/src/smoke.zig)
  - use this first if you only need the package/dependency shape
- `recipes`
  - open [`src/discovery_recipe.zig`](src/discovery_recipe.zig) for identity/discovery flows
  - open [`src/wallet_recipe.zig`](src/wallet_recipe.zig) for NIP-06 and BIP-85 wallet flows
  - open [`src/remote_signing_recipe.zig`](src/remote_signing_recipe.zig) for NIP-46 connect flows
  - open [`src/private_lists_recipe.zig`](src/private_lists_recipe.zig) for NIP-51 private lists
  - open [`src/relay_admin_recipe.zig`](src/relay_admin_recipe.zig) for NIP-86 relay management
  - open [`src/identity_proof_recipe.zig`](src/identity_proof_recipe.zig) for NIP-39 proof helpers

## Boundary Notes

- These are `noztr` recipes, not `nzdk` workflows.
- They show deterministic parse/build/validate usage, not relay pools, HTTP fetch, or app state.
- If a recipe feels like it needs networking, retries, storage, or user interaction, that part
  likely belongs in `nzdk` or above it.
