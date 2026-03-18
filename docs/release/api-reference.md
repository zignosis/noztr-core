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

This is the public module-and-symbol reference for the exported `noztr` surface.

Use it when you want to browse the library by module instead of by task.

If you already know the task but not the module, start with
[contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md) or
[technical-guides.md](/workspace/projects/noztr/docs/release/technical-guides.md) first.

Cross-cutting release notes:

- [errors-and-ownership.md](/workspace/projects/noztr/docs/release/errors-and-ownership.md)
- [performance.md](/workspace/projects/noztr/docs/release/performance.md)
- [stability-and-versioning.md](/workspace/projects/noztr/docs/release/stability-and-versioning.md)
- [examples/README.md](/workspace/projects/noztr/examples/README.md)

## Shared Foundations

| Export | Purpose | Start example |
| --- | --- | --- |
| `limits` | shared strict limits used across the library | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `errors` | shared typed error namespace for common surfaces | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `nostr_keys` | bounded key derivation and event-signing helpers | [nostr_keys_example.zig](/workspace/projects/noztr/examples/nostr_keys_example.zig) |
| `bip85_derivation` | bounded Nostr-relevant BIP-85 helpers | [bip85_example.zig](/workspace/projects/noztr/examples/bip85_example.zig) |

## High-Value Symbol Starting Points

These are the quickest symbol-level routes into the modules most downstream users reach for first.

### `nip01_event`

- `event_parse_json`
  - parse a full event object from JSON
- `event_serialize_json_object`
  - serialize a full signed event object as JSON
- `event_serialize_json_object_unsigned`
  - serialize a full unsigned event object with `id` but without `sig`
- `event_verify`
  - verify event integrity and signature assumptions
- start example:
  - [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig)
- broader route:
  - [core-api-contracts.md](/workspace/projects/noztr/docs/release/core-api-contracts.md)

### `nip46_remote_signing`

- `uri_parse`
  - parse a `nostrconnect:` URI
- `uri_serialize`
  - format a canonical remote-signing URI
- `message_parse_json`
  - parse typed remote-signing message envelopes
- `request_build_*`
  - build typed request payloads
- `request_parse_typed`
  - parse typed inbound request bodies
- `response_result_*`
  - build typed successful response payloads
- start example:
  - [remote_signing_recipe.zig](/workspace/projects/noztr/examples/remote_signing_recipe.zig)
- hostile example:
  - [remote_signing_adversarial_example.zig](/workspace/projects/noztr/examples/remote_signing_adversarial_example.zig)
- broader route:
  - [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)

### `nip47_wallet_connect`

- `connection_uri_parse`
  - parse a Wallet Connect URI
- `connection_uri_format`
  - format a canonical Wallet Connect URI
- `request_event_extract`
  - extract typed request context from an event
- `response_event_extract`
  - extract typed response context from an event
- `notification_event_extract`
  - extract typed notification context from an event
- `request_parse_json`
  - parse typed request JSON content
- `response_parse_json`
  - parse typed response JSON content
- start example:
  - [nip47_example.zig](/workspace/projects/noztr/examples/nip47_example.zig)
- hostile example:
  - [wallet_connect_adversarial_example.zig](/workspace/projects/noztr/examples/wallet_connect_adversarial_example.zig)
- broader route:
  - [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)

### `nip59_wrap`

- `nip59_build_outbound_for_recipient`
  - build one deterministic one-recipient `rumor -> seal -> wrap` transcript
- `nip59_unwrap`
  - unwrap an inbound wrap into the typed kernel payload
- start example:
  - [nip17_wrap_recipe.zig](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig)
- hostile example:
  - [nip59_adversarial_example.zig](/workspace/projects/noztr/examples/nip59_adversarial_example.zig)
- broader route:
  - [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)

### `nip17_private_messages`

- `nip17_message_parse`
  - parse kind-14 direct-message rumors
- `nip17_file_message_parse`
  - parse kind-15 file-message rumors and required file metadata
- `nip17_unwrap_message` / `nip17_unwrap_file_message`
  - unwrap a gift wrap and parse the inner direct-message or file-message rumor
- `nip17_build_recipient_tag` / `nip17_build_relay_tag`
  - build canonical recipient and relay tags
- `nip17_build_file_*_tag`
  - build canonical file-message metadata tags for required and optional kind-15 file metadata
- start example:
  - [nip17_example.zig](/workspace/projects/noztr/examples/nip17_example.zig)
  - [nip17_wrap_recipe.zig](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig)
- hostile example:
  - [nip17_adversarial_example.zig](/workspace/projects/noztr/examples/nip17_adversarial_example.zig)
  - [nip59_adversarial_example.zig](/workspace/projects/noztr/examples/nip59_adversarial_example.zig)
- broader route:
  - [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)

### `nip98_http_auth`

- `http_auth_extract`
  - extract typed auth state from an event
- `http_auth_validate_request`
  - validate request fields against the auth event
