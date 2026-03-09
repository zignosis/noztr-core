# I7 API Contract Trace Checklist

Date: 2026-03-08

Purpose: trace each currently implemented public API to its concrete implementation symbol and a
direct module test invocation.

Status key: `covered` means API symbol exists and is exercised by a direct module test call.

| API | Implementation ref | Direct test ref | Status |
| --- | --- | --- | --- |
| `nip01_event.event_parse_json` | `src/nip01_event.zig:49` | `src/nip01_event.zig:1092` | covered |
| `nip01_event.event_serialize_canonical` | `src/nip01_event.zig:193` | `src/nip01_event.zig:862` | covered |
| `nip01_event.event_serialize_canonical_json` | `src/nip01_event.zig:203` | `src/nip01_event.zig:1409` | covered |
| `nip01_event.event_compute_id` | `src/nip01_event.zig:239` | `src/nip01_event.zig:1424` | covered |
| `nip01_event.event_compute_id_checked` | `src/nip01_event.zig:247` | `src/nip01_event.zig:1405` | covered |
| `nip01_event.event_verify_id` | `src/nip01_event.zig:278` | `src/nip01_event.zig:1411` | covered |
| `nip01_event.event_verify_id_checked` | `src/nip01_event.zig:287` | `src/nip01_event.zig:1406` | covered |
| `nip01_event.event_verify_signature` | `src/nip01_event.zig:299` | `src/nip01_event.zig:1242` | covered |
| `nip01_event.event_verify` | `src/nip01_event.zig:312` | `src/nip01_event.zig:1430` | covered |
| `nip01_event.event_replace_decision` | `src/nip01_event.zig:379` | `src/nip01_event.zig:817` | covered |
| `nip01_filter.filter_parse_json` | `src/nip01_filter.zig:91` | `src/nip01_filter.zig:711` | covered |
| `nip01_filter.filter_matches_event` | `src/nip01_filter.zig:118` | `src/nip01_filter.zig:763` | covered |
| `nip01_filter.filters_match_event` | `src/nip01_filter.zig:182` | `src/nip01_filter.zig:734` | covered |
| `nip01_message.client_message_parse_json` | `src/nip01_message.zig:65` | `src/nip01_message.zig:1284` | covered |
| `nip01_message.relay_message_parse_json` | `src/nip01_message.zig:94` | `src/nip01_message.zig:1308` | covered |
| `nip01_message.client_message_serialize_json` | `src/nip01_message.zig:132` | `src/nip01_message.zig:1568` | covered |
| `nip01_message.relay_message_serialize_json` | `src/nip01_message.zig:181` | `src/nip01_message.zig:1659` | covered |
| `nip01_message.transcript_mark_client_req` | `src/nip01_message.zig:282` | `src/nip01_message.zig:1748` | covered |
| `nip01_message.transcript_apply_relay` | `src/nip01_message.zig:1187` | `src/nip01_message.zig:1728` | covered |
| `nip42_auth.auth_state_init` | `src/nip42_auth.zig:33` | `src/nip42_auth.zig:593` | covered |
| `nip42_auth.auth_state_set_challenge` | `src/nip42_auth.zig:40` | `src/nip42_auth.zig:594` | covered |
| `nip42_auth.auth_validate_event` | `src/nip42_auth.zig:61` | `src/nip42_auth.zig:630` | covered |
| `nip42_auth.auth_state_accept_event` | `src/nip42_auth.zig:99` | `src/nip42_auth.zig:607` | covered |
| `nip42_auth.auth_state_is_pubkey_authenticated` | `src/nip42_auth.zig:131` | `src/nip42_auth.zig:445` | covered |
| `nip70_protected.event_has_protected_tag` | `src/nip70_protected.zig:6` | `src/nip70_protected.zig:75` | covered |
| `nip70_protected.protected_event_validate` | `src/nip70_protected.zig:23` | `src/nip70_protected.zig:115` | covered |
| `nip09_delete.delete_extract_targets` | `src/nip09_delete.zig:44` | `src/nip09_delete.zig:495` | covered |
| `nip09_delete.delete_extract_targets_checked` | `src/nip09_delete.zig:74` | `src/nip09_delete.zig:429` | covered |
| `nip09_delete.deletion_can_apply` | `src/nip09_delete.zig:86` | `src/nip09_delete.zig:451` | covered |
| `nip40_expire.event_expiration_unix_seconds` | `src/nip40_expire.zig:6` | `src/nip40_expire.zig:155` | covered |
| `nip40_expire.event_is_expired_at` | `src/nip40_expire.zig:30` | `src/nip40_expire.zig:189` | covered |
| `nip13_pow.pow_leading_zero_bits` | `src/nip13_pow.zig:20` | `src/nip13_pow.zig:285` | covered |
| `nip13_pow.pow_extract_nonce_target` | `src/nip13_pow.zig:46` | `src/nip13_pow.zig:335` | covered |
| `nip13_pow.pow_meets_difficulty_verified_id` | `src/nip13_pow.zig:152` | `src/nip13_pow.zig:523` | covered |
| `nip19_bech32.nip19_encode` | `src/nip19_bech32.zig:57` | `src/nip19_bech32.zig:673` | covered |
| `nip19_bech32.nip19_decode` | `src/nip19_bech32.zig:80` | `src/nip19_bech32.zig:674` | covered |
| `nip21_uri.nip21_parse` | `src/nip21_uri.zig:20` | `src/nip21_uri.zig:118` | covered |
| `nip21_uri.nip21_is_valid` | `src/nip21_uri.zig:71` | `src/nip21_uri.zig:204` | covered |
| `nip02_contacts.contacts_extract` | `src/nip02_contacts.zig:24` | `src/nip02_contacts.zig:156` | covered |
| `nip65_relays.relay_marker_parse` | `src/nip65_relays.zig:26` | `src/nip65_relays.zig:215` | covered |
| `nip65_relays.relay_list_extract` | `src/nip65_relays.zig:52` | `src/nip65_relays.zig:351` | covered |
| `nip44.nip44_get_conversation_key` | `src/nip44.zig:44` | `src/nip44.zig:870` | covered |
| `nip44.nip44_calc_padded_plaintext_len` | `src/nip44.zig:69` | `src/nip44.zig:591` | covered |
| `nip44.nip44_encrypt_to_base64` | `src/nip44.zig:94` | `src/nip44.zig:797` | covered |
| `nip44.nip44_encrypt_with_nonce_to_base64` | `src/nip44.zig:111` | `src/nip44.zig:611` | covered |
| `nip44.nip44_decode_payload` | `src/nip44.zig:156` | `src/nip44.zig:659` | covered |
| `nip44.nip44_decrypt_from_base64` | `src/nip44.zig:196` | `src/nip44.zig:670` | covered |
| `nip59_wrap.nip59_validate_wrap_structure` | `src/nip59_wrap.zig:26` | `src/nip59_wrap.zig:835` | covered |
| `nip59_wrap.nip59_unwrap` | `src/nip59_wrap.zig:49` | `src/nip59_wrap.zig:861` | covered |
| `nip45_count.count_client_message_parse`* | `src/nip45_count.zig:37` | `src/nip45_count.zig:304` | covered |
| `nip45_count.count_relay_message_parse`* | `src/nip45_count.zig:63` | `src/nip45_count.zig:338` | covered |
| `nip45_count.count_metadata_validate`* | `src/nip45_count.zig:88` | `src/nip45_count.zig:426` | covered |
| `nip50_search.search_field_validate`* | `src/nip50_search.zig:27` | `src/nip50_search.zig:198` | covered |
| `nip50_search.search_tokens_parse`* | `src/nip50_search.zig:47` | `src/nip50_search.zig:203` | covered |
| `nip77_negentropy.negentropy_open_parse`* | `src/nip77_negentropy.zig:79` | `src/nip77_negentropy.zig:523` | covered |
| `nip77_negentropy.negentropy_msg_parse`* | `src/nip77_negentropy.zig:108` | `src/nip77_negentropy.zig:529` | covered |
| `nip77_negentropy.negentropy_close_parse`* | `src/nip77_negentropy.zig:135` | `src/nip77_negentropy.zig:534` | covered |
| `nip77_negentropy.negentropy_err_parse`* | `src/nip77_negentropy.zig:156` | `src/nip77_negentropy.zig:557` | covered |
| `nip77_negentropy.negentropy_state_apply`* | `src/nip77_negentropy.zig:178` | `src/nip77_negentropy.zig:653` | covered |
| `nip77_negentropy.negentropy_items_validate_order`* | `src/nip77_negentropy.zig:232` | `src/nip77_negentropy.zig:617` | covered |
| `nip11.nip11_parse_document` | `src/nip11.zig:33` | `src/nip11.zig:354` | covered |
| `nip11.nip11_validate_known_fields` | `src/nip11.zig:71` | `src/nip11.zig:505` | covered |

`*` Compatibility/extension API surface.
