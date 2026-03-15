# noztr Examples

Downstream consumption examples for SDK and application authors.

These examples are intentionally technical and direct. They are not only "happy path" demos.
Where a surface is trust-boundary-heavy, the example set should also grow hostile or invalid
fixtures so SDK and app authors can see what `noztr` rejects and why.

## Start Here

- `consumer_smoke.zig`
  - minimal package/import check
- `remote_signing_recipe.zig`
  - best first entry point for `nzdk` signer/session work
- `wallet_recipe.zig`
  - best first entry point for deterministic wallet flows
- `discovery_recipe.zig`
  - best first entry point for identity lookup and bunker discovery

## SDK Job Index

- signer/bootstrap handoff:
  - `remote_signing_recipe.zig`
  - `nip46_example.zig`
  - `remote_signing_adversarial_example.zig`
- mailbox/private-message handoff:
  - `nip17_wrap_recipe.zig`
  - `nip17_example.zig`
- group-state replay handoff:
  - `nip29_reducer_recipe.zig`
  - `nip29_example.zig`
  - `nip29_adversarial_example.zig`
- identity lookup and proof flows:
  - `discovery_recipe.zig`
  - `identity_proof_recipe.zig`
  - `nip05_example.zig`
  - `nip39_example.zig`
  - `identity_proof_adversarial_example.zig`
- local attestation verification:
  - `nip03_verification_recipe.zig`
  - `nip03_example.zig`
- deterministic wallet flows:
  - `wallet_recipe.zig`
  - `nip06_example.zig`
  - `bip85_example.zig`
  - `nostr_keys_example.zig`
- media metadata and inline attachments:
  - `nip92_example.zig`
  - `nip94_example.zig`
  - `media_metadata_adversarial_example.zig`
- private draft and relay-list storage:
  - `nip37_example.zig`
  - `private_lists_adversarial_example.zig`
- private list handling:
  - `private_lists_recipe.zig`
  - `nip51_example.zig`
  - `private_lists_adversarial_example.zig`
- relay admin helpers:
  - `relay_admin_recipe.zig`
  - `nip86_example.zig`
  - `relay_admin_adversarial_example.zig`
- listings and metadata commerce helpers:
  - `nip99_example.zig`
  - `listings_adversarial_example.zig`
- web bookmark metadata helpers:
  - `nipb0_example.zig`
- chess PGN note helpers:
  - `nip64_example.zig`
  - `chess_pgn_adversarial_example.zig`

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
- `nip29_reducer_recipe.zig`
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
- `nip64_example.zig`
- `nostr_keys_example.zig`
- `nip65_example.zig`
- `nip70_example.zig`
- `nip73_example.zig`
- `nip84_example.zig`
- `nip86_example.zig`
- `nip92_example.zig`
- `nip94_example.zig`
- `nip99_example.zig`
- `nipb0_example.zig`
- `nipc0_example.zig`
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
- `nip03_verification_recipe.zig`
  - NIP-03 extraction plus bounded local-proof verification
- `nip17_wrap_recipe.zig`
  - NIP-17 rumor construction, signed seal/wrap transcript building, and unwrap
- `nip29_reducer_recipe.zig`
  - NIP-29 pure reducer replay across metadata, snapshot, and moderation events
- `private_lists_recipe.zig`
  - NIP-51 private-list JSON boundary
- `relay_admin_recipe.zig`
  - NIP-86 relay-management request and response helpers

## Adversarial Examples

These are the first files to open when you need the failure contract for a boundary-heavy surface.

- `remote_signing_adversarial_example.zig`
  - invalid `nostrconnect_url` template rendering
- `relay_admin_adversarial_example.zig`
  - invalid control text on NIP-86 serializer paths
- `private_lists_adversarial_example.zig`
  - deprecated NIP-04 private content and non-websocket private relays
- `identity_proof_adversarial_example.zig`
  - overlong NIP-39 identity inputs on typed builder paths
- `media_metadata_adversarial_example.zig`
  - missing `imeta` metadata and non-canonical file MIME values
- `listings_adversarial_example.zig`
  - invalid NIP-99 listing identifiers on both builder and extractor paths
- `code_snippet_adversarial_example.zig`
  - malformed NIP-C0 repository references rejected on both builder and extractor paths
- `chess_pgn_adversarial_example.zig`
  - malformed NIP-64 PGN structure rejected on both validator and metadata-builder paths
- `nip29_adversarial_example.zig`
  - mixed-group moderation replay rejected by the pure reducer

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

## Example Quality Rule

For boundary-heavy surfaces, examples should not stop at valid flows. The preferred set is:
- one direct valid reference example
- one invalid or adversarial example fixture where misuse is plausible
- recipe coverage only when the surface materially affects SDK-facing handoff work

When the example policy gets stricter, recently added SDK-facing examples must be backfilled to the
new standard before the repo claims the stronger example baseline.