- `http_auth_verify_request`
  - verify the full auth event and request relationship
- `http_auth_parse_authorization_header`
  - parse an `Authorization` header into typed auth state
- `http_auth_verify_authorization_header`
  - verify a full header-driven auth flow
- `http_auth_build_*`
  - build typed auth tags and request-facing artifacts
- start example:
  - [nip98_example.zig](/workspace/projects/noztr/examples/nip98_example.zig)
- hostile example:
  - [http_auth_adversarial_example.zig](/workspace/projects/noztr/examples/http_auth_adversarial_example.zig)
- broader route:
  - [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)

### `nip05_identity`

- `address_parse`
  - parse a NIP-05 address into typed local and domain parts
- `address_compose_well_known_url`
  - render the canonical `nostr.json` discovery URL
- `profile_parse_json`
  - parse typed profile records from `nostr.json`
- `profile_verify_json`
  - verify a NIP-05 name against the parsed profile set
- `discovery_parse_well_known`
  - parse typed bunker-discovery metadata from `nostr.json`
- `discovery_render_nostrconnect_url`
  - render a deterministic `nostrconnect:` URL from parsed discovery data
- start example:
  - [discovery_recipe.zig](/workspace/projects/noztr/examples/discovery_recipe.zig)
- hostile example:
  - [nip05_adversarial_example.zig](/workspace/projects/noztr/examples/nip05_adversarial_example.zig)
- broader route:
  - [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md)

### `nip06_mnemonic` and `nostr_keys`

- `mnemonic_validate`
  - validate a mnemonic phrase before derivation
- `derive_nostr_secret_key`
  - derive a deterministic Nostr secret key from mnemonic material
- `nostr_derive_public_key`
  - derive an x-only public key from a secret key
- `nostr_sign_event`
  - sign a bounded event with explicit secret-key input
- start examples:
  - [wallet_recipe.zig](/workspace/projects/noztr/examples/wallet_recipe.zig)
  - [nostr_keys_example.zig](/workspace/projects/noztr/examples/nostr_keys_example.zig)
- broader route:
  - [technical-guides.md](/workspace/projects/noztr/docs/release/technical-guides.md)

### `nip42_auth` and `nip70_protected`

- `auth_validate_event`
  - verify an auth event against the expected challenge and relay
- `auth_state_set_challenge`
  - freeze the expected auth challenge into explicit state
- `auth_state_accept_event`
  - validate and accept an auth event into authenticated state
- `auth_state_is_pubkey_authenticated`
  - check whether one pubkey has already been authenticated
- `protected_event_validate`
  - validate protected-event policy expectations
- start examples:
  - [nip42_example.zig](/workspace/projects/noztr/examples/nip42_example.zig)
  - [nip70_example.zig](/workspace/projects/noztr/examples/nip70_example.zig)
- hostile example:
  - [nip42_adversarial_example.zig](/workspace/projects/noztr/examples/nip42_adversarial_example.zig)
- broader route:
  - [core-api-contracts.md](/workspace/projects/noztr/docs/release/core-api-contracts.md)

### `nip49_private_key_encryption`

- `nip49_encrypt`
  - encrypt a secret key into the typed NIP-49 payload form
- `nip49_decrypt`
  - decrypt and verify a typed NIP-49 payload
- `nip49_parse_bytes`
  - parse a fixed 91-byte NIP-49 payload into typed state
- `nip49_encode_bech32` / `nip49_decode_bech32`
  - serialize and parse the canonical `ncryptsec` bech32 form
- start example:
  - [nip49_example.zig](/workspace/projects/noztr/examples/nip49_example.zig)
- hostile example:
  - [private_key_encryption_adversarial_example.zig](/workspace/projects/noztr/examples/private_key_encryption_adversarial_example.zig)
- broader route:
  - [technical-guides.md](/workspace/projects/noztr/docs/release/technical-guides.md)

### `nip11`

- `nip11_parse_document`
  - parse a relay information document into typed state
- `nip11_validate_known_fields`
  - validate parsed known fields and limitation ranges
- start example:
  - [nip11_example.zig](/workspace/projects/noztr/examples/nip11_example.zig)
- broader route:
  - [technical-guides.md](/workspace/projects/noztr/docs/release/technical-guides.md)

### `nip29_relay_groups`

- `group_state_apply_events`
  - apply a bounded event batch into group state
- reducer helpers around metadata, membership, moderation, and snapshot replay
- start example:
  - [nip29_reducer_recipe.zig](/workspace/projects/noztr/examples/nip29_reducer_recipe.zig)
- hostile example:
  - [nip29_adversarial_example.zig](/workspace/projects/noztr/examples/nip29_adversarial_example.zig)

### `nip31_alt_tags`

- `alt_extract`
  - extract the strict `alt` fallback summary from an event
- `alt_build_tag`
  - build the canonical fallback-summary tag for unknown or custom kinds
