---
title: Migrating From 0.1.0-rc.1
doc_type: release_guide
status: active
owner: noztr
read_when:
  - updating_from_0_1_0_rc_1
  - adapting_to_recent_public_api_breaks
canonical: true
---

# Migrating From `0.1.0-rc.1`

This guide covers the intentional public API cleanup after `v0.1.0-rc.1`.

The current line is still pre-`1.0.0`, so deliberate public-surface cleanup can still happen. When
it does, the change should be explicit and downstream callers should get one clear migration path.

## What Changed

Two public-surface normalization changes landed after `v0.1.0-rc.1`:

- temporary compatibility aliases introduced during the API-naming normalization pass were removed
- public error type names now consistently prefer descriptive names inside module namespaces

These are breaking changes for downstream code that referenced the removed alias symbols or the
short-lived numeric error type names that briefly appeared on `master`.

## Renamed Symbols

Use these canonical names now:

- `noztr.nip21_uri.nip21_parse` -> `noztr.nip21_uri.uri_parse`
- `noztr.nip21_uri.nip21_is_valid` -> `noztr.nip21_uri.uri_is_valid`
- `noztr.nip47_wallet_connect.connection_uri_format` ->
  `noztr.nip47_wallet_connect.connection_uri_serialize`
- `noztr.nip36_content_warning.build_content_warning_tag` ->
  `noztr.nip36_content_warning.content_warning_build_tag`
- `noztr.nip36_content_warning.build_content_warning_namespace_tag` ->
  `noztr.nip36_content_warning.content_warning_build_namespace_tag`
- `noztr.nip36_content_warning.build_content_warning_label_tag` ->
  `noztr.nip36_content_warning.content_warning_build_label_tag`
- `noztr.nip24_extra_metadata.build_reference_tag` ->
  `noztr.nip24_extra_metadata.common_tags_build_reference_tag`
- `noztr.nip24_extra_metadata.build_title_tag` ->
  `noztr.nip24_extra_metadata.common_tags_build_title_tag`
- `noztr.nip24_extra_metadata.build_hashtag_tag` ->
  `noztr.nip24_extra_metadata.common_tags_build_hashtag_tag`
- `noztr.nip56_reporting.build_pubkey_report_tag` ->
  `noztr.nip56_reporting.report_build_pubkey_tag`
- `noztr.nip56_reporting.build_event_report_tag` ->
  `noztr.nip56_reporting.report_build_event_tag`
- `noztr.nip56_reporting.build_blob_report_tag` ->
  `noztr.nip56_reporting.report_build_blob_tag`
- `noztr.nip56_reporting.build_server_tag` ->
  `noztr.nip56_reporting.report_build_server_tag`
- `noztr.nip57_zaps.build_pubkey_tag` ->
  `noztr.nip57_zaps.zap_build_pubkey_tag`
- `noztr.nip57_zaps.build_event_tag` ->
  `noztr.nip57_zaps.zap_build_event_tag`
- `noztr.nip57_zaps.build_coordinate_tag` ->
  `noztr.nip57_zaps.zap_build_coordinate_tag`
- `noztr.nip57_zaps.build_kind_tag` ->
  `noztr.nip57_zaps.zap_build_kind_tag`

## Renamed Error Types

The short-lived numeric error names on `master` were reverted in favor of descriptive names.

Use these public error type names now:

- `noztr.nip02_contacts.Nip02Error` -> `noztr.nip02_contacts.ContactsError`
- `noztr.nip03_opentimestamps.Nip03Error` -> `noztr.nip03_opentimestamps.OpenTimestampsError`
- `noztr.nip04.Nip04Error` -> `noztr.nip04.LegacyDmError`
- `noztr.nip05_identity.Nip05Error` -> `noztr.nip05_identity.IdentityError`
- `noztr.nip06_mnemonic.Nip06Error` -> `noztr.nip06_mnemonic.MnemonicError`
- `noztr.nip09_delete.Nip09Error` -> `noztr.nip09_delete.DeleteError`
- `noztr.nip10_threads.Nip10Error` -> `noztr.nip10_threads.ThreadError`
- `noztr.nip11.Nip11Error` -> `noztr.nip11.RelayInfoError`
- `noztr.nip14_subjects.Nip14Error` -> `noztr.nip14_subjects.SubjectError`
- `noztr.nip17_private_messages.Nip17Error` -> `noztr.nip17_private_messages.PrivateMessageError`
- `noztr.nip17_private_messages.Nip17RelayListError` ->
  `noztr.nip17_private_messages.RelayListError`
