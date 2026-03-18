---
title: Public API Reference
doc_type: release_reference
status: active
owner: noztr
read_when:
  - browsing_public_modules
  - finding_symbols_by_module
  - covering_the_full_supported_surface
canonical: true
---

# Public API Reference

This is the public module-level reference for the exported `noztr` surface.

Use it when you want to browse the library by module instead of by task.

## Shared Foundations

| Export | Purpose | Start example |
| --- | --- | --- |
| `limits` | shared strict limits used across the library | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `errors` | shared typed error namespace for common surfaces | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `nostr_keys` | bounded key derivation and event-signing helpers | [nostr_keys_example.zig](/workspace/projects/noztr/examples/nostr_keys_example.zig) |
| `bip85_derivation` | bounded Nostr-relevant BIP-85 helpers | [bip85_example.zig](/workspace/projects/noztr/examples/bip85_example.zig) |

## Core Event, Filter, Message, And Boundary Helpers

| Export | Purpose | Start example |
| --- | --- | --- |
| `nip01_event` | event parse/serialize/verify/id helpers | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| `nip01_filter` | filter parse and event-matching helpers | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| `nip01_message` | client/relay message parse and serialization helpers | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `nip42_auth` | auth-event validation helpers | [nip42_example.zig](/workspace/projects/noztr/examples/nip42_example.zig) |
| `nip70_protected` | protected-event policy helpers | [nip70_example.zig](/workspace/projects/noztr/examples/nip70_example.zig) |
| `nip09_delete` | deletion-target extraction and applicability helpers | [nip09_example.zig](/workspace/projects/noztr/examples/nip09_example.zig) |
| `nip13_pow` | proof-of-work helpers | [nip13_example.zig](/workspace/projects/noztr/examples/nip13_example.zig) |
| `pow_meets_difficulty_verified_id` | checked PoW boundary wrapper | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `delete_extract_targets_checked` | checked delete extraction wrapper | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `transcript_mark_client_req` | transcript state helper for strict relay/client flow | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `transcript_apply_relay` | transcript relay-application helper | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |

## Identity, Addressing, And Discovery

| Export | Purpose | Start example |
| --- | --- | --- |
| `nip19_bech32` | bech32 entity encode/decode helpers | [nip19_example.zig](/workspace/projects/noztr/examples/nip19_example.zig) |
| `nip21_uri` | `nostr:` URI parse/build helpers | [nip21_example.zig](/workspace/projects/noztr/examples/nip21_example.zig) |
| `nip05_identity` | NIP-05 address and `nostr.json` verification helpers | [discovery_recipe.zig](/workspace/projects/noztr/examples/discovery_recipe.zig) |
| `nip39_external_identities` | deterministic identity-proof helpers | [identity_proof_recipe.zig](/workspace/projects/noztr/examples/identity_proof_recipe.zig) |
| `nip73_external_ids` | bounded external identifier helpers | [nip73_example.zig](/workspace/projects/noztr/examples/nip73_example.zig) |

## Lists, Tags, References, And Social Metadata

| Export | Purpose | Start example |
| --- | --- | --- |
| `nip02_contacts` | contact tag extraction/build helpers | [nip02_example.zig](/workspace/projects/noztr/examples/nip02_example.zig) |
| `nip10_threads` | thread/reply extraction helpers | [nip10_example.zig](/workspace/projects/noztr/examples/nip10_example.zig) |
| `nip18_reposts` | repost extraction/build helpers | [nip18_example.zig](/workspace/projects/noztr/examples/nip18_example.zig) |
| `nip22_comments` | comment target and linkage helpers | [nip22_example.zig](/workspace/projects/noztr/examples/nip22_example.zig) |
| `nip23_long_form` | long-form metadata helpers | [nip23_example.zig](/workspace/projects/noztr/examples/nip23_example.zig) |
| `nip24_extra_metadata` | extra metadata helpers | [nip24_example.zig](/workspace/projects/noztr/examples/nip24_example.zig) |
| `nip25_reactions` | reaction extraction/build helpers | [nip25_example.zig](/workspace/projects/noztr/examples/nip25_example.zig) |
| `nip27_references` | inline `nostr:` text reference extraction | [nip27_example.zig](/workspace/projects/noztr/examples/nip27_example.zig) |
| `nip32_labeling` | labeling helpers | [nip32_example.zig](/workspace/projects/noztr/examples/nip32_example.zig) |
| `nip36_content_warning` | content-warning helpers | [nip36_example.zig](/workspace/projects/noztr/examples/nip36_example.zig) |
| `nip51_lists` | bounded public/private list helpers | [nip51_example.zig](/workspace/projects/noztr/examples/nip51_example.zig) |
| `nip56_reporting` | reporting helpers | [nip56_example.zig](/workspace/projects/noztr/examples/nip56_example.zig) |
| `nip58_badges` | badge helpers | [nip58_example.zig](/workspace/projects/noztr/examples/nip58_example.zig) |
| `nip84_highlights` | highlight helpers | [nip84_example.zig](/workspace/projects/noztr/examples/nip84_example.zig) |
| `nipb0_web_bookmarking` | web-bookmark metadata helpers | [nipb0_example.zig](/workspace/projects/noztr/examples/nipb0_example.zig) |

