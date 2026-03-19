const std = @import("std");
const build_options = @import("build_options");
const i6_extensions_enabled = build_options.enable_i6_extensions;

/// Strict-by-default shared limits used by v1 module contracts.
pub const limits = @import("limits.zig");

/// Strict-by-default typed errors used by v1 module contracts.
pub const errors = @import("errors.zig");

/// Canonical module namespace exports (phase-aligned).
/// Phase I1 concrete export for the NIP-01 event module.
pub const nip01_event = @import("nip01_event.zig");

/// Phase I1 concrete export for the NIP-01 filter module.
pub const nip01_filter = @import("nip01_filter.zig");

/// Phase I2 concrete export for the NIP-01 message module.
pub const nip01_message = @import("nip01_message.zig");

/// Phase I2 concrete export for the NIP-42 auth module.
pub const nip42_auth = @import("nip42_auth.zig");

/// Phase I2 concrete export for the NIP-70 protected-event module.
pub const nip70_protected = @import("nip70_protected.zig");

/// Phase I2 concrete export for the NIP-11 relay information module.
pub const nip11 = @import("nip11.zig");

/// Phase I3 concrete export for the NIP-09 deletion module.
pub const nip09_delete = @import("nip09_delete.zig");

/// Phase I3 concrete export for the NIP-40 expiration module.
pub const nip40_expire = @import("nip40_expire.zig");

/// Post-kernel requested-loop concrete export for the NIP-94 file metadata module.
pub const nip94_file_metadata = @import("nip94_file_metadata.zig");

/// Post-kernel requested-loop concrete export for the NIP-92 media-attachment module.
pub const nip92_media_attachments = @import("nip92_media_attachments.zig");

/// Post-kernel requested-loop concrete export for the NIP-99 classified-listing module.
pub const nip99_classified_listings = @import("nip99_classified_listings.zig");

/// Post-kernel requested-loop concrete export for the NIP-B0 web-bookmarking module.
pub const nipb0_web_bookmarking = @import("nipb0_web_bookmarking.zig");

/// Post-kernel requested-loop concrete export for the NIP-C0 code-snippet module.
pub const nipc0_code_snippets = @import("nipc0_code_snippets.zig");

/// Post-kernel requested-loop concrete export for the NIP-64 chess PGN module.
pub const nip64_chess_pgn = @import("nip64_chess_pgn.zig");

/// Post-kernel requested-loop concrete export for the NIP-88 polls module.
pub const nip88_polls = @import("nip88_polls.zig");

/// Post-kernel requested-loop split concrete export for the NIP-98 HTTP-auth module.
pub const nip98_http_auth = @import("nip98_http_auth.zig");

/// Post-kernel requested-loop split concrete export for the NIP-B7 Blossom module.
pub const nipb7_blossom_servers = @import("nipb7_blossom_servers.zig");

/// Phase I3 concrete export for the NIP-13 proof-of-work module.
pub const nip13_pow = @import("nip13_pow.zig");

/// Phase I4 concrete export for the NIP-19 bech32 identity module.
pub const nip19_bech32 = @import("nip19_bech32.zig");

/// Phase I4 concrete export for the NIP-21 URI module.
pub const nip21_uri = @import("nip21_uri.zig");

/// Phase I4 concrete export for the NIP-02 contacts module.
pub const nip02_contacts = @import("nip02_contacts.zig");

/// Phase I4 concrete export for the NIP-65 relay metadata module.
pub const nip65_relays = @import("nip65_relays.zig");

/// Phase H concrete export for the NIP-10 thread/reply helper module.
pub const nip10_threads = @import("nip10_threads.zig");

/// Phase H third requested-loop concrete export for the NIP-14 subjects module.
pub const nip14_subjects = @import("nip14_subjects.zig");

/// Phase H concrete export for the NIP-18 repost module.
pub const nip18_reposts = @import("nip18_reposts.zig");

/// Phase H concrete export for the NIP-22 comment module.
pub const nip22_comments = @import("nip22_comments.zig");

/// Phase H concrete export for the NIP-27 text-reference module.
pub const nip27_references = @import("nip27_references.zig");

/// Phase H third requested-loop split concrete export for the NIP-28 public-chat module.
pub const nip28_public_chat = @import("nip28_public_chat.zig");

/// Phase H third requested-loop concrete export for the NIP-30 custom-emoji module.
pub const nip30_custom_emoji = @import("nip30_custom_emoji.zig");

/// Phase H concrete export for the NIP-25 reactions module.
pub const nip25_reactions = @import("nip25_reactions.zig");

/// Phase H concrete export for the NIP-51 public-list module.
pub const nip51_lists = @import("nip51_lists.zig");

/// Phase H concrete export for the NIP-46 remote-signing module.
pub const nip46_remote_signing = @import("nip46_remote_signing.zig");

/// Post-kernel requested-loop split concrete export for the NIP-47 wallet-connect module.
pub const nip47_wallet_connect = @import("nip47_wallet_connect.zig");

/// Post-kernel requested-loop concrete export for the NIP-49 private-key encryption module.
pub const nip49_private_key_encryption = @import("nip49_private_key_encryption.zig");

/// Phase H concrete export for the NIP-06 mnemonic derivation module.
pub const nip06_mnemonic = @import("nip06_mnemonic.zig");

/// Post-kernel concrete export for bounded BIP-85 derivation helpers.
pub const bip85_derivation = @import("bip85_derivation.zig");

/// Post-kernel concrete export for bounded Nostr key-derivation and signing helpers.
pub const nostr_keys = @import("nostr_keys.zig");

/// Phase H concrete export for the NIP-23 long-form metadata module.
pub const nip23_long_form = @import("nip23_long_form.zig");

/// Phase H concrete export for the NIP-24 extra metadata module.
pub const nip24_extra_metadata = @import("nip24_extra_metadata.zig");

/// Phase H deferred-backlog concrete export for the NIP-03 OpenTimestamps module.
pub const nip03_opentimestamps = @import("nip03_opentimestamps.zig");

/// Phase H deferred-backlog concrete export for the NIP-17 private direct-message module.
pub const nip17_private_messages = @import("nip17_private_messages.zig");

/// Phase H deferred-backlog concrete export for the NIP-39 external-identity module.
pub const nip39_external_identities = @import("nip39_external_identities.zig");

/// Phase H deferred-backlog concrete export for the NIP-29 relay-group module.
pub const nip29_relay_groups = @import("nip29_relay_groups.zig");

/// Phase H second requested-loop concrete export for the NIP-31 alt-tag module.
pub const nip31_alt_tags = @import("nip31_alt_tags.zig");

/// Post-Phase-H concrete export for the NIP-73 external-id module.
pub const nip73_external_ids = @import("nip73_external_ids.zig");

/// Post-Phase-H concrete export for the NIP-32 labeling module.
pub const nip32_labeling = @import("nip32_labeling.zig");

/// Phase H second requested-loop split concrete export for the NIP-34 git metadata module.
pub const nip34_git = @import("nip34_git.zig");

