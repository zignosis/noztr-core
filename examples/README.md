# noztr-core Examples

Downstream consumption examples for `noztr-sdk`, other SDKs, and application authors.

These examples are intentionally technical and direct. They are not only "happy path" demos.
Where a surface is trust-boundary-heavy, the example set should also grow hostile or invalid
fixtures so SDK and app authors can see what `noztr-core` rejects and why.

## Related Public Docs

Use these docs when you need routing or contract context before opening a file:

- [getting-started.md](../docs/getting-started.md)
- [technical-guides.md](../docs/guides/technical-guides.md)
- [core-api-contracts.md](../docs/reference/core-api-contracts.md)
- [contract-map.md](../docs/reference/contract-map.md)
- [api-reference.md](../docs/reference/api-reference.md)
- [docs-style-guide.md](../docs/guides/docs-style-guide.md)
- [nip-coverage.md](../docs/reference/nip-coverage.md)
- [errors-and-ownership.md](../docs/errors-and-ownership.md)
- [performance.md](../docs/performance.md)
- [stability-and-versioning.md](../docs/stability-and-versioning.md)
- [compatibility-and-support.md](../docs/compatibility-and-support.md)

If you know the job but not the symbol, start with
[technical-guides.md](../docs/guides/technical-guides.md) or
[contract-map.md](../docs/reference/contract-map.md).
If you already know the symbol family, use
[api-reference.md](../docs/reference/api-reference.md).

## Start Here

- `consumer_smoke.zig`
  - minimal package/import check
- `strict_core_recipe.zig`
  - best first entry point for strict event, message, transcript, and wrapper flows
- `remote_signing_recipe.zig`
  - best first entry point for `noztr-sdk` signer/session work
- `wallet_recipe.zig`
  - best first entry point for deterministic wallet flows
- `discovery_recipe.zig`
  - best first entry point for identity lookup and bunker discovery

## Public Symbol Routing

Use this when you already know the job and want the exact `noztr-core` symbol family before
opening a file.

