---
title: NIP Coverage
doc_type: release_reference
status: active
owner: noztr
read_when:
  - checking_supported_nips
  - browsing_support_coverage
  - comparing_noztr_surface_area
canonical: true
---

# NIP Coverage

This page lists the public `noztr` support surface by NIP.

`Status` meanings:

- `implemented`
  - exported and available by default
- `optional`
  - exported only when the I6 extension build flag is enabled
- `split`
  - only the deterministic kernel slice is in `noztr`

## Coverage Table

| NIP | Status | Export | Example |
| --- | --- | --- | --- |
| `NIP-01` events | implemented | `nip01_event` | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| `NIP-01` filters | implemented | `nip01_filter` | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| `NIP-01` messages | implemented | `nip01_message` | [strict_core_recipe.zig](/workspace/projects/noztr/examples/strict_core_recipe.zig) |
| `NIP-91` AND filters | implemented | `nip01_filter` | [nip01_example.zig](/workspace/projects/noztr/examples/nip01_example.zig) |
| `NIP-02` | implemented | `nip02_contacts` | [nip02_example.zig](/workspace/projects/noztr/examples/nip02_example.zig) |
| `NIP-03` | implemented | `nip03_opentimestamps` | [nip03_example.zig](/workspace/projects/noztr/examples/nip03_example.zig) |
| `NIP-05` | implemented | `nip05_identity` | [nip05_example.zig](/workspace/projects/noztr/examples/nip05_example.zig) |
| `NIP-06` | implemented | `nip06_mnemonic` | [nip06_example.zig](/workspace/projects/noztr/examples/nip06_example.zig) |
| `NIP-09` | implemented | `nip09_delete` | [nip09_example.zig](/workspace/projects/noztr/examples/nip09_example.zig) |
| `NIP-10` | implemented | `nip10_threads` | [nip10_example.zig](/workspace/projects/noztr/examples/nip10_example.zig) |
| `NIP-11` | implemented | `nip11` | [nip11_example.zig](/workspace/projects/noztr/examples/nip11_example.zig) |
| `NIP-13` | implemented | `nip13_pow` | [nip13_example.zig](/workspace/projects/noztr/examples/nip13_example.zig) |
| `NIP-14` | implemented | `nip14_subjects` | [nip14_example.zig](/workspace/projects/noztr/examples/nip14_example.zig) |
| `NIP-17` | implemented | `nip17_private_messages` | [nip17_example.zig](/workspace/projects/noztr/examples/nip17_example.zig) |
| `NIP-18` | implemented | `nip18_reposts` | [nip18_example.zig](/workspace/projects/noztr/examples/nip18_example.zig) |
| `NIP-19` | implemented | `nip19_bech32` | [nip19_example.zig](/workspace/projects/noztr/examples/nip19_example.zig) |
| `NIP-21` | implemented | `nip21_uri` | [nip21_example.zig](/workspace/projects/noztr/examples/nip21_example.zig) |
| `NIP-22` | implemented | `nip22_comments` | [nip22_example.zig](/workspace/projects/noztr/examples/nip22_example.zig) |
| `NIP-23` | implemented | `nip23_long_form` | [nip23_example.zig](/workspace/projects/noztr/examples/nip23_example.zig) |
| `NIP-24` | implemented | `nip24_extra_metadata` | [nip24_example.zig](/workspace/projects/noztr/examples/nip24_example.zig) |
| `NIP-25` | implemented | `nip25_reactions` | [nip25_example.zig](/workspace/projects/noztr/examples/nip25_example.zig) |
| `NIP-26` | implemented | `nip26_delegation` | [nip26_example.zig](/workspace/projects/noztr/examples/nip26_example.zig) |
| `NIP-27` | implemented | `nip27_references` | [nip27_example.zig](/workspace/projects/noztr/examples/nip27_example.zig) |
| `NIP-28` | split | `nip28_public_chat` | [nip28_example.zig](/workspace/projects/noztr/examples/nip28_example.zig) |
| `NIP-29` | implemented | `nip29_relay_groups` | [nip29_example.zig](/workspace/projects/noztr/examples/nip29_example.zig) |
| `NIP-30` | implemented | `nip30_custom_emoji` | [nip30_example.zig](/workspace/projects/noztr/examples/nip30_example.zig) |
| `NIP-31` | implemented | `nip31_alt_tags` | [nip31_example.zig](/workspace/projects/noztr/examples/nip31_example.zig) |
| `NIP-32` | implemented | `nip32_labeling` | [nip32_example.zig](/workspace/projects/noztr/examples/nip32_example.zig) |
| `NIP-34` | split | `nip34_git` | [nip34_example.zig](/workspace/projects/noztr/examples/nip34_example.zig) |
| `NIP-36` | implemented | `nip36_content_warning` | [nip36_example.zig](/workspace/projects/noztr/examples/nip36_example.zig) |
| `NIP-37` | implemented | `nip37_drafts` | [nip37_example.zig](/workspace/projects/noztr/examples/nip37_example.zig) |
| `NIP-38` | implemented | `nip38_user_status` | [nip38_example.zig](/workspace/projects/noztr/examples/nip38_example.zig) |
| `NIP-39` | implemented | `nip39_external_identities` | [nip39_example.zig](/workspace/projects/noztr/examples/nip39_example.zig) |
| `NIP-40` | implemented | `nip40_expire` | [nip40_example.zig](/workspace/projects/noztr/examples/nip40_example.zig) |
| `NIP-42` | implemented | `nip42_auth` | [nip42_example.zig](/workspace/projects/noztr/examples/nip42_example.zig) |
| `NIP-44` | implemented | `nip44` | [nip44_example.zig](/workspace/projects/noztr/examples/nip44_example.zig) |
| `NIP-45` | optional | `nip45_count` | [nip45_example.zig](/workspace/projects/noztr/examples/nip45_example.zig) |
| `NIP-46` | implemented | `nip46_remote_signing` | [nip46_example.zig](/workspace/projects/noztr/examples/nip46_example.zig) |
| `NIP-47` | split | `nip47_wallet_connect` | [nip47_example.zig](/workspace/projects/noztr/examples/nip47_example.zig) |
| `NIP-49` | implemented | `nip49_private_key_encryption` | [nip49_example.zig](/workspace/projects/noztr/examples/nip49_example.zig) |
| `NIP-50` | optional | `nip50_search` | [nip50_example.zig](/workspace/projects/noztr/examples/nip50_example.zig) |
| `NIP-51` | implemented | `nip51_lists` | [nip51_example.zig](/workspace/projects/noztr/examples/nip51_example.zig) |
| `NIP-52` | implemented | `nip52_calendar_events` | [nip52_example.zig](/workspace/projects/noztr/examples/nip52_example.zig) |
| `NIP-53` | split | `nip53_live_activities` | [nip53_example.zig](/workspace/projects/noztr/examples/nip53_example.zig) |
| `NIP-54` | implemented | `nip54_wiki` | [nip54_example.zig](/workspace/projects/noztr/examples/nip54_example.zig) |
| `NIP-56` | implemented | `nip56_reporting` | [nip56_example.zig](/workspace/projects/noztr/examples/nip56_example.zig) |
| `NIP-57` | split | `nip57_zaps` | [nip57_example.zig](/workspace/projects/noztr/examples/nip57_example.zig) |
| `NIP-58` | implemented | `nip58_badges` | [nip58_example.zig](/workspace/projects/noztr/examples/nip58_example.zig) |
| `NIP-59` | implemented | `nip59_wrap` | [nip59_example.zig](/workspace/projects/noztr/examples/nip59_example.zig) |
| `NIP-61` | split | `nip61_nutzaps` | [nip61_example.zig](/workspace/projects/noztr/examples/nip61_example.zig) |
| `NIP-64` | implemented | `nip64_chess_pgn` | [nip64_example.zig](/workspace/projects/noztr/examples/nip64_example.zig) |
| `NIP-65` | implemented | `nip65_relays` | [nip65_example.zig](/workspace/projects/noztr/examples/nip65_example.zig) |
| `NIP-66` | split | `nip66_relay_discovery` | [nip66_example.zig](/workspace/projects/noztr/examples/nip66_example.zig) |
| `NIP-70` | implemented | `nip70_protected` | [nip70_example.zig](/workspace/projects/noztr/examples/nip70_example.zig) |
| `NIP-71` | split | `nip71_video_events` | [nip71_example.zig](/workspace/projects/noztr/examples/nip71_example.zig) |
| `NIP-72` | split | `nip72_moderated_communities` | [nip72_example.zig](/workspace/projects/noztr/examples/nip72_example.zig) |
| `NIP-73` | implemented | `nip73_external_ids` | [nip73_example.zig](/workspace/projects/noztr/examples/nip73_example.zig) |
| `NIP-75` | implemented | `nip75_zap_goals` | [nip75_example.zig](/workspace/projects/noztr/examples/nip75_example.zig) |
| `NIP-77` | optional | `nip77_negentropy` | [nip77_example.zig](/workspace/projects/noztr/examples/nip77_example.zig) |
| `NIP-78` | split | `nip78_app_data` | [nip78_example.zig](/workspace/projects/noztr/examples/nip78_example.zig) |
| `NIP-84` | implemented | `nip84_highlights` | [nip84_example.zig](/workspace/projects/noztr/examples/nip84_example.zig) |
| `NIP-86` | split | `nip86_relay_management` | [nip86_example.zig](/workspace/projects/noztr/examples/nip86_example.zig) |
| `NIP-89` | split | `nip89_handlers` | [nip89_example.zig](/workspace/projects/noztr/examples/nip89_example.zig) |
| `NIP-88` | implemented | `nip88_polls` | [nip88_example.zig](/workspace/projects/noztr/examples/nip88_example.zig) |
| `NIP-92` | implemented | `nip92_media_attachments` | [nip92_example.zig](/workspace/projects/noztr/examples/nip92_example.zig) |
| `NIP-94` | implemented | `nip94_file_metadata` | [nip94_example.zig](/workspace/projects/noztr/examples/nip94_example.zig) |
| `NIP-98` | split | `nip98_http_auth` | [nip98_example.zig](/workspace/projects/noztr/examples/nip98_example.zig) |
| `NIP-99` | implemented | `nip99_classified_listings` | [nip99_example.zig](/workspace/projects/noztr/examples/nip99_example.zig) |
| `NIP-B0` | implemented | `nipb0_web_bookmarking` | [nipb0_example.zig](/workspace/projects/noztr/examples/nipb0_example.zig) |
| `NIP-B7` | split | `nipb7_blossom_servers` | [nipb7_example.zig](/workspace/projects/noztr/examples/nipb7_example.zig) |
| `NIP-C0` | implemented | `nipc0_code_snippets` | [nipc0_example.zig](/workspace/projects/noztr/examples/nipc0_example.zig) |

## Related Non-NIP Helpers

| Helper surface | Export | Example |
| --- | --- | --- |
| bounded BIP-85 derivation | `bip85_derivation` | [bip85_example.zig](/workspace/projects/noztr/examples/bip85_example.zig) |
| bounded Nostr key derivation and signing | `nostr_keys` | [nostr_keys_example.zig](/workspace/projects/noztr/examples/nostr_keys_example.zig) |

## Coverage Notes

- `split` means `noztr` implements only the deterministic protocol-kernel slice
- `optional` means the export is build-flag gated through the I6 extension set
- some scenario-oriented guidance lives in recipe examples rather than a separate long-form guide