/// Post-Phase-H concrete export for the NIP-36 content-warning module.
pub const nip36_content_warning = @import("nip36_content_warning.zig");

/// Post-Phase-H concrete export for the NIP-56 reporting module.
pub const nip56_reporting = @import("nip56_reporting.zig");

/// Post-Phase-H concrete export for the NIP-05 identity module.
pub const nip05_identity = @import("nip05_identity.zig");

/// Post-Phase-H concrete export for the NIP-26 delegation module.
pub const nip26_delegation = @import("nip26_delegation.zig");

/// Post-Phase-H concrete export for the NIP-37 drafts module.
pub const nip37_drafts = @import("nip37_drafts.zig");

/// Phase H third requested-loop concrete export for the NIP-38 user-status module.
pub const nip38_user_status = @import("nip38_user_status.zig");

/// Post-Phase-H concrete export for the NIP-58 badges module.
pub const nip58_badges = @import("nip58_badges.zig");

/// Phase H second requested-loop concrete export for the NIP-52 calendar-events module.
pub const nip52_calendar_events = @import("nip52_calendar_events.zig");

/// Phase H second requested-loop split concrete export for the NIP-53 live-activities module.
pub const nip53_live_activities = @import("nip53_live_activities.zig");

/// Phase H second requested-loop split concrete export for the NIP-54 wiki module.
pub const nip54_wiki = @import("nip54_wiki.zig");

/// Post-Phase-H concrete export for the NIP-84 highlights module.
pub const nip84_highlights = @import("nip84_highlights.zig");

/// Post-Phase-H split concrete export for the NIP-57 zaps module.
pub const nip57_zaps = @import("nip57_zaps.zig");

/// Phase H third requested-loop split concrete export for the NIP-61 nutzaps module.
pub const nip61_nutzaps = @import("nip61_nutzaps.zig");

/// Post-Phase-H split concrete export for the NIP-86 relay-management module.
pub const nip86_relay_management = @import("nip86_relay_management.zig");

/// Phase H third requested-loop concrete export for the NIP-75 zap-goals module.
pub const nip75_zap_goals = @import("nip75_zap_goals.zig");

/// Phase I5 concrete export for the NIP-44 encrypted direct-message module.
pub const nip44 = @import("nip44.zig");

/// Phase I5 concrete export for the NIP-59 gift-wrap module.
pub const nip59_wrap = @import("nip59_wrap.zig");

/// Phase H second requested-loop concrete export for the NIP-78 app-data module.
pub const nip78_app_data = @import("nip78_app_data.zig");

/// Phase H third requested-loop split concrete export for the NIP-89 handlers module.
pub const nip89_handlers = @import("nip89_handlers.zig");

/// Phase I6 concrete export for the NIP-45 count module.
pub const nip45_count = if (i6_extensions_enabled) @import("nip45_count.zig") else struct {};

/// Phase I6 concrete export for the NIP-50 search module.
pub const nip50_search = if (i6_extensions_enabled) @import("nip50_search.zig") else struct {};

/// Phase I6 concrete export for the NIP-77 negentropy module.
pub const nip77_negentropy =
    if (i6_extensions_enabled) @import("nip77_negentropy.zig") else struct {};

/// Canonical trust-boundary wrappers and typed error surfaces.
/// Canonical trust-boundary PoW wrapper with id verification.
pub const pow_meets_difficulty_verified_id = nip13_pow.pow_meets_difficulty_verified_id;

/// Typed error surface for canonical trust-boundary PoW wrapper.
pub const PowVerifiedIdError = nip13_pow.PowVerifiedIdError;

/// Canonical trust-boundary delete-target extraction wrapper.
pub const delete_extract_targets_checked = nip09_delete.delete_extract_targets_checked;

/// Typed error surface for canonical trust-boundary delete extraction wrapper.
pub const DeleteExtractCheckedError = nip09_delete.DeleteExtractCheckedError;

/// Canonical transcript marker for client `REQ` state transitions.
pub const transcript_mark_client_req = nip01_message.transcript_mark_client_req;

/// Canonical transcript relay-application helper for state transitions.
pub const transcript_apply_relay = nip01_message.transcript_apply_relay;

fn use_typed_error_for_smoke(fail: bool) errors.EventVerifyError!void {
    std.debug.assert(fail);
    std.debug.assert(!@inComptime());

    if (fail) {
        return error.InvalidId;
    }

    return;
}