| Job | Primary public symbols | Start file | Hostile / failure fixture |
| --- | --- | --- | --- |
| Identity lookup and bunker discovery | `address_parse`, `address_compose_well_known_url`, `profile_parse_json`, `profile_verify_json`, `discovery_parse_well_known`, `discovery_render_nostrconnect_url` | `discovery_recipe.zig` | `nip05_adversarial_example.zig` |
| Remote-signing requests, URIs, and typed responses | `uri_parse`, `uri_serialize`, `message_parse_json`, `request_build_*`, `request_parse_typed`, `response_result_*`, `discovery_parse_*` | `remote_signing_recipe.zig` | `remote_signing_adversarial_example.zig` |
| Legacy kind-4 DM crypto and event-shape validation | `nip04_get_shared_secret`, `nip04_encrypt`, `nip04_decrypt`, `nip04_payload_parse`, `nip04_message_parse`, `nip04_build_recipient_tag` | `nip04_dm_recipe.zig` | `nip04_adversarial_example.zig` |
| One-recipient gift-wrap outbound build and unwrap | `nip59_build_outbound_for_recipient`, `nip59_unwrap`, `nip17_unwrap_message`, `nip17_build_recipient_tag`, `nip17_relay_list_extract` | `nip17_wrap_recipe.zig` | `nip59_adversarial_example.zig` |
| File-message parse and deterministic tag building | `nip17_file_message_parse`, `nip17_unwrap_file_message`, `nip17_build_file_*_tag` | `nip17_example.zig` | `nip17_adversarial_example.zig` |
| Wallet Connect envelope and JSON helpers | `connection_uri_parse`, `connection_uri_serialize`, `request_event_extract`, `response_event_extract`, `notification_event_extract`, `request_parse_json`, `response_parse_json` | `nip47_example.zig` | `wallet_connect_adversarial_example.zig` |
| Relay-admin JSON-RPC helpers | `method_parse`, `request_parse_json`, `request_serialize_json`, `response_parse_json`, `response_serialize_json` | `relay_admin_recipe.zig` | `relay_admin_adversarial_example.zig` |
| Relay discovery metadata and monitor announcements | `relay_discovery_extract`, `relay_monitor_extract`, `relay_discovery_build_*`, `relay_monitor_build_*` | `nip66_example.zig` | `nip66_adversarial_example.zig` |
| HTTP auth event and header helpers | `http_auth_extract`, `http_auth_validate_request`, `http_auth_verify_request`, `http_auth_parse_authorization_header`, `http_auth_verify_authorization_header`, `http_auth_build_*` | `nip98_example.zig` | `http_auth_adversarial_example.zig` |
| Subject tags for kind-1 text notes | `subject_extract`, `subject_build_tag` | `nip14_example.zig` | none |
| Public-channel metadata, linkage, and moderation tags | `channel_*_extract`, `channel_build_*`, `channel_metadata_parse_json` | `nip28_example.zig` | `nip28_adversarial_example.zig` |
| Custom emoji tag parsing and build helpers | `emoji_tag_extract`, `emoji_shortcode_from_token`, `emoji_build_tag` | `nip30_example.zig` | none |
| Unknown/custom-kind fallback summaries | `alt_extract`, `alt_build_tag` | `nip31_example.zig` | none |
| User-status metadata and linkage tags | `user_status_extract`, `user_status_build_*` | `nip38_example.zig` | none |
| Video-event metadata, variant fields, and imported-origin tags | `video_extract`, `video_build_*`, `video_build_duration_field`, `video_build_bitrate_field` | `nip71_example.zig` | none |
| Moderated-community definitions, post linkage, and approval contracts | `community_extract`, `community_post_extract`, `community_approval_extract`, `community_*_build_*` | `nip72_example.zig` | `nip72_adversarial_example.zig` |
| Git repository metadata and state tags | `repository_announcement_extract`, `repository_state_extract`, `repository_build_*` | `nip34_example.zig` | none |
| Calendar event, collection, and RSVP metadata | `date_calendar_event_extract`, `time_calendar_event_extract`, `calendar_rsvp_extract`, `calendar_build_*` | `nip52_example.zig` | none |
| Live activity metadata and chat activity addressing | `live_activity_extract`, `live_chat_extract`, `live_activity_build_*`, `live_chat_build_activity_tag` | `nip53_example.zig` | none |
| Wiki article, merge-request, and redirect metadata | `wiki_article_extract`, `wiki_merge_request_extract`, `wiki_redirect_extract`, `wiki_build_*` | `nip54_example.zig` | none |
| Nutzap informational, event, and redemption-marker contracts | `informational_extract`, `nutzap_extract`, `redemption_extract`, `*_build_*` | `nip61_example.zig` | `nip61_adversarial_example.zig` |
| Zap-goal metadata and goal-reference tags | `goal_extract`, `goal_reference_extract`, `goal_build_*` | `nip75_example.zig` | none |
| Opaque app-data `kind:30078` helpers | `app_data_extract`, `app_data_build_identifier_tag` | `nip78_example.zig` | none |
| Handler recommendations, endpoints, and client tags | `recommendation_extract`, `handler_extract`, `client_extract`, `*_build_*` | `nip89_example.zig` | `nip89_adversarial_example.zig` |

## SDK Job Index

- signer/bootstrap handoff:
  - `remote_signing_recipe.zig`
  - `nip46_example.zig`
  - `remote_signing_adversarial_example.zig`
- strict core trust-boundary flows:
  - `strict_core_recipe.zig`
  - `nip01_example.zig`
  - `nip01_adversarial_example.zig`
  - `nip42_example.zig`
  - `nip42_adversarial_example.zig`
  - `nip70_example.zig`
  - `nip13_example.zig`
  - `nip09_example.zig`
- mailbox/private-message handoff:
  - `nip04_dm_recipe.zig`
    - symbols: `nip04_encrypt`, `nip04_decrypt`, `nip04_message_parse`
  - `nip04_example.zig`
  - `nip04_adversarial_example.zig`
  - `nip17_wrap_recipe.zig`
    - symbols: `nip59_build_outbound_for_recipient`, `nip17_unwrap_message`
  - `nip17_example.zig`
  - `nip17_adversarial_example.zig`
  - `nip59_example.zig`
    - typed boundary example for invalid outer-wrap shape only
  - `nip59_adversarial_example.zig`