## Relay, Admin, And Messaging-Oriented Surfaces

| Export | Purpose | Start example |
| --- | --- | --- |
| `nip11` | relay-info parse helpers | [nip11_example.zig](/workspace/projects/noztr/examples/nip11_example.zig) |
| `nip65_relays` | relay metadata helpers | [nip65_example.zig](/workspace/projects/noztr/examples/nip65_example.zig) |
| `nip86_relay_management` | relay-admin JSON-RPC helpers | [relay_admin_recipe.zig](/workspace/projects/noztr/examples/relay_admin_recipe.zig) |
| `nip46_remote_signing` | remote-signing URI, request, and response helpers | [remote_signing_recipe.zig](/workspace/projects/noztr/examples/remote_signing_recipe.zig) |
| `nip47_wallet_connect` | Wallet Connect URI, envelope, and JSON contract helpers | [nip47_example.zig](/workspace/projects/noztr/examples/nip47_example.zig) |
| `nip98_http_auth` | HTTP-auth event and header helpers | [nip98_example.zig](/workspace/projects/noztr/examples/nip98_example.zig) |

## Privacy, Encryption, And Delegation

| Export | Purpose | Start example |
| --- | --- | --- |
| `nip06_mnemonic` | mnemonic validation and derivation helpers | [wallet_recipe.zig](/workspace/projects/noztr/examples/wallet_recipe.zig) |
| `nip44` | encrypted direct-message primitives | [nip44_example.zig](/workspace/projects/noztr/examples/nip44_example.zig) |
| `nip49_private_key_encryption` | private-key encryption/decryption helpers | [nip49_example.zig](/workspace/projects/noztr/examples/nip49_example.zig) |
| `nip59_wrap` | gift-wrap build/unwrap helpers | [nip17_wrap_recipe.zig](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig) |
| `nip17_private_messages` | private-message boundary helpers | [nip17_example.zig](/workspace/projects/noztr/examples/nip17_example.zig) |
| `nip26_delegation` | delegation tag, signing, and verification helpers | [nip26_example.zig](/workspace/projects/noztr/examples/nip26_example.zig) |

## Reducers, Drafts, Search, And Optional Extensions

| Export | Purpose | Start example |
| --- | --- | --- |
| `nip29_relay_groups` | pure relay-group reducer helpers | [nip29_reducer_recipe.zig](/workspace/projects/noztr/examples/nip29_reducer_recipe.zig) |
| `nip37_drafts` | draft and private relay helpers | [nip37_example.zig](/workspace/projects/noztr/examples/nip37_example.zig) |
| `nip40_expire` | expiration helpers | [nip40_example.zig](/workspace/projects/noztr/examples/nip40_example.zig) |
| `nip45_count` | optional count helpers, build-flag gated | [nip45_example.zig](/workspace/projects/noztr/examples/nip45_example.zig) |
| `nip50_search` | optional search helpers, build-flag gated | [nip50_example.zig](/workspace/projects/noztr/examples/nip50_example.zig) |
| `nip77_negentropy` | optional negentropy helpers, build-flag gated | [nip77_example.zig](/workspace/projects/noztr/examples/nip77_example.zig) |

## Media, Listings, Polls, Blossom, And Other Specialized Surfaces

| Export | Purpose | Start example |
| --- | --- | --- |
| `nip03_opentimestamps` | bounded OpenTimestamps parsing and local verification floor | [nip03_example.zig](/workspace/projects/noztr/examples/nip03_example.zig) |
| `nip57_zaps` | zap-related helpers | [nip57_example.zig](/workspace/projects/noztr/examples/nip57_example.zig) |
| `nip64_chess_pgn` | chess PGN note helpers | [nip64_example.zig](/workspace/projects/noztr/examples/nip64_example.zig) |
| `nip88_polls` | poll parse/build/tally helpers | [nip88_example.zig](/workspace/projects/noztr/examples/nip88_example.zig) |
| `nip92_media_attachments` | inline media metadata helpers | [nip92_example.zig](/workspace/projects/noztr/examples/nip92_example.zig) |
| `nip94_file_metadata` | file metadata helpers | [nip94_example.zig](/workspace/projects/noztr/examples/nip94_example.zig) |
| `nip99_classified_listings` | classified listing metadata helpers | [nip99_example.zig](/workspace/projects/noztr/examples/nip99_example.zig) |
| `nipb7_blossom_servers` | deterministic Blossom server-list and fallback helpers | [nipb7_example.zig](/workspace/projects/noztr/examples/nipb7_example.zig) |
| `nipc0_code_snippets` | code-snippet metadata helpers | [nipc0_example.zig](/workspace/projects/noztr/examples/nipc0_example.zig) |

## Coverage Note

For a NIP-by-NIP view of support, examples, and optional/gated surfaces, use
[nip-coverage.md](/workspace/projects/noztr/docs/release/nip-coverage.md).
