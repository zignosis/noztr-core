# Changelog

This changelog records intentional public release changes for `noztr`.

Current release posture:

- the current public line is intentionally pre-`1.0.0`
- the first intentional public tag starts at `0.1.0-rc.1`
- final RC closure should still be informed by downstream `noztr-sdk` feedback

For the public versioning policy, see
[docs/stability-and-versioning.md](docs/stability-and-versioning.md).

## [Unreleased]

### Breaking Changes

- shortened route-local public type names in:
  - `nip37_drafts`
  - `nip45_count`
  - `nip23_long_form`
  - `nip99_classified_listings`
- downstream migration guide:
  - [docs/guides/migrating-from-0.1.0-rc.5.md](docs/guides/migrating-from-0.1.0-rc.5.md)

## [0.1.0-rc.5] - 2026-03-24

Release type: breaking rc

### Summary

Fifth public release candidate for `noztr-core`.

This RC removes `NIP-26` from the supported `noztr-core` surface. The protocol-kernel boundary,
ownership posture, and the rest of the public API remain otherwise unchanged.

### Breaking Changes

- removed `NIP-26` support from `noztr-core`
- removed the public `nip26_delegation` module and its example/docs routes
- downstream migration guide:
  - [docs/guides/migrating-from-0.1.0-rc.4.md](docs/guides/migrating-from-0.1.0-rc.4.md)

## [0.1.0-rc.4] - 2026-03-23

Release type: breaking rc

### Summary

Fourth public release candidate for `noztr-core`.

This RC continues the pre-`1.0` public-surface cleanup: grouped routes now carry more of the
context, route-local read models are shorter and easier to scan, and the downstream migration path
is tighter. Wire behavior, ownership posture, and protocol scope remain stable.

### Breaking Changes

- renamed caller-owned builder workspace types toward explicit role names:
  - `BuiltTag` -> `TagBuilder`
  - `nip17_private_messages.BuiltFileMetadataTag` -> `FileTagBuilder`
  - `nip46_remote_signing.BuiltRequest` -> `RequestBuilder`
- shortened several primary route-local read-model types:
  - `DmReplyRef` -> `ReplyRef`
  - `DmMessageInfo` -> `Message`
  - `FileMessageInfo` -> `FileMessage`
  - `MessageInfo` -> `Message` in `nip04`
  - `ThreadReference` -> `Reference` in `nip10_threads`
  - `ThreadInfo` -> `Thread`
  - `EmojiTagInfo` -> `EmojiTag`
  - `ContentWarningInfo` -> `ContentWarning`
  - `RepositoryAnnouncementInfo` -> `Announcement`
  - `RepositoryStateRef` -> `StateRef`
  - `RepositoryStateInfo` -> `State`
  - `UserGraspListInfo` -> `GraspList`
  - `ListInfo` -> `List`
  - `PrivateListInfo` -> `PrivateList`
  - `LiveActivityInfo` -> `Activity`
  - `LiveChatInfo` -> `Chat`
  - `ReportInfo` -> `Report`
  - `ChessPgnInfo` -> `Pgn`
  - `ImageInfo` -> `Image` in `nip58_badges`
  - `HttpAuthInfo` -> `Auth`
  - `TextTrackInfo` -> `TextTrack`
  - `OriginInfo` -> `Origin`
  - `VideoInfo` -> `Video`
  - `CommentInfo` -> `Comment`
  - `LabelEventInfo` -> `LabelEvent`
  - `SelfLabelInfo` -> `SelfLabel`
  - `CommunityInfo` -> `Community`
  - `EventReference` -> `EventRef` in `nip72_moderated_communities`
  - `CommunityPostInfo` -> `Post`
  - `CommunityApprovalInfo` -> `Approval`
  - `AppDataInfo` -> `AppData`
  - `UrlReference` -> `UrlRef`
  - `HighlightInfo` -> `Highlight`
  - `PriceInfo` -> `Price`
  - `ImageInfo` -> `Image` in `nip99_classified_listings`
  - `ImetaInfo` -> `Imeta`
  - `ImageReference` -> `ImageRef`
  - `FileMetadataInfo` -> `Metadata`
  - `RelayDiscoveryInfo` -> `Discovery`
  - `RelayMonitorInfo` -> `Monitor`
  - `GroupReference` -> `Reference`
  - `GroupAdminsInfo` -> `Admins`
  - `GroupMembersInfo` -> `Members`
  - `GroupRolesInfo` -> `Roles`
  - `GroupJoinRequestInfo` -> `JoinRequest`
  - `GroupLeaveRequestInfo` -> `LeaveRequest`
  - `GroupPutUserInfo` -> `PutUser`
  - `GroupRemoveUserInfo` -> `RemoveUser`
  - `WebBookmarkInfo` -> `Bookmark`
  - `BlossomServerListInfo` -> `ServerList`
  - `BlobReference` -> `BlobRef`
  - `LicenseInfo` -> `License`
  - `RepoReference` -> `RepoRef`
  - `CodeSnippetInfo` -> `Snippet`
