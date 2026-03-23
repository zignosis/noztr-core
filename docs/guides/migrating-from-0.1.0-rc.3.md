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

- `noztr.nip17_private_messages.DmReplyRef` -> `noztr.nip17_private_messages.ReplyRef`
- `noztr.nip17_private_messages.DmMessageInfo` -> `noztr.nip17_private_messages.Message`
- `noztr.nip17_private_messages.FileMessageInfo` -> `noztr.nip17_private_messages.FileMessage`
- `noztr.nip04.MessageInfo` -> `noztr.nip04.Message`
- `noztr.nip30_custom_emoji.EmojiTagInfo` -> `noztr.nip30_custom_emoji.EmojiTag`
- `noztr.nip36_content_warning.ContentWarningInfo` -> `noztr.nip36_content_warning.ContentWarning`
- `noztr.nip34_git.RepositoryAnnouncementInfo` -> `noztr.nip34_git.Announcement`
- `noztr.nip34_git.RepositoryStateRef` -> `noztr.nip34_git.StateRef`
- `noztr.nip34_git.RepositoryStateInfo` -> `noztr.nip34_git.State`
- `noztr.nip34_git.UserGraspListInfo` -> `noztr.nip34_git.GraspList`
- `noztr.nip51_lists.ListInfo` -> `noztr.nip51_lists.List`
- `noztr.nip51_lists.PrivateListInfo` -> `noztr.nip51_lists.PrivateList`
- `noztr.nip53_live_activities.LiveActivityInfo` -> `noztr.nip53_live_activities.Activity`
- `noztr.nip53_live_activities.LiveChatInfo` -> `noztr.nip53_live_activities.Chat`
- `noztr.nip56_reporting.ReportInfo` -> `noztr.nip56_reporting.Report`
- `noztr.nip64_chess_pgn.ChessPgnInfo` -> `noztr.nip64_chess_pgn.Pgn`
- `noztr.nip58_badges.ImageInfo` -> `noztr.nip58_badges.Image`
- `noztr.nip98_http_auth.HttpAuthInfo` -> `noztr.nip98_http_auth.Auth`
- `noztr.nip71_video_events.TextTrackInfo` -> `noztr.nip71_video_events.TextTrack`
- `noztr.nip71_video_events.OriginInfo` -> `noztr.nip71_video_events.Origin`
- `noztr.nip71_video_events.VideoInfo` -> `noztr.nip71_video_events.Video`
- `noztr.nip78_app_data.AppDataInfo` -> `noztr.nip78_app_data.AppData`
- `noztr.nip84_highlights.UrlReference` -> `noztr.nip84_highlights.UrlRef`
- `noztr.nip84_highlights.HighlightInfo` -> `noztr.nip84_highlights.Highlight`
- `noztr.nip72_moderated_communities.CommunityInfo` -> `noztr.nip72_moderated_communities.Community`
- `noztr.nip72_moderated_communities.EventReference` -> `noztr.nip72_moderated_communities.EventRef`
- `noztr.nip72_moderated_communities.CommunityPostInfo` -> `noztr.nip72_moderated_communities.Post`
- `noztr.nip72_moderated_communities.CommunityApprovalInfo` -> `noztr.nip72_moderated_communities.Approval`
- `noztr.nip99_classified_listings.PriceInfo` -> `noztr.nip99_classified_listings.Price`
- `noztr.nip99_classified_listings.ImageInfo` -> `noztr.nip99_classified_listings.Image`
- `noztr.nip92_media_attachments.ImetaInfo` -> `noztr.nip92_media_attachments.Imeta`
- `noztr.nip94_file_metadata.ImageReference` -> `noztr.nip94_file_metadata.ImageRef`
- `noztr.nip94_file_metadata.FileMetadataInfo` -> `noztr.nip94_file_metadata.Metadata`
- `noztr.nip66_relay_discovery.RelayDiscoveryInfo` -> `noztr.nip66_relay_discovery.Discovery`
- `noztr.nip66_relay_discovery.RelayMonitorInfo` -> `noztr.nip66_relay_discovery.Monitor`
- `noztr.nip22_comments.CommentInfo` -> `noztr.nip22_comments.Comment`
- `noztr.nip29_relay_groups.GroupReference` -> `noztr.nip29_relay_groups.Reference`
- `noztr.nip29_relay_groups.GroupAdminsInfo` -> `noztr.nip29_relay_groups.Admins`
- `noztr.nip29_relay_groups.GroupMembersInfo` -> `noztr.nip29_relay_groups.Members`
- `noztr.nip29_relay_groups.GroupRolesInfo` -> `noztr.nip29_relay_groups.Roles`
- `noztr.nip29_relay_groups.GroupJoinRequestInfo` -> `noztr.nip29_relay_groups.JoinRequest`
- `noztr.nip29_relay_groups.GroupLeaveRequestInfo` -> `noztr.nip29_relay_groups.LeaveRequest`
- `noztr.nip29_relay_groups.GroupPutUserInfo` -> `noztr.nip29_relay_groups.PutUser`
- `noztr.nip29_relay_groups.GroupRemoveUserInfo` -> `noztr.nip29_relay_groups.RemoveUser`
- `noztr.nipb0_web_bookmarking.WebBookmarkInfo` -> `noztr.nipb0_web_bookmarking.Bookmark`
- `noztr.nipb7_blossom_servers.BlossomServerListInfo` -> `noztr.nipb7_blossom_servers.ServerList`
- `noztr.nipb7_blossom_servers.BlobReference` -> `noztr.nipb7_blossom_servers.BlobRef`

These are naming cleanups only. They do not change parsing behavior, wire formats, or ownership.
