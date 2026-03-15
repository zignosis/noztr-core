# noztr Examples

Downstream consumption examples for SDK and application authors.

## Start Here

- `consumer_smoke.zig`
  - minimal package/import check
- `remote_signing_recipe.zig`
  - best first entry point for `nzdk` signer/session work
- `wallet_recipe.zig`
  - best first entry point for deterministic wallet flows
- `discovery_recipe.zig`
  - best first entry point for identity lookup and bunker discovery

## Reference Examples

Each implemented kernel NIP now has a direct reference example.

- `nip01_example.zig`
- `nip02_example.zig`
- `nip03_example.zig`
- `nip05_example.zig`
- `nip06_example.zig`
- `nip09_example.zig`
- `nip10_example.zig`
- `nip11_example.zig`
- `nip13_example.zig`
- `nip17_example.zig`
- `nip18_example.zig`
- `nip19_example.zig`
- `nip21_example.zig`
- `nip22_example.zig`
- `nip23_example.zig`
- `nip24_example.zig`
- `nip25_example.zig`
- `nip26_example.zig`
- `nip27_example.zig`
- `nip29_example.zig`
- `nip32_example.zig`
- `nip36_example.zig`
- `nip37_example.zig`
- `nip39_example.zig`
- `nip40_example.zig`
- `nip42_example.zig`
- `nip44_example.zig`
- `nip46_example.zig`
- `nip51_example.zig`
- `nip56_example.zig`
- `nip57_example.zig`
- `nip58_example.zig`
- `nip59_example.zig`
  - typed boundary example; `noztr` does not expose a public gift-wrap builder
- `nip65_example.zig`
- `nip70_example.zig`
- `nip73_example.zig`
- `nip84_example.zig`
- `nip86_example.zig`
- optional I6 reference examples:
  - `nip45_example.zig`
  - `nip50_example.zig`
  - `nip77_example.zig`
- non-NIP deterministic wallet helper:
  - `bip85_example.zig`

## Scenario Recipes

The recipe files are slightly higher-level, but still stay inside `noztr` boundaries.

- `discovery_recipe.zig`
  - NIP-05 plus NIP-46 discovery parsing
- `wallet_recipe.zig`
  - NIP-06 plus Nostr-focused BIP-85 helpers
- `identity_proof_recipe.zig`
  - NIP-39 proof URL and expected-text helpers
- `remote_signing_recipe.zig`
  - NIP-46 request, URI, and template composition
- `private_lists_recipe.zig`
  - NIP-51 private-list JSON boundary
- `relay_admin_recipe.zig`
  - NIP-86 relay-management request and response helpers

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