- migration guide:
  - [docs/guides/migrating-from-0.1.0-rc.3.md](docs/guides/migrating-from-0.1.0-rc.3.md)

## [0.1.0-rc.3] - 2026-03-23

Release type: breaking rc

### Summary

Third public release candidate for `noztr-core`.

This RC keeps wire behavior, the kernel-vs-SDK boundary, and the ownership posture stable, but it
significantly tightens the public teaching surface: route-internal names are shorter, pure storage
wrappers were removed where a direct caller-owned buffer path is clearer, and the `nip46` / `nip86`
response-result shells are flatter and easier to consume.

### Public Highlights

- shortened redundant route-internal public type names across the highest-noise grouped routes
- removed pure storage wrappers that added no semantic value in:
  - `nip28_public_chat`
  - `nip71_video_events`
  - `nip92_media_attachments`
- flattened response-result wrapper layers in:
  - `nip46_remote_signing`
  - `nip86_relay_management`
- tightened the migration guide and root contract-smoke coverage so downstream consumers and LLMs
  have one exact upgrade path

### Breaking Changes

- shortened route-internal public type names in:
  - `nip04`
  - `nip21_uri`
  - `nip44`
  - `nip46_remote_signing`
  - `nip28_public_chat`
  - `nip54_wiki`
  - `nip75_zap_goals`
  - `nip88_polls`
  - `nip52_calendar_events`
  - `nip58_badges`
  - `nip38_user_status`
  - `nip61_nutzaps`
  - `nip89_handlers`
  - `nip47_wallet_connect`
- removed storage-wrapper builder types:
  - `nip28_public_chat.BuiltJson`
  - `nip71_video_events.BuiltField`
  - `nip92_media_attachments.BuiltField`
- flattened `Response.result` shape in:
  - `nip46_remote_signing`
  - `nip86_relay_management`
- downstream callers that reference those public types directly need to update symbol names or
  result-shape pattern matches
- migration guide:
  - [docs/guides/migrating-from-0.1.0-rc.2.md](docs/guides/migrating-from-0.1.0-rc.2.md)

### Compatibility Notes

- Zig toolchain floor for this RC line remains `0.15.2`
- optional I6 exports remain build-flag gated
- wire formats, deterministic crypto behavior, and kernel-vs-SDK scope are unchanged by this RC
- ownership stays caller-owned and buffer-explicit; wrapper removals simplify that surface rather
  than weakening it

### Docs And Examples

- updated the migration guide for downstream callers moving forward from `rc.2`
- updated public examples and contract checks to teach the canonical names
- kept route-level docs and examples aligned with the remediated public surface

### Verification

- `zig build lint`
- `zig build test --summary all`
- `zig build`
- `zig build release-check`

### Upgrade Guidance

- if you depend on `noztr-core`, review [docs/guides/migrating-from-0.1.0-rc.2.md](docs/guides/migrating-from-0.1.0-rc.2.md)
- update explicit public type references and any direct `Response.result` shape matches in `nip46`
  or `nip86`