- `noztr.nip18_reposts.Nip18Error` -> `noztr.nip18_reposts.RepostError`
- `noztr.nip19_bech32.Nip19Error` -> `noztr.nip19_bech32.Bech32Error`
- `noztr.nip21_uri.Nip21Error` -> `noztr.nip21_uri.UriError`
- `noztr.nip22_comments.Nip22Error` -> `noztr.nip22_comments.CommentError`
- `noztr.nip23_long_form.Nip23Error` -> `noztr.nip23_long_form.LongFormError`
- `noztr.nip24_extra_metadata.Nip24Error` ->
  `noztr.nip24_extra_metadata.ExtraMetadataError`
- `noztr.nip26_delegation.Nip26Error` -> `noztr.nip26_delegation.DelegationError`
- `noztr.nip27_references.Nip27Error` -> `noztr.nip27_references.ReferenceError`
- `noztr.nip28_public_chat.Nip28Error` -> `noztr.nip28_public_chat.PublicChatError`
- `noztr.nip29_relay_groups.Nip29Error` -> `noztr.nip29_relay_groups.GroupError`
- `noztr.nip30_custom_emoji.Nip30Error` -> `noztr.nip30_custom_emoji.EmojiError`
- `noztr.nip31_alt_tags.Nip31Error` -> `noztr.nip31_alt_tags.AltTagError`
- `noztr.nip32_labeling.Nip32Error` -> `noztr.nip32_labeling.LabelingError`
- `noztr.nip34_git.Nip34Error` -> `noztr.nip34_git.GitError`
- `noztr.nip36_content_warning.Nip36Error` ->
  `noztr.nip36_content_warning.ContentWarningError`
- `noztr.nip37_drafts.Nip37Error` -> `noztr.nip37_drafts.DraftError`
- `noztr.nip38_user_status.Nip38Error` -> `noztr.nip38_user_status.UserStatusError`
- `noztr.nip39_external_identities.Nip39Error` ->
  `noztr.nip39_external_identities.ExternalIdentityError`
- `noztr.nip40_expire.Nip40Error` -> `noztr.nip40_expire.ExpirationError`
- `noztr.nip42_auth.Nip42Error` -> `noztr.nip42_auth.AuthError`
- `noztr.nip44.Nip44Error` -> `noztr.nip44.ConversationEncryptionError`
- `noztr.nip45_count.Nip45Error` -> `noztr.nip45_count.CountError`
- `noztr.nip46_remote_signing.Nip46Error` ->
  `noztr.nip46_remote_signing.RemoteSigningError`
- `noztr.nip47_wallet_connect.Nip47Error` -> `noztr.nip47_wallet_connect.NwcError`
- `noztr.nip49_private_key_encryption.Nip49Error` ->
  `noztr.nip49_private_key_encryption.PrivateKeyEncryptionError`
- `noztr.nip50_search.Nip50Error` -> `noztr.nip50_search.SearchError`
- `noztr.nip51_lists.Nip51Error` -> `noztr.nip51_lists.ListError`
- `noztr.nip51_lists.Nip51PrivateListError` -> `noztr.nip51_lists.PrivateListError`
- `noztr.nip52_calendar_events.Nip52Error` -> `noztr.nip52_calendar_events.CalendarError`
- `noztr.nip53_live_activities.Nip53Error` ->
  `noztr.nip53_live_activities.LiveActivityError`
