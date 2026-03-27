---
title: Migrating From 0.1.0-rc.6
doc_type: release_guide
status: active
owner: noztr
read_when:
  - updating_from_0_1_0_rc_6
  - adapting_to_recent_public_api_breaks
canonical: true
---

# Migrating From `0.1.0-rc.6`

This guide covers the current post-`v0.1.0-rc.6` route-local cleanup in `noztr-core`.

## Quick Path

If your project depends on `noztr-core`:

1. update explicit function references in the affected routes
2. rerun your normal build/test gates
3. refresh generated symbol indexes or local LLM context that still teach the older longer names

## Renamed Public Surface

### `nip51_lists`

- `list_kind_classify` -> `kind_classify`
- `list_is_supported` -> `is_supported`
- `list_extract` -> `extract`
- `list_build_identifier_tag` -> `build_identifier_tag`
- `list_private_serialize_json` -> `private_serialize_json`
- `list_private_extract_json` -> `private_extract_json`
- `list_private_extract_nip44` -> `private_extract_nip44`

### `nip66_relay_discovery`

- `relay_discovery_extract` -> `discovery_extract`
- `relay_monitor_extract` -> `monitor_extract`
- `relay_discovery_build_*` -> `discovery_build_*`
- `relay_monitor_build_*` -> `monitor_build_*`

### `nip78_app_data`

- `app_data_is_supported` -> `is_supported`
- `app_data_extract` -> `extract`
- `app_data_build_identifier_tag` -> `build_identifier_tag`

### `nip34_git`

- `repository_announcement_extract` -> `announcement_extract`
- `repository_state_extract` -> `state_extract`
- `user_grasp_list_extract` -> `grasp_list_extract`
- `repository_build_*` -> `build_*`

### `nip64_chess_pgn`

- `chess_pgn_is_supported` -> `is_supported`
- `chess_pgn_extract` -> `extract`
- `chess_pgn_validate` -> `validate`
- `chess_pgn_build_alt_tag` -> `build_alt_tag`

### `nip11`

- `nip11_parse_document` -> `parse_document`
- `nip11_validate_known_fields` -> `validate_known_fields`

### `nip44`

- `nip44_get_conversation_key` -> `get_conversation_key`
- `nip44_calc_padded_plaintext_len` -> `calc_padded_plaintext_len`
- `nip44_encrypt_to_base64` -> `encrypt_to_base64`
- `nip44_encrypt_with_nonce_to_base64` -> `encrypt_with_nonce_to_base64`
- `nip44_decode_payload` -> `decode_payload`
- `nip44_decrypt_from_base64` -> `decrypt_from_base64`

### `nip59_wrap`

- `nip59_validate_wrap_structure` -> `validate_wrap_structure`
- `nip59_build_outbound_for_recipient` -> `build_outbound_for_recipient`
- `nip59_unwrap` -> `unwrap`

## Scope

This is route-local cleanup only.

The grouped routes stay the same.
Wire behavior, trust-boundary behavior, and ownership posture are unchanged.

If you are also updating from older release candidates, apply the earlier migration guides first:

- [migrating-from-0.1.0-rc.1.md](migrating-from-0.1.0-rc.1.md)
- [migrating-from-0.1.0-rc.2.md](migrating-from-0.1.0-rc.2.md)
- [migrating-from-0.1.0-rc.3.md](migrating-from-0.1.0-rc.3.md)
- [migrating-from-0.1.0-rc.4.md](migrating-from-0.1.0-rc.4.md)
- [migrating-from-0.1.0-rc.5.md](migrating-from-0.1.0-rc.5.md)