- refresh generated symbol indexes, wrappers, or local LLM context packs so they reflect the
  current canonical names

## [0.1.0-rc.2] - 2026-03-22

Release type: breaking rc

### Summary

Second public release candidate for `noztr-core`.

This RC keeps the kernel/runtime boundary and protocol surface stable, but tightens the public API
teaching surface after the first public cut: temporary naming aliases are gone, public error names
now consistently prefer descriptive names inside module namespaces, and a narrow `zig fmt`-based
lint gate is now part of the documented verification path.

### Public Highlights

- removed temporary compatibility aliases from the public API and kept only the canonical names
- normalized public error type names toward descriptive module-local names instead of short-lived
  numeric `NipXXError` symbols
- added `zig build lint` as a narrow, functional formatting gate using `zig fmt --check`
- updated the migration guide and public style guide to make the naming rule explicit

### Breaking Changes

- removed temporary public naming aliases introduced during the API-naming normalization pass
- changed public error type names across the exported surface toward descriptive names inside module
  namespaces
- downstream callers should update any explicit error type references and any old alias symbol usage
- migration guide:
  - [docs/guides/migrating-from-0.1.0-rc.1.md](docs/guides/migrating-from-0.1.0-rc.1.md)

### Compatibility Notes

- Zig toolchain floor for this RC line remains `0.15.2`
- optional I6 exports remain build-flag gated
- these changes are naming- and contract-surface changes only; they do not change wire formats,
  ownership posture, or kernel-vs-SDK scope

### Docs And Examples

- updated the public migration guide for post-`rc.1` callers
- updated the public style guide to prefer descriptive names inside module namespaces
- updated release-facing verification docs to include `zig build lint`

### Verification

- `zig build lint`
- `zig build test --summary all`
- `zig build`

## [0.1.0-rc.1] - 2026-03-21

Release type: rc

### Summary

First intentional public release candidate for `noztr-core`.

This RC establishes the documented protocol-kernel surface, adds first-class native legacy
`NIP-04` DM support, and consolidates shared trust-boundary helpers behind clearer internal
contracts.

### Added

- first-class native `NIP-04` legacy direct-message support under `noztr.nip04`
- local encrypt/decrypt, canonical `ciphertext?iv=...` payload handling, and strict `kind:4`
  event-shape parsing for legacy DMs
- public docs surface under `docs/`
- public task and example routing
- public ownership, performance, compatibility, and versioning notes
- public `CONTRIBUTING.md`
- public `CHANGELOG.md`
- `NIP-04` examples for local crypto, DM build/sign/parse/verify, and adversarial malformed-input
  coverage

### Changed

- internal planning, audit, and process docs moved to local-only `.private-docs/`
- public docs and examples now form the tracked user-facing documentation surface
- shared lower-hex, URL, relay-URL, and private-JSON boundary helpers are centralized behind
  explicit internal helper modules
- strict `NIP-04` DM parsing now accepts standard reply `e`-tag forms for better interoperability

### Breaking Changes

- none intended for the first public RC line
- the public line remains pre-`1.0.0`, so compatibility should still be treated conservatively

### Compatibility Notes

- Zig toolchain floor for this RC line is `0.15.2`
- `NIP-04` support is limited to strict legacy kind-4 DMs
- deprecated `NIP-04` private-list compatibility remains out of scope

### Docs And Examples

- updated release-facing docs under `README.md`, `docs/`, and `examples/README.md`
- added `examples/nip04_example.zig`
- added `examples/nip04_dm_recipe.zig`
- added `examples/nip04_adversarial_example.zig`

### Verification

- `zig build test --summary all`
- `zig build`

### Notes

- Treat this as a release candidate, not a long-established stable compatibility line.

## Format

Each release entry should include:

- version and date
- whether the release is additive, corrective, or breaking
- public API additions
- public API removals or breaking changes
- typed error or ownership contract changes
- docs/examples updates that materially affect downstream use