- `noztr.nip54_wiki.Nip54Error` -> `noztr.nip54_wiki.WikiError`
- `noztr.nip56_reporting.Nip56Error` -> `noztr.nip56_reporting.ReportError`
- `noztr.nip57_zaps.Nip57Error` -> `noztr.nip57_zaps.ZapError`
- `noztr.nip58_badges.Nip58Error` -> `noztr.nip58_badges.BadgeError`
- `noztr.nip59_wrap.Nip59Error` -> `noztr.nip59_wrap.WrapError`
- `noztr.nip59_wrap.Nip59BuildError` -> `noztr.nip59_wrap.WrapBuildError`
- `noztr.nip61_nutzaps.Nip61Error` -> `noztr.nip61_nutzaps.NutzapError`
- `noztr.nip64_chess_pgn.Nip64Error` -> `noztr.nip64_chess_pgn.ChessPgnError`
- `noztr.nip65_relays.Nip65Error` -> `noztr.nip65_relays.RelaysError`
- `noztr.nip66_relay_discovery.Nip66Error` ->
  `noztr.nip66_relay_discovery.RelayDiscoveryError`
- `noztr.nip70_protected.Nip70Error` -> `noztr.nip70_protected.ProtectedError`
- `noztr.nip71_video_events.Nip71Error` -> `noztr.nip71_video_events.VideoEventError`
- `noztr.nip72_moderated_communities.Nip72Error` ->
  `noztr.nip72_moderated_communities.CommunityError`
- `noztr.nip73_external_ids.Nip73Error` -> `noztr.nip73_external_ids.ExternalIdError`
- `noztr.nip75_zap_goals.Nip75Error` -> `noztr.nip75_zap_goals.ZapGoalError`
- `noztr.nip77_negentropy.Nip77Error` -> `noztr.nip77_negentropy.NegentropyError`
- `noztr.nip78_app_data.Nip78Error` -> `noztr.nip78_app_data.AppDataError`
- `noztr.nip84_highlights.Nip84Error` -> `noztr.nip84_highlights.HighlightError`
- `noztr.nip86_relay_management.Nip86Error` ->
  `noztr.nip86_relay_management.RelayManagementError`
- `noztr.nip88_polls.Nip88Error` -> `noztr.nip88_polls.PollError`
- `noztr.nip89_handlers.Nip89Error` -> `noztr.nip89_handlers.HandlerError`
- `noztr.nip92_media_attachments.Nip92Error` ->
  `noztr.nip92_media_attachments.MediaAttachmentError`
- `noztr.nip94_file_metadata.Nip94Error` ->
  `noztr.nip94_file_metadata.FileMetadataError`
- `noztr.nip98_http_auth.Nip98Error` -> `noztr.nip98_http_auth.HttpAuthError`
- `noztr.nip99_classified_listings.Nip99Error` ->
  `noztr.nip99_classified_listings.ClassifiedListingError`
- `noztr.nipb0_web_bookmarking.NipB0Error` -> `noztr.nipb0_web_bookmarking.WebBookmarkError`
- `noztr.nipb7_blossom_servers.NipB7Error` -> `noztr.nipb7_blossom_servers.BlossomError`
- `noztr.nipc0_code_snippets.NipC0Error` -> `noztr.nipc0_code_snippets.CodeSnippetError`

## Why

The goal is to make the public surface more coherent without reducing clarity:

- one obvious naming shape per module
- fewer bare `build_*` names in otherwise domain-prefixed APIs
- fewer redundant module-number prefixes where the module namespace already carries that meaning
- more consistent parse/build/serialize verb shape across similar modules
- descriptive public names inside module namespaces instead of mechanical numeric repetition

## Downstream Guidance

If your project depends on `noztr-core`:

1. update imports, call sites, and any explicit error type references to the canonical names above
2. rerun your normal build and example/test lanes
3. if you publish wrappers around `noztr`, re-export only the descriptive current names

## Scope

These changes normalize public symbol and error type names only. They do not change:

- wire formats
- ownership model
- typed error intent
- protocol/kernel versus SDK boundary