- group-state replay handoff:
  - `nip29_reducer_recipe.zig`
  - `nip29_example.zig`
  - `nip29_adversarial_example.zig`
- identity lookup and proof flows:
  - `discovery_recipe.zig`
    - symbols: `address_parse`, `address_compose_well_known_url`, `profile_parse_json`,
      `profile_verify_json`, `discovery_parse_well_known`, `discovery_render_nostrconnect_url`
  - `identity_proof_recipe.zig`
  - `nip05_example.zig`
  - `nip05_adversarial_example.zig`
  - `nip39_example.zig`
  - `identity_proof_adversarial_example.zig`
- local attestation verification:
  - `nip03_verification_recipe.zig`
  - `nip03_example.zig`
  - `nip03_adversarial_example.zig`
- deterministic wallet flows:
  - `wallet_recipe.zig`
  - `nip06_example.zig`
  - `nip47_example.zig`
  - `nip49_example.zig`
  - `bip85_example.zig`
  - `nostr_keys_example.zig`
- wallet-connect kernel helpers:
  - `nip47_example.zig`
  - `wallet_connect_adversarial_example.zig`
- media metadata and inline attachments:
  - `nip92_example.zig`
  - `nip94_example.zig`
  - `media_metadata_adversarial_example.zig`
- private draft and relay-list storage:
  - `nip37_example.zig`
  - `nip37_adversarial_example.zig`
  - `private_lists_adversarial_example.zig`
- private list handling:
  - `private_lists_recipe.zig`
  - `nip51_example.zig`
  - `private_lists_adversarial_example.zig`
- relay admin helpers:
  - `relay_admin_recipe.zig`
  - `nip86_example.zig`
  - `relay_admin_adversarial_example.zig`
- HTTP auth helpers:
  - `nip98_example.zig`
  - `http_auth_adversarial_example.zig`
- Blossom server-list and fallback helpers:
  - `nipb7_example.zig`
  - `blossom_adversarial_example.zig`
- listings and metadata commerce helpers:
  - `nip99_example.zig`
  - `listings_adversarial_example.zig`
- web bookmark metadata helpers:
  - `nipb0_example.zig`
- chess PGN note helpers:
  - `nip64_example.zig`
  - `chess_pgn_adversarial_example.zig`
- poll metadata and tally helpers:
  - `nip88_example.zig`
  - `polls_adversarial_example.zig`
- private-key encryption boundary:
  - `nip49_example.zig`
  - `private_key_encryption_adversarial_example.zig`

## Reference Examples

Each implemented kernel NIP now has a direct reference example.

`NIP-91` is covered through the `NIP-01` filter example family, so its reference route is
`nip01_example.zig` rather than a separate dedicated `nip91_example.zig`.

- `nip01_example.zig`
- `nip01_adversarial_example.zig`
- `nip02_example.zig`
- `nip03_example.zig`
- `nip04_example.zig`
- `nip05_example.zig`
- `nip05_adversarial_example.zig`
- `nip06_example.zig`
- `nip09_example.zig`
- `nip10_example.zig`
- `nip11_example.zig`
- `nip13_example.zig`
- `nip14_example.zig`
- `nip17_example.zig`
- `nip18_example.zig`
- `nip19_example.zig`
- `nip21_example.zig`
- `nip22_example.zig`
- `nip23_example.zig`
- `nip24_example.zig`
- `nip25_example.zig`
- `nip27_example.zig`
- `nip28_example.zig`
- `nip29_example.zig`
- `nip29_reducer_recipe.zig`
- `nip30_example.zig`
- `nip31_example.zig`
- `nip32_example.zig`
- `nip36_example.zig`
- `nip37_example.zig`
- `nip38_example.zig`
- `nip39_example.zig`
- `nip40_example.zig`
- `nip42_example.zig`
- `nip44_example.zig`
- `nip46_example.zig`
- `nip47_example.zig`
- `nip49_example.zig`
- `nip98_example.zig`
- `nip51_example.zig`
- `nip52_example.zig`
- `nip53_example.zig`
- `nip54_example.zig`
- `nip56_example.zig`
- `nip57_example.zig`
- `nip58_example.zig`
- `nip59_example.zig`
  - typed boundary example; public outbound build stays deterministic and one-recipient only
  - successful deterministic outbound build lives in `nip17_wrap_recipe.zig`