test "root exports limits and error namespaces" {
    try std.testing.expect(limits.event_json_max >= limits.content_bytes_max);
    try std.testing.expect(@TypeOf(nip01_event.EventParseError) == type);
    try std.testing.expect(@TypeOf(nip01_filter.FilterParseError) == type);
    try std.testing.expect(@TypeOf(nip01_message.MessageParseError) == type);
    try std.testing.expect(@TypeOf(nip42_auth.AuthError) == type);
    try std.testing.expect(@TypeOf(nip70_protected.ProtectedError) == type);
    try std.testing.expect(@TypeOf(nip11.Nip11Error) == type);
    try std.testing.expect(@TypeOf(nip09_delete.DeleteError) == type);
    try std.testing.expect(@TypeOf(nip40_expire.ExpirationError) == type);
    try std.testing.expect(@TypeOf(nip92_media_attachments.Nip92Error) == type);
    try std.testing.expect(@TypeOf(nip94_file_metadata.Nip94Error) == type);
    try std.testing.expect(@TypeOf(nip99_classified_listings.Nip99Error) == type);
    try std.testing.expect(@TypeOf(nipb0_web_bookmarking.WebBookmarkError) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.CodeSnippetError) == type);
    try std.testing.expect(@TypeOf(nip64_chess_pgn.Nip64Error) == type);
    try std.testing.expect(@TypeOf(nip88_polls.Nip88Error) == type);
    try std.testing.expect(@TypeOf(nip98_http_auth.Nip98Error) == type);
    try std.testing.expect(@TypeOf(nipb7_blossom_servers.NipB7Error) == type);
    try std.testing.expect(@TypeOf(nip13_pow.PowError) == type);
    try std.testing.expect(@TypeOf(nip14_subjects.Nip14Error) == type);
    try std.testing.expect(@TypeOf(nip19_bech32.Nip19Error) == type);
    try std.testing.expect(@TypeOf(nip21_uri.Nip21Error) == type);
    try std.testing.expect(@TypeOf(nip02_contacts.ContactsError) == type);
    try std.testing.expect(@TypeOf(nip65_relays.RelaysError) == type);
    try std.testing.expect(@TypeOf(nip10_threads.ThreadError) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.Nip28Error) == type);
    try std.testing.expect(@TypeOf(nip30_custom_emoji.Nip30Error) == type);
    try std.testing.expect(@TypeOf(nip18_reposts.RepostError) == type);
    try std.testing.expect(@TypeOf(nip22_comments.CommentError) == type);
    try std.testing.expect(@TypeOf(nip27_references.ReferencesError) == type);
    try std.testing.expect(@TypeOf(nip25_reactions.ReactionError) == type);
    try std.testing.expect(@TypeOf(nip51_lists.ListError) == type);
    try std.testing.expect(@TypeOf(nip51_lists.PrivateListError) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.Nip46Error) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.NwcError) == type);
    try std.testing.expect(@TypeOf(nip49_private_key_encryption.Nip49Error) == type);
    try std.testing.expect(@TypeOf(nip06_mnemonic.Nip06Error) == type);
    try std.testing.expect(@TypeOf(bip85_derivation.Bip85Error) == type);
    try std.testing.expect(@TypeOf(nostr_keys.NostrKeysError) == type);
    try std.testing.expect(@TypeOf(nip23_long_form.LongFormError) == type);
    try std.testing.expect(@TypeOf(nip24_extra_metadata.Nip24Error) == type);
    try std.testing.expect(@TypeOf(nip03_opentimestamps.OpenTimestampsError) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.Nip17Error) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.Nip17RelayListError) == type);
    try std.testing.expect(@TypeOf(nip39_external_identities.Nip39Error) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.Nip29Error) == type);
    try std.testing.expect(@TypeOf(nip31_alt_tags.Nip31Error) == type);
    try std.testing.expect(@TypeOf(nip73_external_ids.Nip73Error) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.Nip32Error) == type);
    try std.testing.expect(@TypeOf(nip34_git.Nip34Error) == type);
    try std.testing.expect(@TypeOf(nip36_content_warning.Nip36Error) == type);
    try std.testing.expect(@TypeOf(nip38_user_status.Nip38Error) == type);
    try std.testing.expect(@TypeOf(nip56_reporting.Nip56Error) == type);
    try std.testing.expect(@TypeOf(nip05_identity.Nip05Error) == type);
    try std.testing.expect(@TypeOf(nip26_delegation.Nip26Error) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.Nip52Error) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.Nip53Error) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.Nip54Error) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.Nip57Error) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.Nip61Error) == type);
    try std.testing.expect(@TypeOf(nip75_zap_goals.Nip75Error) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.Nip86Error) == type);
    try std.testing.expect(@TypeOf(nip44.Nip44Error) == type);
    try std.testing.expect(@TypeOf(nip59_wrap.WrapError) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.Nip78Error) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.Nip89Error) == type);
    try std.testing.expectEqual(i6_extensions_enabled, @hasDecl(nip45_count, "CountError"));
    try std.testing.expectEqual(i6_extensions_enabled, @hasDecl(nip50_search, "SearchError"));
    try std.testing.expectEqual(
        i6_extensions_enabled,
        @hasDecl(nip77_negentropy, "NegentropyError"),
    );
    try std.testing.expect(@TypeOf(nip19_bech32.Nip19Entity) == type);
    try std.testing.expect(@TypeOf(nip21_uri.Nip21Reference) == type);
    try std.testing.expect(@TypeOf(nip02_contacts.ContactEntry) == type);
    try std.testing.expect(@TypeOf(nip65_relays.RelayPermission) == type);
    try std.testing.expect(@TypeOf(nip10_threads.ThreadInfo) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.ChannelMetadata) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.ChannelMessageInfo) == type);
    try std.testing.expect(@TypeOf(nip30_custom_emoji.EmojiTagInfo) == type);
    try std.testing.expect(@TypeOf(nip18_reposts.RepostTarget) == type);
    try std.testing.expect(@TypeOf(nip22_comments.CommentInfo) == type);
    try std.testing.expect(@TypeOf(nip27_references.ContentReference) == type);
    try std.testing.expect(@TypeOf(nip25_reactions.ReactionTarget) == type);
    try std.testing.expect(@TypeOf(nip51_lists.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip51_lists.BookmarkBuilderItem) == type);
    try std.testing.expect(@TypeOf(nip51_lists.ListItem) == type);
    try std.testing.expect(@TypeOf(nip51_lists.PrivateListInfo) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ConnectRequest) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.PubkeyTextRequest) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.BuiltRequest) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ConnectResult) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ParsedRequest) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.DiscoveryInfo) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.ConnectionUri) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Request) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Response) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Notification) == type);
    try std.testing.expect(@TypeOf(nip23_long_form.LongFormMetadata) == type);
    try std.testing.expect(@TypeOf(nip23_long_form.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.LicenseInfo) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.RepoReference) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.CodeSnippetInfo) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip64_chess_pgn.ChessPgnInfo) == type);
    try std.testing.expect(@TypeOf(nip64_chess_pgn.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip88_polls.PollType) == type);
    try std.testing.expect(@TypeOf(nip88_polls.PollInfo) == type);
    try std.testing.expect(@TypeOf(nip88_polls.PollResponseInfo) == type);
    try std.testing.expect(@TypeOf(nip88_polls.OptionTally) == type);
    try std.testing.expect(@TypeOf(nip88_polls.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nipb7_blossom_servers.BlossomServerListInfo) == type);
    try std.testing.expect(@TypeOf(nipb7_blossom_servers.BlobReference) == type);
    try std.testing.expect(@TypeOf(nipb7_blossom_servers.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip24_extra_metadata.MetadataExtras) == type);
    try std.testing.expect(@TypeOf(nip24_extra_metadata.CommonTagInfo) == type);
    try std.testing.expect(@TypeOf(nip24_extra_metadata.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip03_opentimestamps.OpenTimestampsAttestation) == type);
    try std.testing.expect(@TypeOf(nip03_opentimestamps.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.DmRecipient) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.DmReplyRef) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.DmMessageInfo) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.FileEncryptionAlgorithm) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.FileDimensions) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.FileMessageInfo) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip14_subjects.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip31_alt_tags.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip39_external_identities.IdentityProvider) == type);
    try std.testing.expect(@TypeOf(nip39_external_identities.IdentityClaim) == type);
    try std.testing.expect(@TypeOf(nip39_external_identities.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupMetadataFlag) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupStateUser) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupState) == type);
    try std.testing.expect(@TypeOf(nip73_external_ids.ExternalIdKind) == type);
    try std.testing.expect(@TypeOf(nip73_external_ids.ExternalId) == type);
    try std.testing.expect(@TypeOf(nip73_external_ids.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.LabelNamespace) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.Label) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.LabelTarget) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.LabelEventInfo) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.SelfLabelInfo) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip34_git.RepositoryAnnouncementInfo) == type);
    try std.testing.expect(@TypeOf(nip34_git.RepositoryStateRef) == type);
    try std.testing.expect(@TypeOf(nip34_git.RepositoryStateInfo) == type);
    try std.testing.expect(@TypeOf(nip34_git.UserGraspListInfo) == type);
    try std.testing.expect(@TypeOf(nip34_git.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip36_content_warning.ContentWarningInfo) == type);
    try std.testing.expect(@TypeOf(nip36_content_warning.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip38_user_status.UserStatusInfo) == type);
    try std.testing.expect(@TypeOf(nip38_user_status.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip56_reporting.ReportType) == type);
    try std.testing.expect(@TypeOf(nip56_reporting.ReportInfo) == type);
    try std.testing.expect(@TypeOf(nip56_reporting.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip05_identity.Address) == type);
    try std.testing.expect(@TypeOf(nip05_identity.Profile) == type);
    try std.testing.expect(@TypeOf(nip26_delegation.DelegationTag) == type);
    try std.testing.expect(@TypeOf(nip26_delegation.DelegationCondition) == type);
    try std.testing.expect(@TypeOf(nip26_delegation.DelegationConditions) == type);
    try std.testing.expect(@TypeOf(nip26_delegation.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.Nip57Error) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.ZapRequest) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.ZapReceipt) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.Nip86Error) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.PubkeyReason) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.EventIdReason) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.IpReason) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.Request) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.Response) == type);
    try std.testing.expect(@TypeOf(nip37_drafts.DraftWrapInfo) == type);
    try std.testing.expect(@TypeOf(nip37_drafts.DraftWrapPlaintextInfo) == type);
    try std.testing.expect(@TypeOf(nip37_drafts.PrivateRelayListInfo) == type);
    try std.testing.expect(@TypeOf(nip37_drafts.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip58_badges.ImageInfo) == type);
    try std.testing.expect(@TypeOf(nip58_badges.BadgeDefinitionReference) == type);
    try std.testing.expect(@TypeOf(nip58_badges.BadgeDefinitionInfo) == type);
    try std.testing.expect(@TypeOf(nip58_badges.BadgeAwardRecipient) == type);
    try std.testing.expect(@TypeOf(nip58_badges.BadgeAwardInfo) == type);
    try std.testing.expect(@TypeOf(nip58_badges.BadgeAwardEventReference) == type);
    try std.testing.expect(@TypeOf(nip58_badges.ProfileBadgePair) == type);
    try std.testing.expect(@TypeOf(nip58_badges.ProfileBadgesInfo) == type);
    try std.testing.expect(@TypeOf(nip58_badges.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.CalendarParticipant) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.CalendarCoordinate) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.DateCalendarEventInfo) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.TimeCalendarEventInfo) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.CalendarInfo) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.CalendarRsvpInfo) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.LiveActivityParticipant) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.LiveActivityCoordinate) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.LiveChatReply) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.LiveActivityInfo) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.LiveChatInfo) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.WikiArticleReference) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.WikiEventReference) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.WikiArticleInfo) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.WikiMergeRequestInfo) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.WikiRedirectInfo) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.InformationalInfo) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.NutzapInfo) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.RedemptionInfo) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip75_zap_goals.GoalInfo) == type);
    try std.testing.expect(@TypeOf(nip75_zap_goals.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.AppDataInfo) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.RecommendationInfo) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.HandlerInfo) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.EventSource) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.AddressSource) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.UrlReference) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.HighlightSource) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.HighlightAttribution) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.HighlightInfo) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupMetadata) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupAdmin) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupReference) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupMember) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupRole) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupAdminsInfo) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupMembersInfo) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupRolesInfo) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupJoinRequestInfo) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupLeaveRequestInfo) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupPutUserInfo) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupRemoveUserInfo) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.AppDataInfo) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.BuiltTag) == type);
    try std.testing.expect(
        @TypeOf(nip06_mnemonic.mnemonic_validate) ==
            fn ([]const u8) nip06_mnemonic.Nip06Error!void,
    );
    try std.testing.expect(
        @TypeOf(nip06_mnemonic.mnemonic_to_seed) ==
            fn ([]u8, []const u8, ?[]const u8) nip06_mnemonic.Nip06Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip06_mnemonic.derive_nostr_secret_key_from_seed) ==
            fn ([]u8, []const u8, u32) nip06_mnemonic.Nip06Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip06_mnemonic.derive_nostr_secret_key) ==
            fn ([]u8, []const u8, ?[]const u8, u32) nip06_mnemonic.Nip06Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(bip85_derivation.derive_bip39_mnemonic) ==
            fn (
                []u8,
                []const u8,
                ?[]const u8,
                bip85_derivation.Bip39WordCount,
                u32,
            ) bip85_derivation.Bip85Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip23_long_form.long_form_extract) ==
            fn (
                *const nip01_event.Event,
                [][]const u8,
            ) nip23_long_form.LongFormError!nip23_long_form.LongFormMetadata,
    );
    try std.testing.expect(
        @TypeOf(nip23_long_form.long_form_build_identifier_tag) ==
            fn (
                *nip23_long_form.BuiltTag,
                []const u8,
            ) nip23_long_form.LongFormError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip24_extra_metadata.metadata_extras_parse_json) ==
            fn (
                []const u8,
                std.mem.Allocator,
            ) nip24_extra_metadata.Nip24Error!nip24_extra_metadata.MetadataExtras,
    );
    try std.testing.expect(
        @TypeOf(nip03_opentimestamps.opentimestamps_extract) ==
            fn (
                []u8,
                *const nip01_event.Event,
            ) nip03_opentimestamps.OpenTimestampsError!nip03_opentimestamps.OpenTimestampsAttestation,
    );
    try std.testing.expect(
        @TypeOf(nip03_opentimestamps.opentimestamps_validate_local_proof) ==
            fn (
                *const nip03_opentimestamps.OpenTimestampsAttestation,
                []const u8,
            ) nip03_opentimestamps.OpenTimestampsError!void,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_file_message_parse) ==
            fn (
                *const nip01_event.Event,
                []nip17_private_messages.DmRecipient,
                [][]const u8,
                [][]const u8,
            ) nip17_private_messages.Nip17Error!nip17_private_messages.FileMessageInfo,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_unwrap_file_message) ==
            fn (
                *nip01_event.Event,
                *const [32]u8,
                *const nip01_event.Event,
                []nip17_private_messages.DmRecipient,
                [][]const u8,
                [][]const u8,
                std.mem.Allocator,
            ) nip17_private_messages.Nip17Error!nip17_private_messages.FileMessageInfo,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_reference_parse) ==
            fn ([]const u8) nip29_relay_groups.Nip29Error!nip29_relay_groups.GroupReference,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_roles_extract) ==
            fn (
                *const nip01_event.Event,
                []nip29_relay_groups.GroupRole,
            ) nip29_relay_groups.Nip29Error!nip29_relay_groups.GroupRolesInfo,
    );
    try std.testing.expect(
        @TypeOf(nip03_opentimestamps.opentimestamps_build_event_tag) ==
            fn (
                *nip03_opentimestamps.BuiltTag,
                []const u8,
                ?[]const u8,
            ) nip03_opentimestamps.OpenTimestampsError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_message_parse) ==
            fn (
                *const nip01_event.Event,
                []nip17_private_messages.DmRecipient,
            ) nip17_private_messages.Nip17Error!nip17_private_messages.DmMessageInfo,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_unwrap_message) ==
            fn (
                *nip01_event.Event,
                *const [32]u8,
                *const nip01_event.Event,
                []nip17_private_messages.DmRecipient,
                std.mem.Allocator,
            ) nip17_private_messages.Nip17Error!nip17_private_messages.DmMessageInfo,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_relay_list_extract) ==
            fn (
                *const nip01_event.Event,
                [][]const u8,
            ) nip17_private_messages.Nip17RelayListError!u16,
    );
    try std.testing.expect(@TypeOf(nip17_private_messages.BuiltFileMetadataTag) == type);
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_build_file_type_tag) ==
            fn (
                *nip17_private_messages.BuiltFileMetadataTag,
                []const u8,
            ) nip17_private_messages.Nip17Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_build_file_size_tag) ==
            fn (
                *nip17_private_messages.BuiltFileMetadataTag,
                u64,
            ) nip17_private_messages.Nip17Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip39_external_identities.identity_claims_extract) ==
            fn (
                *const nip01_event.Event,
                []nip39_external_identities.IdentityClaim,
            ) nip39_external_identities.Nip39Error!u16,
    );
    try std.testing.expect(
        @TypeOf(nip39_external_identities.identity_claim_build_tag) ==
            fn (
                *nip39_external_identities.BuiltTag,
                *const nip39_external_identities.IdentityClaim,
            ) nip39_external_identities.Nip39Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip39_external_identities.identity_claim_build_proof_url) ==
            fn (
                []u8,
                *const nip39_external_identities.IdentityClaim,
            ) nip39_external_identities.Nip39Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_metadata_extract) ==
            fn (*const nip01_event.Event) nip29_relay_groups.Nip29Error!nip29_relay_groups.GroupMetadata,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_admins_extract) ==
            fn (
                *const nip01_event.Event,
                []nip29_relay_groups.GroupAdmin,
                [][]const u8,
            ) nip29_relay_groups.Nip29Error!nip29_relay_groups.GroupAdminsInfo,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_state_apply_event) ==
            fn (
                *nip29_relay_groups.GroupState,
                *const nip01_event.Event,
            ) nip29_relay_groups.Nip29Error!void,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_state_apply_events) ==
            fn (
                *nip29_relay_groups.GroupState,
                []const nip01_event.Event,
            ) nip29_relay_groups.Nip29Error!void,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_members_extract) ==
            fn (
                *const nip01_event.Event,
                []nip29_relay_groups.GroupMember,
            ) nip29_relay_groups.Nip29Error!nip29_relay_groups.GroupMembersInfo,
    );
    try std.testing.expect(
        @TypeOf(nip24_extra_metadata.common_tags_extract) ==
            fn (
                []const nip01_event.EventTag,
                [][]const u8,
                [][]const u8,
            ) nip24_extra_metadata.Nip24Error!nip24_extra_metadata.CommonTagInfo,
    );
    try std.testing.expect(
        @TypeOf(nip24_extra_metadata.common_tags_extract_with_external_ids) ==
            fn (
                []const nip01_event.EventTag,
                [][]const u8,
                []nip73_external_ids.ExternalId,
                [][]const u8,
            ) nip24_extra_metadata.Nip24Error!nip24_extra_metadata.CommonTagInfo,
    );
    try std.testing.expect(
        @TypeOf(nip73_external_ids.external_id_parse) ==
            fn (
                []const u8,
                ?[]const u8,
            ) nip73_external_ids.Nip73Error!nip73_external_ids.ExternalId,
    );
    try std.testing.expect(
        @TypeOf(nip73_external_ids.external_id_build_i_tag) ==
            fn (
                *nip73_external_ids.BuiltTag,
                *const nip73_external_ids.ExternalId,
            ) nip73_external_ids.Nip73Error!nip01_event.EventTag,
    );
    try std.testing.expect(@TypeOf(nip46_remote_signing.Message) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ConnectionUri) == type);
    try std.testing.expect(@TypeOf(PowVerifiedIdError) == type);
    try std.testing.expect(@TypeOf(DeleteExtractCheckedError) == type);
    try std.testing.expect(
        @TypeOf(nip51_lists.list_private_serialize_json) ==
            fn ([]u8, []const nip01_event.EventTag) nip51_lists.PrivateListError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.list_private_extract_json) ==
            fn (
                u32,
                []const u8,
                []nip51_lists.ListItem,
                std.mem.Allocator,
            ) nip51_lists.PrivateListError!nip51_lists.PrivateListInfo,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.list_private_extract_nip44) ==
            fn (
                []u8,
                *const nip01_event.Event,
                *const [32]u8,
                []nip51_lists.ListItem,
                std.mem.Allocator,
            ) nip51_lists.PrivateListError!nip51_lists.PrivateListInfo,
    );
    try std.testing.expect(
        @TypeOf(nip19_bech32.nip19_encode) ==
            fn ([]u8, nip19_bech32.Nip19Entity) nip19_bech32.Nip19Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip19_bech32.nip19_decode) ==
            fn ([]const u8, []u8) nip19_bech32.Nip19Error!nip19_bech32.Nip19Entity,
    );
    try std.testing.expect(
        @TypeOf(nip21_uri.nip21_parse) ==
            fn ([]const u8, []u8) nip21_uri.Nip21Error!nip21_uri.Nip21Reference,
    );
    try std.testing.expect(@TypeOf(nip21_uri.nip21_is_valid) == fn ([]const u8, []u8) bool);
    try std.testing.expect(
        @TypeOf(nip02_contacts.contacts_extract) ==
            fn (
                *const nip01_event.Event,
                []nip02_contacts.ContactEntry,
            ) nip02_contacts.ContactsError!u16,
    );
    try std.testing.expect(
        @TypeOf(nip65_relays.relay_marker_parse) ==
            fn ([]const u8) error{InvalidMarker}!nip65_relays.RelayMarker,
    );
    try std.testing.expect(
        @TypeOf(nip65_relays.relay_list_extract) ==
            fn (
                *const nip01_event.Event,
                []nip65_relays.RelayPermission,
            ) nip65_relays.RelaysError!u16,
    );
    try std.testing.expect(
        @TypeOf(nip10_threads.thread_extract) ==
            fn (
                *const nip01_event.Event,
                []nip10_threads.ThreadReference,
            ) nip10_threads.ThreadError!nip10_threads.ThreadInfo,
    );
    try std.testing.expect(
        @TypeOf(nip18_reposts.repost_parse) ==
            fn (
                *const nip01_event.Event,
            ) nip18_reposts.RepostError!nip18_reposts.RepostTarget,
    );
    try std.testing.expect(
        @TypeOf(nip22_comments.comment_parse) ==
            fn (
                *const nip01_event.Event,
            ) nip22_comments.CommentError!nip22_comments.CommentInfo,
    );
    try std.testing.expect(
        @TypeOf(nip27_references.reference_extract) ==
            fn (
                []const u8,
                []nip27_references.ContentReference,
                []u8,
            ) nip27_references.ReferencesError!u16,
    );
    try std.testing.expect(
        @TypeOf(nip25_reactions.reaction_parse) ==
            fn (
                *const nip01_event.Event,
            ) nip25_reactions.ReactionError!nip25_reactions.ReactionTarget,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.list_extract) ==
            fn (
                *const nip01_event.Event,
                []nip51_lists.ListItem,
            ) nip51_lists.ListError!nip51_lists.ListInfo,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.list_build_identifier_tag) ==
            fn (
                *nip51_lists.BuiltTag,
                []const u8,
            ) nip51_lists.ListError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.bookmark_build_tag) ==
            fn (
                *nip51_lists.BuiltTag,
                nip51_lists.BookmarkBuilderItem,
            ) nip51_lists.ListError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.emoji_build_tag) ==
            fn (
                *nip51_lists.BuiltTag,
                *const nip51_lists.ListEmoji,
            ) nip51_lists.ListError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.address_parse) ==
            fn ([]const u8, std.mem.Allocator) nip05_identity.Nip05Error!nip05_identity.Address,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.address_format) ==
            fn ([]u8, *const nip05_identity.Address) nip05_identity.Nip05Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.address_compose_well_known_url) ==
            fn ([]u8, *const nip05_identity.Address) nip05_identity.Nip05Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.profile_parse_json) ==
            fn (
                *const nip05_identity.Address,
                []const u8,
                std.mem.Allocator,
            ) nip05_identity.Nip05Error!nip05_identity.Profile,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.profile_verify_json) ==
            fn (
                *const [32]u8,
                *const nip05_identity.Address,
                []const u8,
                std.mem.Allocator,
            ) nip05_identity.Nip05Error!bool,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_tag_parse) ==
            fn (nip01_event.EventTag) nip26_delegation.Nip26Error!nip26_delegation.DelegationTag,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_conditions_parse) ==
            fn (
                []const u8,
                []nip26_delegation.DelegationCondition,
            ) nip26_delegation.Nip26Error!nip26_delegation.DelegationConditions,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_conditions_format) ==
            fn (
                []u8,
                nip26_delegation.DelegationConditions,
            ) nip26_delegation.Nip26Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_message_build) ==
            fn ([]u8, *const [32]u8, []const u8) nip26_delegation.Nip26Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_signature_sign) ==
            fn (
                *[64]u8,
                *const [32]u8,
                *const [32]u8,
                []const u8,
            ) nip26_delegation.Nip26Error!void,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_signature_verify) ==
            fn (
                *const nip26_delegation.DelegationTag,
                *const [32]u8,
            ) nip26_delegation.Nip26Error!void,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_event_satisfies) ==
            fn (
                nip26_delegation.DelegationConditions,
                *const nip01_event.Event,
            ) bool,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_event_validate) ==
            fn (
                *const nip26_delegation.DelegationTag,
                *const nip01_event.Event,
                []nip26_delegation.DelegationCondition,
            ) nip26_delegation.Nip26Error!nip26_delegation.DelegationConditions,
    );
    try std.testing.expect(
        @TypeOf(nip26_delegation.delegation_tag_build) ==
            fn (
                *nip26_delegation.BuiltTag,
                *const nip26_delegation.DelegationTag,
            ) nip26_delegation.Nip26Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.message_parse_json) ==
            fn ([]const u8, std.mem.Allocator) nip46_remote_signing.Nip46Error!nip46_remote_signing.Message,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.draft_wrap_parse) ==
            fn (*const nip01_event.Event) nip37_drafts.Nip37Error!nip37_drafts.DraftWrapInfo,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.draft_wrap_decrypt_json) ==
            fn (
                []u8,
                *const nip01_event.Event,
                *const [32]u8,
                std.mem.Allocator,
            ) nip37_drafts.Nip37Error!nip37_drafts.DraftWrapPlaintextInfo,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.draft_wrap_encrypt_json) ==
            fn (
                []u8,
                *const [32]u8,
                *const [32]u8,
                []const u8,
                std.mem.Allocator,
            ) nip37_drafts.Nip37Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.private_relay_build_tag) ==
            fn (*nip37_drafts.BuiltTag, []const u8) nip37_drafts.Nip37Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.private_relay_list_serialize_json) ==
            fn ([]u8, []const nip01_event.EventTag) nip37_drafts.Nip37Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.private_relay_list_extract_json) ==
            fn (
                []const u8,
                [][]const u8,
                std.mem.Allocator,
            ) nip37_drafts.Nip37Error!nip37_drafts.PrivateRelayListInfo,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.private_relay_list_extract_nip44) ==
            fn (
                []u8,
                *const nip01_event.Event,
                *const [32]u8,
                [][]const u8,
                std.mem.Allocator,
            ) nip37_drafts.Nip37Error!nip37_drafts.PrivateRelayListInfo,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_definition_extract) ==
            fn (
                *const nip01_event.Event,
                []nip58_badges.ImageInfo,
            ) nip58_badges.Nip58Error!nip58_badges.BadgeDefinitionInfo,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_award_extract) ==
            fn (
                *const nip01_event.Event,
                []nip58_badges.BadgeAwardRecipient,
            ) nip58_badges.Nip58Error!nip58_badges.BadgeAwardInfo,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.profile_badges_extract) ==
            fn (
                *const nip01_event.Event,
                []nip58_badges.ProfileBadgePair,
            ) nip58_badges.Nip58Error!nip58_badges.ProfileBadgesInfo,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_award_validate_definition) ==
            fn (
                *const nip58_badges.BadgeAwardInfo,
                *const nip58_badges.BadgeDefinitionInfo,
            ) nip58_badges.Nip58Error!void,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.profile_badge_pair_validate) ==
            fn (
                *const nip58_badges.ProfileBadgePair,
                *const nip58_badges.BadgeAwardInfo,
                []const nip58_badges.BadgeAwardRecipient,
                *const nip58_badges.BadgeDefinitionInfo,
                *const [32]u8,
            ) nip58_badges.Nip58Error!void,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_build_identifier_tag) ==
            fn (*nip58_badges.BuiltTag, []const u8) nip58_badges.Nip58Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_build_image_tag) ==
            fn (
                *nip58_badges.BuiltTag,
                []const u8,
                ?[]const u8,
            ) nip58_badges.Nip58Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_build_definition_tag) ==
            fn (
                *nip58_badges.BuiltTag,
                *const nip58_badges.BadgeDefinitionReference,
            ) nip58_badges.Nip58Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.profile_badges_build_award_tag) ==
            fn (
                *nip58_badges.BuiltTag,
                []const u8,
                ?[]const u8,
            ) nip58_badges.Nip58Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip84_highlights.highlight_extract) ==
            fn (
                *const nip01_event.Event,
                []nip84_highlights.HighlightAttribution,
                []nip84_highlights.UrlReference,
            ) nip84_highlights.Nip84Error!nip84_highlights.HighlightInfo,
    );
    try std.testing.expect(
        @TypeOf(nip84_highlights.highlight_build_event_source_tag) ==
            fn (
                *nip84_highlights.BuiltTag,
                []const u8,
                ?[]const u8,
            ) nip84_highlights.Nip84Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip84_highlights.highlight_build_author_tag) ==
            fn (
                *nip84_highlights.BuiltTag,
                []const u8,
                ?[]const u8,
                ?[]const u8,
            ) nip84_highlights.Nip84Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip84_highlights.highlight_build_comment_tag) ==
            fn (
                *nip84_highlights.BuiltTag,
                []const u8,
            ) nip84_highlights.Nip84Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip57_zaps.zap_request_extract) ==
            fn (
                *const nip01_event.Event,
                [][]const u8,
            ) nip57_zaps.Nip57Error!nip57_zaps.ZapRequest,
    );
    try std.testing.expect(
        @TypeOf(nip57_zaps.zap_receipt_extract) ==
            fn (
                *const nip01_event.Event,
                [][]const u8,
                std.mem.Allocator,
            ) nip57_zaps.Nip57Error!nip57_zaps.ZapReceipt,
    );
    try std.testing.expect(
        @TypeOf(nip57_zaps.request_build_relays_tag) ==
            fn (
                *nip57_zaps.BuiltTag,
                []const []const u8,
            ) nip57_zaps.Nip57Error!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip86_relay_management.request_parse_json) ==
            fn (
                []const u8,
                std.mem.Allocator,
            ) nip86_relay_management.Nip86Error!nip86_relay_management.Request,
    );
    try std.testing.expect(
        @TypeOf(nip86_relay_management.response_parse_json) ==
            fn (
                []const u8,
                nip86_relay_management.RelayManagementMethod,
                [][]const u8,
                []nip86_relay_management.PubkeyReason,
                []nip86_relay_management.EventIdReason,
                []u32,
                []nip86_relay_management.IpReason,
                std.mem.Allocator,
            ) nip86_relay_management.Nip86Error!nip86_relay_management.Response,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.message_serialize_json) ==
            fn ([]u8, nip46_remote_signing.Message) nip46_remote_signing.Nip46Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_parse_typed) ==
            fn (
                *const nip46_remote_signing.Request,
                std.mem.Allocator,
            ) nip46_remote_signing.Nip46Error!nip46_remote_signing.ParsedRequest,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_build_connect) ==
            fn (
                *nip46_remote_signing.BuiltRequest,
                []const u8,
                *const nip46_remote_signing.ConnectRequest,
                std.mem.Allocator,
            ) nip46_remote_signing.Nip46Error!nip46_remote_signing.Request,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_build_sign_event) ==
            fn (
                *nip46_remote_signing.BuiltRequest,
                []const u8,
                []const u8,
                std.mem.Allocator,
            ) nip46_remote_signing.Nip46Error!nip46_remote_signing.Request,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_build_pubkey_text) ==
            fn (
                *nip46_remote_signing.BuiltRequest,
                []const u8,
                nip46_remote_signing.RemoteSigningMethod,
                *const nip46_remote_signing.PubkeyTextRequest,
                std.mem.Allocator,
            ) nip46_remote_signing.Nip46Error!nip46_remote_signing.Request,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_build_empty) ==
            fn (
                *nip46_remote_signing.BuiltRequest,
                []const u8,
                nip46_remote_signing.RemoteSigningMethod,
                std.mem.Allocator,
            ) nip46_remote_signing.Nip46Error!nip46_remote_signing.Request,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.uri_parse) ==
            fn ([]const u8, std.mem.Allocator) nip46_remote_signing.Nip46Error!nip46_remote_signing.ConnectionUri,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.uri_serialize) ==
            fn ([]u8, nip46_remote_signing.ConnectionUri) nip46_remote_signing.Nip46Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.discovery_parse_well_known) ==
            fn (
                []const u8,
                std.mem.Allocator,
            ) nip46_remote_signing.Nip46Error!nip46_remote_signing.DiscoveryInfo,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.discovery_parse_nip89) ==
            fn (
                *const nip01_event.Event,
                std.mem.Allocator,
            ) nip46_remote_signing.Nip46Error!nip46_remote_signing.DiscoveryInfo,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.response_result_connect) ==
            fn (
                *const nip46_remote_signing.Response,
            ) nip46_remote_signing.Nip46Error!nip46_remote_signing.ConnectResult,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.response_result_get_public_key) ==
            fn (
                *const nip46_remote_signing.Response,
            ) nip46_remote_signing.Nip46Error![32]u8,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.response_result_sign_event) ==
            fn (
                *const nip46_remote_signing.Response,
                std.mem.Allocator,
            ) nip46_remote_signing.Nip46Error!nip01_event.Event,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.response_result_switch_relays) ==
            fn (
                *const nip46_remote_signing.Response,
            ) nip46_remote_signing.Nip46Error!?[]const []const u8,
    );
    try std.testing.expect(
        @TypeOf(nip44.nip44_get_conversation_key) ==
            fn (*const [32]u8, *const [32]u8) nip44.Nip44Error![32]u8,
    );
    try std.testing.expect(
        @TypeOf(nip44.nip44_encrypt_to_base64) ==
            fn (
                []u8,
                *const [32]u8,
                []const u8,
                ?*anyopaque,
                nip44.Nip44NonceProvider,
            ) nip44.Nip44Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip44.nip44_decrypt_from_base64) ==
            fn ([]u8, *const [32]u8, []const u8) nip44.Nip44Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip59_wrap.nip59_validate_wrap_structure) ==
            fn (*const nip01_event.Event) nip59_wrap.WrapError!void,
    );
    try std.testing.expect(
        @TypeOf(nip59_wrap.nip59_unwrap) ==
            fn (
                *nip01_event.Event,
                *const [32]u8,
                *const nip01_event.Event,
                std.mem.Allocator,
            ) nip59_wrap.WrapError!void,
    );
    if (i6_extensions_enabled) {
        try std.testing.expect(@TypeOf(nip45_count.CountError) == type);
        try std.testing.expect(@TypeOf(nip50_search.SearchError) == type);
        try std.testing.expect(@TypeOf(nip77_negentropy.NegentropyError) == type);
        try std.testing.expect(
            @TypeOf(nip45_count.count_client_message_parse) ==
                fn (
                    []const u8,
                    std.mem.Allocator,
                ) nip45_count.CountError!nip45_count.CountClientMessage,
        );
        try std.testing.expect(
            @TypeOf(nip45_count.count_relay_message_parse) ==
                fn (
                    []const u8,
                    std.mem.Allocator,
                ) nip45_count.CountError!nip45_count.CountRelayMessage,
        );
        try std.testing.expect(
            @TypeOf(nip45_count.count_metadata_validate) ==
                fn (*const nip45_count.CountMetadata) nip45_count.CountError!void,
        );
        try std.testing.expect(
            @TypeOf(nip50_search.search_field_validate) ==
                fn ([]const u8) nip50_search.SearchError!void,
        );
        try std.testing.expect(
            @TypeOf(nip50_search.search_tokens_parse) ==
                fn (
                    []const u8,
                    []nip50_search.SearchToken,
                ) error{ BufferTooSmall, InvalidSearchValue }!u16,
        );
        try std.testing.expect(
            @TypeOf(nip77_negentropy.negentropy_open_parse) ==
                fn (
                    []const u8,
                    std.mem.Allocator,
                ) nip77_negentropy.NegentropyError!nip77_negentropy.NegOpenMessage,
        );
        try std.testing.expect(
            @TypeOf(nip77_negentropy.negentropy_msg_parse) ==
                fn (
                    []const u8,
                    std.mem.Allocator,
                ) nip77_negentropy.NegentropyError!nip77_negentropy.NegMsgMessage,
        );
        try std.testing.expect(
            @TypeOf(nip77_negentropy.negentropy_state_apply) ==
                fn (
                    *nip77_negentropy.NegentropyState,
                    *const nip77_negentropy.NegentropyMessage,
                ) nip77_negentropy.NegentropyError!void,
        );
        try std.testing.expect(
            @TypeOf(nip77_negentropy.negentropy_items_validate_order) ==
                fn ([]const nip77_negentropy.NegentropyItem) nip77_negentropy.NegentropyError!void,
        );
    }
    try std.testing.expect(
        @TypeOf(pow_meets_difficulty_verified_id) ==
            @TypeOf(nip13_pow.pow_meets_difficulty_verified_id),
    );
    try std.testing.expect(
        @TypeOf(delete_extract_targets_checked) ==
            @TypeOf(nip09_delete.delete_extract_targets_checked),
    );
    try std.testing.expect(
        @TypeOf(transcript_mark_client_req) ==
            @TypeOf(nip01_message.transcript_mark_client_req),
    );
    try std.testing.expect(
        @TypeOf(transcript_apply_relay) ==
            @TypeOf(nip01_message.transcript_apply_relay),
    );
}

