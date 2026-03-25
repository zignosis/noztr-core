---
title: Migrating From 0.1.0-rc.5
doc_type: release_guide
status: active
owner: noztr
read_when:
  - updating_from_0_1_0_rc_5
  - adapting_to_recent_public_api_breaks
canonical: true
---

# Migrating From `0.1.0-rc.5`

This guide covers the current post-`v0.1.0-rc.5` route-local naming and surface-noise cleanup in `noztr-core`.

## Quick Path

If your project depends on `noztr-core`:

1. update explicit type and function references in the affected routes
2. rerun your normal build/test gates
3. refresh generated symbol indexes or local LLM context that still teach the older longer names

## Renamed Public Surface

### `nip37_drafts`

- `DraftWrapInfo` -> `Wrap`
- `DraftWrapPlaintextInfo` -> `Plaintext`
- `PrivateRelayListInfo` -> `PrivateRelayList`
- `draft_wrap_parse` -> `wrap_parse`
- `draft_wrap_decrypt_json` -> `wrap_decrypt_json`
- `draft_wrap_encrypt_json` -> `wrap_encrypt_json`
- `draft_build_*` -> `wrap_build_*`
- `private_relay_build_tag` -> `relay_build_tag`
- `private_relay_list_*` -> `relay_list_*`

### `nip45_count`

- `CountMetadata` -> `Metadata`
- `CountClientMessage` -> `ClientMessage`
- `CountRelayMessage` -> `RelayMessage`

### `nip23_long_form`

- `LongFormMetadata` -> `Metadata`

### `nip99_classified_listings`

- `ListingMetadata` -> `Metadata`
- `listing_kind_classify` -> `kind_classify`
- `listing_extract` -> `extract`
- `listing_build_*` -> `build_*`

### `nip23_long_form`

- `long_form_kind_classify` -> `kind_classify`
- `long_form_is_supported` -> `is_supported`
- `long_form_extract` -> `extract`
- `long_form_build_*` -> `build_*`

### `nip45_count`

- `count_client_message_parse` -> `client_message_parse`
- `count_relay_message_parse` -> `relay_message_parse`
- `count_metadata_validate` -> `metadata_validate`

### `nip98_http_auth`

- `http_auth_is_supported` -> `is_supported`
- `http_auth_extract` -> `extract`
- `http_auth_validate_request` -> `validate_request`
- `http_auth_verify_request` -> `verify_request`
- `http_auth_parse_authorization_header` -> `parse_authorization_header`
- `http_auth_decode_authorization_header` -> `decode_authorization_header`
- `http_auth_decode_base64_event_json` -> `decode_base64_event_json`
- `http_auth_parse_authorization_header_event` -> `parse_authorization_header_event`
- `http_auth_verify_authorization_header` -> `verify_authorization_header`
- `http_auth_build_*` -> `build_*`
- `http_auth_payload_sha256_hex` -> `payload_sha256_hex`
- `http_auth_encode_event_json_base64` -> `encode_event_json_base64`
- `http_auth_format_authorization_header` -> `format_authorization_header`
- `http_auth_encode_authorization_header` -> `encode_authorization_header`

### `nip53_live_activities`

- `LiveActivityCoordinate` -> `Coordinate`
- `LiveChatReply` -> `Reply`

### `nip09_delete`

- `DeleteAddressCoordinate` -> `AddressCoordinate`

### `nip72_moderated_communities`

- `CommunityCoordinate` -> `Coordinate`
- `AddressableTarget` -> `Target`
- `CommunityModerator` -> `Moderator`
- `CommunityRelay` -> `Relay`
- `community_extract` -> `extract`
- `community_post_extract` -> `post_extract`
- `community_approval_extract` -> `approval_extract`
- `community_build_*` -> `build_*`
- `community_post_build_*` -> `post_build_*`
- `community_approval_build_*` -> `approval_build_*`

### `nip46_remote_signing`

- `ConnectParams` -> `Connect`
- `PubkeyTextParams` -> `PubkeyText`
- `ParsedRequest` -> `TypedRequest`

### `nip47_wallet_connect`

- `connection_uri_parse` -> `uri_parse`
- `connection_uri_serialize` -> `uri_serialize`
- `info_event_extract` -> `info_extract`
- `request_event_extract` -> `request_extract`
- `response_event_extract` -> `response_extract`
- `notification_event_extract` -> `notification_extract`
- `nwc_build_*` -> `build_*`
- `nwc_format_info_capabilities` -> `format_info_capabilities`

## Scope

This is naming and surface-noise cleanup only.

The grouped routes stay the same.
Wire behavior, trust-boundary behavior, and ownership posture are unchanged.

If you are also updating from older release candidates, apply the earlier migration guides first:

- [migrating-from-0.1.0-rc.1.md](migrating-from-0.1.0-rc.1.md)
- [migrating-from-0.1.0-rc.2.md](migrating-from-0.1.0-rc.2.md)
- [migrating-from-0.1.0-rc.3.md](migrating-from-0.1.0-rc.3.md)
- [migrating-from-0.1.0-rc.4.md](migrating-from-0.1.0-rc.4.md)
