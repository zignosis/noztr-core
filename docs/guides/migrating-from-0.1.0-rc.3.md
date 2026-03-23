---
title: Migrating From 0.1.0-rc.3
doc_type: release_guide
status: active
owner: noztr
read_when:
  - updating_from_0_1_0_rc_3
  - adapting_to_recent_public_api_breaks
canonical: true
---

# Migrating From `0.1.0-rc.3`

This guide covers the current builder-workspace cleanup after `v0.1.0-rc.3`.

The current line is still pre-`1.0.0`, so clarity-driven public cleanup can still happen. This
slice keeps the caller-owned builder pattern, but renames the generic workspace types so they read
as current role names instead of past-tense storage artifacts.

## Quick Path

If your project depends on `noztr-core`:

1. replace route-local `BuiltTag` references with `TagBuilder`
2. replace `nip17_private_messages.BuiltFileMetadataTag` with `FileTagBuilder`
3. replace `nip46_remote_signing.BuiltRequest` with `RequestBuilder`
4. rerun your normal build/test gates
5. refresh generated symbol indexes or local LLM context packs that still point at the old names

## Renamed Builder Workspace Types

### Generic Tag Builders

Every route that previously exported `BuiltTag` now exports `TagBuilder` instead.

This affects:

- `nip03_opentimestamps`
- `nip04`
- `nip14_subjects`
- `nip17_private_messages`
- `nip23_long_form`
- `nip24_extra_metadata`
- `nip26_delegation`
- `nip28_public_chat`
- `nip29_relay_groups`
- `nip30_custom_emoji`
- `nip31_alt_tags`
- `nip32_labeling`
- `nip34_git`
- `nip36_content_warning`
- `nip37_drafts`
- `nip38_user_status`
- `nip39_external_identities`
- `nip51_lists`
- `nip52_calendar_events`
- `nip53_live_activities`
- `nip54_wiki`
- `nip56_reporting`
- `nip57_zaps`
- `nip58_badges`
- `nip61_nutzaps`
- `nip64_chess_pgn`
- `nip66_relay_discovery`
- `nip71_video_events`
- `nip73_external_ids`
- `nip75_zap_goals`
- `nip78_app_data`
- `nip84_highlights`
- `nip88_polls`
- `nip89_handlers`
- `nip92_media_attachments`
- `nip94_file_metadata`
- `nip99_classified_listings`
- `nipb0_web_bookmarking`
- `nipb7_blossom_servers`
- `nipc0_code_snippets`

Example:

- before:
  - `var tag: noztr.nip04.BuiltTag = .{};`
- after:
  - `var tag: noztr.nip04.TagBuilder = .{};`

### Specialized Builder Workspaces

- `noztr.nip17_private_messages.BuiltFileMetadataTag` ->
  `noztr.nip17_private_messages.FileTagBuilder`
- `noztr.nip46_remote_signing.BuiltRequest` ->
  `noztr.nip46_remote_signing.RequestBuilder`

## Why

The grouped route already carries the protocol context.

These types are caller-owned build workspaces, so `TagBuilder`, `FileTagBuilder`, and
`RequestBuilder` say what they are more directly than `Built*` names do.

This is a naming cleanup only. It does not change:

- wire formats
- typed error intent
- ownership model
- kernel-vs-SDK scope

## Scope

This guide covers the builder-workspace rename slice only.

If you are also updating from older release candidates, apply the earlier migration guides first:

- [migrating-from-0.1.0-rc.1.md](migrating-from-0.1.0-rc.1.md)
- [migrating-from-0.1.0-rc.2.md](migrating-from-0.1.0-rc.2.md)

## Renamed Primary Read Models

The current read-model cleanup also shortens several primary route-local extract types:

- `noztr.nip64_chess_pgn.ChessPgnInfo` -> `noztr.nip64_chess_pgn.Pgn`
- `noztr.nip78_app_data.AppDataInfo` -> `noztr.nip78_app_data.AppData`
- `noztr.nip92_media_attachments.ImetaInfo` -> `noztr.nip92_media_attachments.Imeta`
- `noztr.nip94_file_metadata.ImageReference` -> `noztr.nip94_file_metadata.ImageRef`
- `noztr.nip94_file_metadata.FileMetadataInfo` -> `noztr.nip94_file_metadata.Metadata`
- `noztr.nip66_relay_discovery.RelayDiscoveryInfo` -> `noztr.nip66_relay_discovery.Discovery`
- `noztr.nip66_relay_discovery.RelayMonitorInfo` -> `noztr.nip66_relay_discovery.Monitor`

These are naming cleanups only. They do not change parsing behavior, wire formats, or ownership.