test "root smoke test uses typed errors" {
    try std.testing.expectError(error.InvalidId, use_typed_error_for_smoke(true));
}

test "I4 optional paths do not interfere with strict core defaults" {
    var bech32_buffer: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var uri_buffer: [limits.nip21_uri_bytes_max]u8 = undefined;
    var tlv_scratch: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;

    const npub_identifier = try nip19_bech32.nip19_encode(
        bech32_buffer[0..],
        .{ .npub = [_]u8{0x42} ** 32 },
    );
    const decoded_npub = try nip19_bech32.nip19_decode(npub_identifier, tlv_scratch[0..]);
    try std.testing.expect(decoded_npub == .npub);

    const npub_uri = try std.fmt.bufPrint(uri_buffer[0..], "nostr:{s}", .{npub_identifier});
    const parsed_uri = try nip21_uri.nip21_parse(npub_uri, tlv_scratch[0..]);
    try std.testing.expect(parsed_uri.entity == .npub);

    const contact_tag_items = [_][]const u8{
        "p",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const contact_tags = [_]nip01_event.EventTag{.{ .items = contact_tag_items[0..] }};
    const contact_event: nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 3,
        .created_at = 0,
        .content = "",
        .tags = contact_tags[0..],
    };
    var contacts_output: [1]nip02_contacts.ContactEntry = undefined;
    const contact_count = try nip02_contacts.contacts_extract(&contact_event, contacts_output[0..]);
    try std.testing.expectEqual(@as(u16, 1), contact_count);

    const relay_tag_items = [_][]const u8{ "r", "wss://relay.example", "read" };
    const relay_tags = [_]nip01_event.EventTag{.{ .items = relay_tag_items[0..] }};
    const relay_event: nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 10002,
        .created_at = 0,
        .content = "",
        .tags = relay_tags[0..],
    };
    var relays_output: [1]nip65_relays.RelayPermission = undefined;
    const relay_count = try nip65_relays.relay_list_extract(&relay_event, relays_output[0..]);
    try std.testing.expectEqual(@as(u16, 1), relay_count);

    const list_d_tag = [_][]const u8{ "d", "team" };
    const list_p_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const list_tags = [_]nip01_event.EventTag{
        .{ .items = list_d_tag[0..] },
        .{ .items = list_p_tag[0..] },
    };
    const list_event: nip01_event.Event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 30000,
        .created_at = 0,
        .content = "",
        .tags = list_tags[0..],
    };
    var list_output: [1]nip51_lists.ListItem = undefined;
    const list_info = try nip51_lists.list_extract(&list_event, list_output[0..]);
    try std.testing.expectEqual(nip51_lists.ListKind.follow_set, list_info.kind);
    try std.testing.expectEqual(@as(u16, 1), list_info.item_count);
    try std.testing.expectEqualStrings("team", list_info.metadata.identifier.?);
    try std.testing.expect(list_output[0] == .pubkey);

    var built_tag: nip51_lists.BuiltTag = .{};
    const emoji_tag = try nip51_lists.emoji_build_tag(&built_tag, &.{
        .shortcode = "soapbox",
        .image_url = "https://cdn.example/soapbox.png",
        .set_coordinate = .{
            .kind = 30030,
            .pubkey = [_]u8{0xaa} ** 32,
            .identifier = "icons",
        },
    });
    try std.testing.expectEqual(@as(usize, 4), emoji_tag.items.len);
    try std.testing.expectEqualStrings("emoji", emoji_tag.items[0]);
    try std.testing.expectEqualStrings("soapbox", emoji_tag.items[1]);

    try std.testing.expectError(
        error.InvalidFilter,
        nip01_filter.filter_parse_json("{\"unexpected\":1}", std.testing.allocator),
    );
    try std.testing.expectError(
        error.InvalidCommand,
        nip01_message.relay_message_parse_json("[\"UNKNOWN\",\"sub\"]", std.testing.allocator),
    );
}