- `nip61_example.zig`
- `nip64_example.zig`
- `nip88_example.zig`
- `nostr_keys_example.zig`
- `nip65_example.zig`
- `nip66_example.zig`
- `nip66_adversarial_example.zig`
- `nip70_example.zig`
- `nip71_example.zig`
- `nip72_example.zig`
- `nip73_example.zig`
- `nip75_example.zig`
- `nip78_example.zig`
- `nip89_example.zig`
- `nip84_example.zig`
- `nip86_example.zig`
- `nip92_example.zig`
- `nip94_example.zig`
- `nip99_example.zig`
- `nipb0_example.zig`
- `nipb7_example.zig`
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
- `strict_core_recipe.zig`
  - canonical event lifecycle, strict message grammar, transcript flow, and checked wrappers
- `identity_proof_recipe.zig`
  - NIP-39 proof URL and expected-text helpers
- `remote_signing_recipe.zig`
  - NIP-46 request, URI, and template composition
- `nip03_verification_recipe.zig`
  - NIP-03 extraction plus bounded local-proof verification
- `nip04_dm_recipe.zig`
  - `NIP-04` local encrypt/decrypt plus strict kind-4 event parse/verify flow
- `nip17_wrap_recipe.zig`
  - NIP-17 rumor construction, deterministic one-recipient seal/wrap transcript building, and unwrap
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
- `nip42_adversarial_example.zig`
  - mismatched relay challenge stays on typed `NIP-42` auth failures
- `nip03_adversarial_example.zig`
  - malformed OpenTimestamps proof payload stays on typed `InvalidBase64`
- `nip04_adversarial_example.zig`
  - malformed legacy payloads and duplicate recipient tags stay on typed `NIP-04` failures
- `nip17_adversarial_example.zig`
  - overlong recipient and relay builder input stays on typed `NIP-17` failures
- `nip37_adversarial_example.zig`
  - overlong private relay builder input stays on typed `InvalidPrivateRelayUrl`
- `nip59_adversarial_example.zig`
  - sender/rumor mismatch on outbound wrap construction stays on typed `InvalidRumorEvent`
- `nip05_adversarial_example.zig`
  - malformed matched pubkeys and relay maps stay on typed `NIP-05` failures
- `relay_admin_adversarial_example.zig`
- `nip72_adversarial_example.zig`
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
- `polls_adversarial_example.zig`
  - latest malformed same-poll responses suppress older votes and invalid response tags stay typed
- `private_key_encryption_adversarial_example.zig`
  - wrong passwords stay on `InvalidCiphertext` and invalid scrypt parameters stay typed
- `wallet_connect_adversarial_example.zig`
  - malformed NWC request bodies and mismatched notification shapes stay on typed failures
- `http_auth_adversarial_example.zig`
  - malformed `Authorization` values and noncanonical payload hashes stay on typed failures
- `nip28_adversarial_example.zig`
  - overlong channel reference builder input stays on typed `InvalidChannelTag`
- `nip61_adversarial_example.zig`
  - target kind without a target event stays on typed `TargetKindWithoutEvent`
- `nip89_adversarial_example.zig`
  - malformed client handler coordinates stay on typed `InvalidClientTag`
- `blossom_adversarial_example.zig`
  - malformed server URLs and query-bearing blob URLs stay on typed `NIP-B7` failures
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

That work belongs in `noztr-sdk` or above it.

## Example Quality Rule

For boundary-heavy surfaces, examples should not stop at valid flows. The preferred set is:
- one direct valid reference example
- one invalid or adversarial example fixture where misuse is plausible
- recipe coverage only when the surface materially affects SDK-facing handoff work

When the example policy gets stricter, recently added SDK-facing examples must be backfilled to the
new standard before the repo claims the stronger example baseline.