- start example:
  - [nip31_example.zig](/workspace/projects/noztr/examples/nip31_example.zig)

### `nip88_polls`

- poll metadata parse/build helpers
- response extraction helpers
- tally reduction helpers
- start example:
  - [nip88_example.zig](/workspace/projects/noztr/examples/nip88_example.zig)
- hostile example:
  - [polls_adversarial_example.zig](/workspace/projects/noztr/examples/polls_adversarial_example.zig)

### `nip34_git`

- `repository_announcement_extract`
  - extract bounded repository announcement metadata
- `repository_state_extract`
  - extract bounded repository state refs and `HEAD`
- `user_grasp_list_extract`
  - extract bounded grasp server URLs
- `repository_build_*`
  - build canonical repository announcement and state tags
- start example:
  - [nip34_example.zig](/workspace/projects/noztr/examples/nip34_example.zig)

### `nip52_calendar_events`

- `date_calendar_event_extract` / `time_calendar_event_extract`
  - extract bounded metadata from date-based and time-based calendar events
- `calendar_extract`
  - extract bounded calendar collection metadata
- `calendar_rsvp_extract`
  - extract bounded RSVP metadata and status
- `calendar_build_*`
  - build canonical calendar, participant, coordinate, and status tags
- start example:
  - [nip52_example.zig](/workspace/projects/noztr/examples/nip52_example.zig)

### `nip53_live_activities`

- `live_activity_extract`
  - extract bounded live-stream metadata and participants
- `live_chat_extract`
  - extract the live-activity coordinate addressed by a live-chat event
- `live_activity_build_*`
  - build canonical live-stream metadata tags
- `live_chat_build_activity_tag`
  - build the required live-chat activity reference tag
- start example:
  - [nip53_example.zig](/workspace/projects/noztr/examples/nip53_example.zig)

### `nip54_wiki`

- `wiki_article_extract`
  - extract bounded wiki article metadata plus fork/defer references
- `wiki_merge_request_extract`
  - extract bounded wiki merge-request metadata
- `wiki_redirect_extract`
  - extract bounded redirect metadata
- `wiki_normalize_identifier_ascii`
  - normalize an ASCII-heavy wiki title into a `d` identifier slug
- `wiki_build_*`
  - build canonical wiki article, event, and destination tags
- start example:
  - [nip54_example.zig](/workspace/projects/noztr/examples/nip54_example.zig)

### `nip78_app_data`

- `app_data_is_supported`
  - check whether an event is the narrow `kind:30078` app-data surface
- `app_data_extract`
  - extract the required `d` identifier and opaque content
- `app_data_build_identifier_tag`
  - build the required canonical identifier tag
- start example:
  - [nip78_example.zig](/workspace/projects/noztr/examples/nip78_example.zig)

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
| `nip31_alt_tags` | `alt` fallback-summary extraction and build helpers | [nip31_example.zig](/workspace/projects/noztr/examples/nip31_example.zig) |
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
| `nip34_git` | bounded git repository metadata and state helpers | [nip34_example.zig](/workspace/projects/noztr/examples/nip34_example.zig) |
| `nip52_calendar_events` | calendar event, calendar, and RSVP helpers | [nip52_example.zig](/workspace/projects/noztr/examples/nip52_example.zig) |
| `nip53_live_activities` | bounded live-activity and live-chat helpers | [nip53_example.zig](/workspace/projects/noztr/examples/nip53_example.zig) |
| `nip54_wiki` | wiki article, merge-request, and redirect helpers | [nip54_example.zig](/workspace/projects/noztr/examples/nip54_example.zig) |
| `nip78_app_data` | narrow opaque app-data helpers for `kind:30078` | [nip78_example.zig](/workspace/projects/noztr/examples/nip78_example.zig) |
| `nip88_polls` | poll parse/build/tally helpers | [nip88_example.zig](/workspace/projects/noztr/examples/nip88_example.zig) |
| `nip92_media_attachments` | inline media metadata helpers | [nip92_example.zig](/workspace/projects/noztr/examples/nip92_example.zig) |
| `nip94_file_metadata` | file metadata helpers | [nip94_example.zig](/workspace/projects/noztr/examples/nip94_example.zig) |
| `nip99_classified_listings` | classified listing metadata helpers | [nip99_example.zig](/workspace/projects/noztr/examples/nip99_example.zig) |
| `nipb7_blossom_servers` | deterministic Blossom server-list and fallback helpers | [nipb7_example.zig](/workspace/projects/noztr/examples/nipb7_example.zig) |
| `nipc0_code_snippets` | code-snippet metadata helpers | [nipc0_example.zig](/workspace/projects/noztr/examples/nipc0_example.zig) |

## Coverage Note

For a NIP-by-NIP view of support, examples, and optional/gated surfaces, use
[nip-coverage.md](/workspace/projects/noztr/docs/release/nip-coverage.md).

For task-first routing, use [contract-map.md](/workspace/projects/noztr/docs/release/contract-map.md).