test "I6 optional paths do not interfere with strict core defaults" {
    if (!i6_extensions_enabled) {
        return;
    }

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const count_relay = try nip45_count.count_relay_message_parse(
        "[\"COUNT\",\"q1\",{\"count\":1}]",
        arena.allocator(),
    );
    try std.testing.expectEqual(@as(u64, 1), count_relay.count);

    try nip50_search.search_field_validate("nostr include:spam");

    const neg_open = try nip77_negentropy.negentropy_open_parse(
        "[\"NEG-OPEN\",\"sub\",{\"kinds\":[1]},\"6100\"]",
        arena.allocator(),
    );
    var neg_state = nip77_negentropy.NegentropyState{};
    const neg_message: nip77_negentropy.NegentropyMessage = .{ .open = neg_open };
    try nip77_negentropy.negentropy_state_apply(&neg_state, &neg_message);

    try std.testing.expectError(
        error.InvalidCommand,
        nip01_message.relay_message_parse_json("[\"UNKNOWN\",\"sub\"]", std.testing.allocator),
    );
}

test "I6 disabled mode preserves strict core behavior" {
    if (i6_extensions_enabled) {
        return;
    }

    try std.testing.expectError(
        error.InvalidFilter,
        nip01_filter.filter_parse_json("{\"unexpected\":1}", std.testing.allocator),
    );
    try std.testing.expectError(
        error.InvalidCommand,
        nip01_message.relay_message_parse_json("[\"UNKNOWN\",\"sub\"]", std.testing.allocator),
    );
}
