# noztr Examples

Downstream consumption examples for SDK and application authors.

## Files

- `consumer_smoke.zig`
  - minimal package/import check
- `discovery_recipe.zig`
  - NIP-05 plus NIP-46 discovery parsing
- `wallet_recipe.zig`
  - NIP-06 and Nostr-focused BIP-85 helpers
- `identity_proof_recipe.zig`
  - NIP-39 proof URL and expected-text helpers
- `remote_signing_recipe.zig`
  - NIP-46 request/URI/template composition
- `private_lists_recipe.zig`
  - NIP-51 private-list JSON boundary
- `relay_admin_recipe.zig`
  - NIP-86 relay-management request/response helpers

## Boundary

These examples stay at the `noztr` layer:
- deterministic parsing
- deterministic building
- bounded validation

They intentionally do not show:
- relay pools
- HTTP fetch
- storage/state sync
- UI or session orchestration

That work belongs in `nzdk` or above it.
