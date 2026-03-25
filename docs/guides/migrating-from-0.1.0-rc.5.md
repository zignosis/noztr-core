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

This guide covers the current post-`v0.1.0-rc.5` route-local type cleanup in `noztr-core`.

## Quick Path

If your project depends on `noztr-core`:

1. update explicit type references in the affected routes
2. rerun your normal build/test gates
3. refresh generated symbol indexes or local LLM context that still teach the older longer names

## Renamed Public Types

### `nip37_drafts`

- `DraftWrapInfo` -> `Wrap`
- `DraftWrapPlaintextInfo` -> `Plaintext`
- `PrivateRelayListInfo` -> `PrivateRelayList`

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

## Scope

This is naming and surface-noise cleanup only.

The grouped routes stay the same.
Wire behavior, trust-boundary behavior, and ownership posture are unchanged.

If you are also updating from older release candidates, apply the earlier migration guides first:

- [migrating-from-0.1.0-rc.1.md](migrating-from-0.1.0-rc.1.md)
- [migrating-from-0.1.0-rc.2.md](migrating-from-0.1.0-rc.2.md)
- [migrating-from-0.1.0-rc.3.md](migrating-from-0.1.0-rc.3.md)
- [migrating-from-0.1.0-rc.4.md](migrating-from-0.1.0-rc.4.md)
