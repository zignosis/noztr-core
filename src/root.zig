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

/// Phase H fourth requested-loop split concrete export for the NIP-71 video-events module.
pub const nip71_video_events = @import("nip71_video_events.zig");

/// Phase H fourth requested-loop split concrete export for the NIP-72 moderated-communities module.
pub const nip72_moderated_communities = @import("nip72_moderated_communities.zig");

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

/// Phase H split concrete export for the NIP-66 relay discovery module.
pub const nip66_relay_discovery = @import("nip66_relay_discovery.zig");

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

/// Phase H deferred-backlog concrete export for the NIP-04 legacy direct-message module.
pub const nip04 = @import("nip04.zig");

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
    try std.testing.expect(@TypeOf(nip11.RelayInfoError) == type);
    try std.testing.expect(@TypeOf(nip09_delete.DeleteError) == type);
    try std.testing.expect(@TypeOf(nip40_expire.ExpirationError) == type);
    try std.testing.expect(@TypeOf(nip92_media_attachments.MediaAttachmentError) == type);
    try std.testing.expect(@TypeOf(nip94_file_metadata.FileMetadataError) == type);
    try std.testing.expect(@TypeOf(nip99_classified_listings.ClassifiedListingError) == type);
    try std.testing.expect(@TypeOf(nipb0_web_bookmarking.WebBookmarkError) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.CodeSnippetError) == type);
    try std.testing.expect(@TypeOf(nip64_chess_pgn.ChessPgnError) == type);
    try std.testing.expect(@TypeOf(nip88_polls.PollError) == type);
    try std.testing.expect(@TypeOf(nip98_http_auth.HttpAuthError) == type);
    try std.testing.expect(@TypeOf(nipb7_blossom_servers.BlossomError) == type);
    try std.testing.expect(@TypeOf(nip13_pow.PowError) == type);
    try std.testing.expect(@TypeOf(nip14_subjects.SubjectError) == type);
    try std.testing.expect(@TypeOf(nip19_bech32.Bech32Error) == type);
    try std.testing.expect(@TypeOf(nip21_uri.UriError) == type);
    try std.testing.expect(@TypeOf(nip02_contacts.ContactsError) == type);
    try std.testing.expect(@TypeOf(nip65_relays.RelaysError) == type);
    try std.testing.expect(@TypeOf(nip10_threads.ThreadError) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.PublicChatError) == type);
    try std.testing.expect(@TypeOf(nip30_custom_emoji.EmojiError) == type);
    try std.testing.expect(@TypeOf(nip18_reposts.RepostError) == type);
    try std.testing.expect(@TypeOf(nip22_comments.CommentError) == type);
    try std.testing.expect(@TypeOf(nip27_references.ReferenceError) == type);
    try std.testing.expect(@TypeOf(nip25_reactions.ReactionError) == type);
    try std.testing.expect(@TypeOf(nip51_lists.ListError) == type);
    try std.testing.expect(@TypeOf(nip51_lists.PrivateListError) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.RemoteSigningError) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.NwcError) == type);
    try std.testing.expect(@TypeOf(nip49_private_key_encryption.PrivateKeyEncryptionError) == type);
    try std.testing.expect(@TypeOf(nip06_mnemonic.MnemonicError) == type);
    try std.testing.expect(@TypeOf(bip85_derivation.Bip85Error) == type);
    try std.testing.expect(@TypeOf(nostr_keys.NostrKeysError) == type);
    try std.testing.expect(@TypeOf(nip23_long_form.LongFormError) == type);
    try std.testing.expect(@TypeOf(nip24_extra_metadata.ExtraMetadataError) == type);
    try std.testing.expect(@TypeOf(nip03_opentimestamps.OpenTimestampsError) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.PrivateMessageError) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.RelayListError) == type);
    try std.testing.expect(@TypeOf(nip39_external_identities.ExternalIdentityError) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupError) == type);
    try std.testing.expect(@TypeOf(nip31_alt_tags.AltTagError) == type);
    try std.testing.expect(@TypeOf(nip73_external_ids.ExternalIdError) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.LabelingError) == type);
    try std.testing.expect(@TypeOf(nip34_git.GitError) == type);
    try std.testing.expect(@TypeOf(nip36_content_warning.ContentWarningError) == type);
    try std.testing.expect(@TypeOf(nip38_user_status.UserStatusError) == type);
    try std.testing.expect(@TypeOf(nip56_reporting.ReportError) == type);
    try std.testing.expect(@TypeOf(nip05_identity.IdentityError) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.CalendarError) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.LiveActivityError) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.WikiError) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.ZapError) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.NutzapError) == type);
    try std.testing.expect(@TypeOf(nip75_zap_goals.ZapGoalError) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.RelayManagementError) == type);
    try std.testing.expect(@TypeOf(nip44.ConversationEncryptionError) == type);
    try std.testing.expect(@TypeOf(nip59_wrap.WrapError) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.AppDataError) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.HandlerError) == type);
    try std.testing.expectEqual(i6_extensions_enabled, @hasDecl(nip45_count, "CountError"));
    try std.testing.expectEqual(i6_extensions_enabled, @hasDecl(nip50_search, "SearchError"));
    try std.testing.expectEqual(
        i6_extensions_enabled,
        @hasDecl(nip77_negentropy, "NegentropyError"),
    );
    try std.testing.expect(@TypeOf(nip19_bech32.Nip19Entity) == type);
    try std.testing.expect(@TypeOf(nip21_uri.Reference) == type);
    try std.testing.expect(@TypeOf(nip02_contacts.ContactEntry) == type);
    try std.testing.expect(@TypeOf(nip65_relays.RelayPermission) == type);
    try std.testing.expect(@TypeOf(nip10_threads.Reference) == type);
    try std.testing.expect(@TypeOf(nip10_threads.Thread) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.ChannelMetadata) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.Reference) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.Update) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.Message) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.HideMessage) == type);
    try std.testing.expect(@TypeOf(nip28_public_chat.MuteUser) == type);
    try std.testing.expect(@TypeOf(nip30_custom_emoji.EmojiTag) == type);
    try std.testing.expect(@TypeOf(nipb0_web_bookmarking.Bookmark) == type);
    try std.testing.expect(@TypeOf(nip04.Message) == type);
    try std.testing.expect(@TypeOf(nip18_reposts.RepostTarget) == type);
    try std.testing.expect(@TypeOf(nip22_comments.Comment) == type);
    try std.testing.expect(@TypeOf(nip27_references.ContentReference) == type);
    try std.testing.expect(@TypeOf(nip25_reactions.ReactionTarget) == type);
    try std.testing.expect(@TypeOf(nip51_lists.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip51_lists.BookmarkBuilderItem) == type);
    try std.testing.expect(@TypeOf(nip51_lists.ListItem) == type);
    try std.testing.expect(@TypeOf(nip51_lists.PrivateList) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ConnectParams) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.PubkeyTextParams) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.RequestBuilder) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.Result) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ConnectResult) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ParsedRequest) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.Discovery) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Uri) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.InfoEvent) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.ErrorDetail) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.PayInvoice) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.PayKeysend) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.MakeInvoice) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.LookupInvoice) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.ListTransactions) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.MakeHoldInvoice) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.CancelHoldInvoice) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.SettleHoldInvoice) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Payment) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Balance) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.WalletInfo) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Request) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Response) == type);
    try std.testing.expect(@TypeOf(nip47_wallet_connect.Notification) == type);
    try std.testing.expect(@TypeOf(nip23_long_form.Metadata) == type);
    try std.testing.expect(@TypeOf(nip23_long_form.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.License) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.RepoRef) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.Snippet) == type);
    try std.testing.expect(@TypeOf(nipc0_code_snippets.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip64_chess_pgn.Pgn) == type);
    try std.testing.expect(@TypeOf(nip64_chess_pgn.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip88_polls.PollType) == type);
    try std.testing.expect(@TypeOf(nip88_polls.Poll) == type);
    try std.testing.expect(@TypeOf(nip88_polls.EventRef) == type);
    try std.testing.expect(@TypeOf(nip88_polls.Response) == type);
    try std.testing.expect(@TypeOf(nip88_polls.OptionTally) == type);
    try std.testing.expect(@TypeOf(nip88_polls.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip98_http_auth.Auth) == type);
    try std.testing.expect(@TypeOf(nipb7_blossom_servers.ServerList) == type);
    try std.testing.expect(@TypeOf(nipb7_blossom_servers.BlobRef) == type);
    try std.testing.expect(@TypeOf(nipb7_blossom_servers.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip24_extra_metadata.MetadataExtras) == type);
    try std.testing.expect(@TypeOf(nip24_extra_metadata.CommonTagInfo) == type);
    try std.testing.expect(@TypeOf(nip24_extra_metadata.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip03_opentimestamps.OpenTimestampsAttestation) == type);
    try std.testing.expect(@TypeOf(nip03_opentimestamps.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.DmRecipient) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.ReplyRef) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.Message) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.FileEncryptionAlgorithm) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.FileDimensions) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.FileMessage) == type);
    try std.testing.expect(@TypeOf(nip17_private_messages.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip14_subjects.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip31_alt_tags.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip39_external_identities.IdentityProvider) == type);
    try std.testing.expect(@TypeOf(nip39_external_identities.IdentityClaim) == type);
    try std.testing.expect(@TypeOf(nip39_external_identities.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupMetadataFlag) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupStateUser) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupState) == type);
    try std.testing.expect(@TypeOf(nip73_external_ids.ExternalIdKind) == type);
    try std.testing.expect(@TypeOf(nip73_external_ids.ExternalId) == type);
    try std.testing.expect(@TypeOf(nip73_external_ids.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.LabelNamespace) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.Label) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.LabelTarget) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.LabelEvent) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.SelfLabel) == type);
    try std.testing.expect(@TypeOf(nip32_labeling.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip34_git.Announcement) == type);
    try std.testing.expect(@TypeOf(nip34_git.StateRef) == type);
    try std.testing.expect(@TypeOf(nip34_git.State) == type);
    try std.testing.expect(@TypeOf(nip34_git.GraspList) == type);
    try std.testing.expect(@TypeOf(nip34_git.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip36_content_warning.ContentWarning) == type);
    try std.testing.expect(@TypeOf(nip36_content_warning.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip38_user_status.Status) == type);
    try std.testing.expect(@TypeOf(nip38_user_status.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip56_reporting.ReportType) == type);
    try std.testing.expect(@TypeOf(nip56_reporting.Report) == type);
    try std.testing.expect(@TypeOf(nip56_reporting.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip05_identity.Address) == type);
    try std.testing.expect(@TypeOf(nip05_identity.Profile) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.ZapError) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.ZapRequest) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.ZapReceipt) == type);
    try std.testing.expect(@TypeOf(nip57_zaps.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.RelayManagementError) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.PubkeyReason) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.EventIdReason) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.IpReason) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.Result) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.Request) == type);
    try std.testing.expect(@TypeOf(nip86_relay_management.Response) == type);
    try std.testing.expect(@TypeOf(nip37_drafts.Wrap) == type);
    try std.testing.expect(@TypeOf(nip37_drafts.Plaintext) == type);
    try std.testing.expect(@TypeOf(nip37_drafts.PrivateRelayList) == type);
    try std.testing.expect(@TypeOf(nip37_drafts.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip58_badges.Image) == type);
    try std.testing.expect(@TypeOf(nip58_badges.DefinitionRef) == type);
    try std.testing.expect(@TypeOf(nip58_badges.Definition) == type);
    try std.testing.expect(@TypeOf(nip58_badges.BadgeAwardRecipient) == type);
    try std.testing.expect(@TypeOf(nip58_badges.Award) == type);
    try std.testing.expect(@TypeOf(nip58_badges.AwardEventRef) == type);
    try std.testing.expect(@TypeOf(nip58_badges.ProfileBadgePair) == type);
    try std.testing.expect(@TypeOf(nip58_badges.ProfileBadges) == type);
    try std.testing.expect(@TypeOf(nip58_badges.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.CalendarParticipant) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.CalendarCoordinate) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.Common) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.DateEvent) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.TimeEvent) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.Calendar) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.Rsvp) == type);
    try std.testing.expect(@TypeOf(nip52_calendar_events.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.LiveActivityParticipant) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.Coordinate) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.Reply) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.Activity) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.Chat) == type);
    try std.testing.expect(@TypeOf(nip53_live_activities.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.ArticleRef) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.EventRef) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.Article) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.MergeRequest) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.Redirect) == type);
    try std.testing.expect(@TypeOf(nip54_wiki.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.Informational) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.Nutzap) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.Redemption) == type);
    try std.testing.expect(@TypeOf(nip61_nutzaps.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip75_zap_goals.Goal) == type);
    try std.testing.expect(@TypeOf(nip75_zap_goals.Reference) == type);
    try std.testing.expect(@TypeOf(nip75_zap_goals.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.AppData) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.Reference) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.Recommendation) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.Handler) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.ClientTag) == type);
    try std.testing.expect(@TypeOf(nip89_handlers.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.EventSource) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.AddressSource) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.UrlRef) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.HighlightSource) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.HighlightAttribution) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.Highlight) == type);
    try std.testing.expect(@TypeOf(nip84_highlights.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip72_moderated_communities.Community) == type);
    try std.testing.expect(@TypeOf(nip72_moderated_communities.EventRef) == type);
    try std.testing.expect(@TypeOf(nip72_moderated_communities.Post) == type);
    try std.testing.expect(@TypeOf(nip72_moderated_communities.Approval) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupMetadata) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupAdmin) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.Reference) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupMember) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.GroupRole) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.Admins) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.Members) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.Roles) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.JoinRequest) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.LeaveRequest) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.PutUser) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.RemoveUser) == type);
    try std.testing.expect(@TypeOf(nip29_relay_groups.TagBuilder) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.AppData) == type);
    try std.testing.expect(@TypeOf(nip78_app_data.TagBuilder) == type);
    try std.testing.expect(
        @TypeOf(nip06_mnemonic.mnemonic_validate) ==
            fn ([]const u8) nip06_mnemonic.MnemonicError!void,
    );
    try std.testing.expect(
        @TypeOf(nip06_mnemonic.mnemonic_to_seed) ==
            fn ([]u8, []const u8, ?[]const u8) nip06_mnemonic.MnemonicError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip06_mnemonic.derive_nostr_secret_key_from_seed) ==
            fn ([]u8, []const u8, u32) nip06_mnemonic.MnemonicError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip06_mnemonic.derive_nostr_secret_key) ==
            fn ([]u8, []const u8, ?[]const u8, u32) nip06_mnemonic.MnemonicError![]const u8,
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
            ) nip23_long_form.LongFormError!nip23_long_form.Metadata,
    );
    try std.testing.expect(
        @TypeOf(nip23_long_form.long_form_build_identifier_tag) ==
            fn (
                *nip23_long_form.TagBuilder,
                []const u8,
            ) nip23_long_form.LongFormError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip24_extra_metadata.metadata_extras_parse_json) ==
            fn (
                []const u8,
                std.mem.Allocator,
            ) nip24_extra_metadata.ExtraMetadataError!nip24_extra_metadata.MetadataExtras,
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
            ) nip17_private_messages.PrivateMessageError!nip17_private_messages.FileMessage,
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
            ) nip17_private_messages.PrivateMessageError!nip17_private_messages.FileMessage,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_reference_parse) ==
            fn ([]const u8) nip29_relay_groups.GroupError!nip29_relay_groups.Reference,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_roles_extract) ==
            fn (
                *const nip01_event.Event,
                []nip29_relay_groups.GroupRole,
            ) nip29_relay_groups.GroupError!nip29_relay_groups.Roles,
    );
    try std.testing.expect(
        @TypeOf(nip03_opentimestamps.opentimestamps_build_event_tag) ==
            fn (
                *nip03_opentimestamps.TagBuilder,
                []const u8,
                ?[]const u8,
            ) nip03_opentimestamps.OpenTimestampsError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_message_parse) ==
            fn (
                *const nip01_event.Event,
                []nip17_private_messages.DmRecipient,
            ) nip17_private_messages.PrivateMessageError!nip17_private_messages.Message,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_unwrap_message) ==
            fn (
                *nip01_event.Event,
                *const [32]u8,
                *const nip01_event.Event,
                []nip17_private_messages.DmRecipient,
                std.mem.Allocator,
            ) nip17_private_messages.PrivateMessageError!nip17_private_messages.Message,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_relay_list_extract) ==
            fn (
                *const nip01_event.Event,
                [][]const u8,
            ) nip17_private_messages.RelayListError!u16,
    );
    try std.testing.expect(@TypeOf(nip17_private_messages.FileTagBuilder) == type);
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_build_file_type_tag) ==
            fn (
                *nip17_private_messages.FileTagBuilder,
                []const u8,
            ) nip17_private_messages.PrivateMessageError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip17_private_messages.nip17_build_file_size_tag) ==
            fn (
                *nip17_private_messages.FileTagBuilder,
                u64,
            ) nip17_private_messages.PrivateMessageError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip39_external_identities.identity_claims_extract) ==
            fn (
                *const nip01_event.Event,
                []nip39_external_identities.IdentityClaim,
            ) nip39_external_identities.ExternalIdentityError!u16,
    );
    try std.testing.expect(
        @TypeOf(nip39_external_identities.identity_claim_build_tag) ==
            fn (
                *nip39_external_identities.TagBuilder,
                *const nip39_external_identities.IdentityClaim,
            ) nip39_external_identities.ExternalIdentityError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip39_external_identities.identity_claim_build_proof_url) ==
            fn (
                []u8,
                *const nip39_external_identities.IdentityClaim,
            ) nip39_external_identities.ExternalIdentityError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_metadata_extract) ==
            fn (*const nip01_event.Event) nip29_relay_groups.GroupError!nip29_relay_groups.GroupMetadata,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_admins_extract) ==
            fn (
                *const nip01_event.Event,
                []nip29_relay_groups.GroupAdmin,
                [][]const u8,
            ) nip29_relay_groups.GroupError!nip29_relay_groups.Admins,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_state_apply_event) ==
            fn (
                *nip29_relay_groups.GroupState,
                *const nip01_event.Event,
            ) nip29_relay_groups.GroupError!void,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_state_apply_events) ==
            fn (
                *nip29_relay_groups.GroupState,
                []const nip01_event.Event,
            ) nip29_relay_groups.GroupError!void,
    );
    try std.testing.expect(
        @TypeOf(nip29_relay_groups.group_members_extract) ==
            fn (
                *const nip01_event.Event,
                []nip29_relay_groups.GroupMember,
            ) nip29_relay_groups.GroupError!nip29_relay_groups.Members,
    );
    try std.testing.expect(
        @TypeOf(nip24_extra_metadata.common_tags_extract) ==
            fn (
                []const nip01_event.EventTag,
                [][]const u8,
                [][]const u8,
            ) nip24_extra_metadata.ExtraMetadataError!nip24_extra_metadata.CommonTagInfo,
    );
    try std.testing.expect(
        @TypeOf(nip24_extra_metadata.common_tags_extract_with_external_ids) ==
            fn (
                []const nip01_event.EventTag,
                [][]const u8,
                []nip73_external_ids.ExternalId,
                [][]const u8,
            ) nip24_extra_metadata.ExtraMetadataError!nip24_extra_metadata.CommonTagInfo,
    );
    try std.testing.expect(
        @TypeOf(nip73_external_ids.external_id_parse) ==
            fn (
                []const u8,
                ?[]const u8,
            ) nip73_external_ids.ExternalIdError!nip73_external_ids.ExternalId,
    );
    try std.testing.expect(
        @TypeOf(nip73_external_ids.external_id_build_i_tag) ==
            fn (
                *nip73_external_ids.TagBuilder,
                *const nip73_external_ids.ExternalId,
            ) nip73_external_ids.ExternalIdError!nip01_event.EventTag,
    );
    try std.testing.expect(@TypeOf(nip46_remote_signing.Message) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.Uri) == type);
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
            ) nip51_lists.PrivateListError!nip51_lists.PrivateList,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.list_private_extract_nip44) ==
            fn (
                []u8,
                *const nip01_event.Event,
                *const [32]u8,
                []nip51_lists.ListItem,
                std.mem.Allocator,
            ) nip51_lists.PrivateListError!nip51_lists.PrivateList,
    );
    try std.testing.expect(
        @TypeOf(nip19_bech32.nip19_encode) ==
            fn ([]u8, nip19_bech32.Nip19Entity) nip19_bech32.Bech32Error![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip19_bech32.nip19_decode) ==
            fn ([]const u8, []u8) nip19_bech32.Bech32Error!nip19_bech32.Nip19Entity,
    );
    try std.testing.expect(
        @TypeOf(nip21_uri.uri_parse) ==
            fn ([]const u8, []u8) nip21_uri.UriError!nip21_uri.Reference,
    );
    try std.testing.expect(@TypeOf(nip21_uri.uri_is_valid) == fn ([]const u8, []u8) bool);
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
                []nip10_threads.Reference,
            ) nip10_threads.ThreadError!nip10_threads.Thread,
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
            ) nip22_comments.CommentError!nip22_comments.Comment,
    );
    try std.testing.expect(
        @TypeOf(nip27_references.reference_extract) ==
            fn (
                []const u8,
                []nip27_references.ContentReference,
                []u8,
            ) nip27_references.ReferenceError!u16,
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
            ) nip51_lists.ListError!nip51_lists.List,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.list_build_identifier_tag) ==
            fn (
                *nip51_lists.TagBuilder,
                []const u8,
            ) nip51_lists.ListError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.bookmark_build_tag) ==
            fn (
                *nip51_lists.TagBuilder,
                nip51_lists.BookmarkBuilderItem,
            ) nip51_lists.ListError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip51_lists.emoji_build_tag) ==
            fn (
                *nip51_lists.TagBuilder,
                *const nip51_lists.ListEmoji,
            ) nip51_lists.ListError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.address_parse) ==
            fn ([]const u8, std.mem.Allocator) nip05_identity.IdentityError!nip05_identity.Address,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.address_format) ==
            fn ([]u8, *const nip05_identity.Address) nip05_identity.IdentityError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.address_compose_well_known_url) ==
            fn ([]u8, *const nip05_identity.Address) nip05_identity.IdentityError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.profile_parse_json) ==
            fn (
                *const nip05_identity.Address,
                []const u8,
                std.mem.Allocator,
            ) nip05_identity.IdentityError!nip05_identity.Profile,
    );
    try std.testing.expect(
        @TypeOf(nip05_identity.profile_verify_json) ==
            fn (
                *const [32]u8,
                *const nip05_identity.Address,
                []const u8,
                std.mem.Allocator,
            ) nip05_identity.IdentityError!bool,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.message_parse_json) ==
            fn ([]const u8, std.mem.Allocator) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.Message,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.draft_wrap_parse) ==
            fn (*const nip01_event.Event) nip37_drafts.DraftError!nip37_drafts.Wrap,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.draft_wrap_decrypt_json) ==
            fn (
                []u8,
                *const nip01_event.Event,
                *const [32]u8,
                std.mem.Allocator,
            ) nip37_drafts.DraftError!nip37_drafts.Plaintext,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.draft_wrap_encrypt_json) ==
            fn (
                []u8,
                *const [32]u8,
                *const [32]u8,
                []const u8,
                std.mem.Allocator,
            ) nip37_drafts.DraftError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.private_relay_build_tag) ==
            fn (*nip37_drafts.TagBuilder, []const u8) nip37_drafts.DraftError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.private_relay_list_serialize_json) ==
            fn ([]u8, []const nip01_event.EventTag) nip37_drafts.DraftError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.private_relay_list_extract_json) ==
            fn (
                []const u8,
                [][]const u8,
                std.mem.Allocator,
            ) nip37_drafts.DraftError!nip37_drafts.PrivateRelayList,
    );
    try std.testing.expect(
        @TypeOf(nip37_drafts.private_relay_list_extract_nip44) ==
            fn (
                []u8,
                *const nip01_event.Event,
                *const [32]u8,
                [][]const u8,
                std.mem.Allocator,
            ) nip37_drafts.DraftError!nip37_drafts.PrivateRelayList,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_definition_extract) ==
            fn (
                *const nip01_event.Event,
                []nip58_badges.Image,
            ) nip58_badges.BadgeError!nip58_badges.Definition,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_award_extract) ==
            fn (
                *const nip01_event.Event,
                []nip58_badges.BadgeAwardRecipient,
            ) nip58_badges.BadgeError!nip58_badges.Award,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.profile_badges_extract) ==
            fn (
                *const nip01_event.Event,
                []nip58_badges.ProfileBadgePair,
            ) nip58_badges.BadgeError!nip58_badges.ProfileBadges,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_award_validate_definition) ==
            fn (
                *const nip58_badges.Award,
                *const nip58_badges.Definition,
            ) nip58_badges.BadgeError!void,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.profile_badge_pair_validate) ==
            fn (
                *const nip58_badges.ProfileBadgePair,
                *const nip58_badges.Award,
                []const nip58_badges.BadgeAwardRecipient,
                *const nip58_badges.Definition,
                *const [32]u8,
            ) nip58_badges.BadgeError!void,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_build_identifier_tag) ==
            fn (*nip58_badges.TagBuilder, []const u8) nip58_badges.BadgeError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_build_image_tag) ==
            fn (
                *nip58_badges.TagBuilder,
                []const u8,
                ?[]const u8,
            ) nip58_badges.BadgeError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.badge_build_definition_tag) ==
            fn (
                *nip58_badges.TagBuilder,
                *const nip58_badges.DefinitionRef,
            ) nip58_badges.BadgeError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip58_badges.profile_badges_build_award_tag) ==
            fn (
                *nip58_badges.TagBuilder,
                []const u8,
                ?[]const u8,
            ) nip58_badges.BadgeError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip84_highlights.highlight_extract) ==
            fn (
                *const nip01_event.Event,
                []nip84_highlights.HighlightAttribution,
                []nip84_highlights.UrlRef,
            ) nip84_highlights.HighlightError!nip84_highlights.Highlight,
    );
    try std.testing.expect(
        @TypeOf(nip84_highlights.highlight_build_event_source_tag) ==
            fn (
                *nip84_highlights.TagBuilder,
                []const u8,
                ?[]const u8,
            ) nip84_highlights.HighlightError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip84_highlights.highlight_build_author_tag) ==
            fn (
                *nip84_highlights.TagBuilder,
                []const u8,
                ?[]const u8,
                ?[]const u8,
            ) nip84_highlights.HighlightError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip84_highlights.highlight_build_comment_tag) ==
            fn (
                *nip84_highlights.TagBuilder,
                []const u8,
            ) nip84_highlights.HighlightError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip57_zaps.zap_request_extract) ==
            fn (
                *const nip01_event.Event,
                [][]const u8,
            ) nip57_zaps.ZapError!nip57_zaps.ZapRequest,
    );
    try std.testing.expect(
        @TypeOf(nip57_zaps.zap_receipt_extract) ==
            fn (
                *const nip01_event.Event,
                [][]const u8,
                std.mem.Allocator,
            ) nip57_zaps.ZapError!nip57_zaps.ZapReceipt,
    );
    try std.testing.expect(
        @TypeOf(nip57_zaps.request_build_relays_tag) ==
            fn (
                *nip57_zaps.TagBuilder,
                []const []const u8,
            ) nip57_zaps.ZapError!nip01_event.EventTag,
    );
    try std.testing.expect(
        @TypeOf(nip86_relay_management.request_parse_json) ==
            fn (
                []const u8,
                std.mem.Allocator,
            ) nip86_relay_management.RelayManagementError!nip86_relay_management.Request,
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
            ) nip86_relay_management.RelayManagementError!nip86_relay_management.Response,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.message_serialize_json) ==
            fn ([]u8, nip46_remote_signing.Message) nip46_remote_signing.RemoteSigningError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_parse_typed) ==
            fn (
                *const nip46_remote_signing.Request,
                std.mem.Allocator,
            ) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.ParsedRequest,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_build_connect) ==
            fn (
                *nip46_remote_signing.RequestBuilder,
                []const u8,
                *const nip46_remote_signing.ConnectParams,
                std.mem.Allocator,
            ) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.Request,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_build_sign_event) ==
            fn (
                *nip46_remote_signing.RequestBuilder,
                []const u8,
                []const u8,
                std.mem.Allocator,
            ) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.Request,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_build_pubkey_text) ==
            fn (
                *nip46_remote_signing.RequestBuilder,
                []const u8,
                nip46_remote_signing.Method,
                *const nip46_remote_signing.PubkeyTextParams,
                std.mem.Allocator,
            ) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.Request,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.request_build_empty) ==
            fn (
                *nip46_remote_signing.RequestBuilder,
                []const u8,
                nip46_remote_signing.Method,
                std.mem.Allocator,
            ) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.Request,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.uri_parse) ==
            fn ([]const u8, std.mem.Allocator) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.Uri,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.uri_serialize) ==
            fn ([]u8, nip46_remote_signing.Uri) nip46_remote_signing.RemoteSigningError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.discovery_parse_well_known) ==
            fn (
                []const u8,
                std.mem.Allocator,
            ) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.Discovery,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.discovery_parse_nip89) ==
            fn (
                *const nip01_event.Event,
                std.mem.Allocator,
            ) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.Discovery,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.response_result_connect) ==
            fn (
                *const nip46_remote_signing.Response,
            ) nip46_remote_signing.RemoteSigningError!nip46_remote_signing.ConnectResult,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.response_result_get_public_key) ==
            fn (
                *const nip46_remote_signing.Response,
            ) nip46_remote_signing.RemoteSigningError![32]u8,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.response_result_sign_event) ==
            fn (
                *const nip46_remote_signing.Response,
                std.mem.Allocator,
            ) nip46_remote_signing.RemoteSigningError!nip01_event.Event,
    );
    try std.testing.expect(
        @TypeOf(nip46_remote_signing.response_result_switch_relays) ==
            fn (
                *const nip46_remote_signing.Response,
            ) nip46_remote_signing.RemoteSigningError!?[]const []const u8,
    );
    try std.testing.expect(
        @TypeOf(nip44.nip44_get_conversation_key) ==
            fn (*const [32]u8, *const [32]u8) nip44.ConversationEncryptionError![32]u8,
    );
    try std.testing.expect(
        @TypeOf(nip44.nip44_encrypt_to_base64) ==
            fn (
                []u8,
                *const [32]u8,
                []const u8,
                ?*anyopaque,
                nip44.NonceProvider,
            ) nip44.ConversationEncryptionError![]const u8,
    );
    try std.testing.expect(
        @TypeOf(nip44.nip44_decrypt_from_base64) ==
            fn ([]u8, *const [32]u8, []const u8) nip44.ConversationEncryptionError![]const u8,
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
                ) nip45_count.CountError!nip45_count.ClientMessage,
        );
        try std.testing.expect(
            @TypeOf(nip45_count.count_relay_message_parse) ==
                fn (
                    []const u8,
                    std.mem.Allocator,
                ) nip45_count.CountError!nip45_count.RelayMessage,
        );
        try std.testing.expect(
            @TypeOf(nip45_count.count_metadata_validate) ==
                fn (*const nip45_count.Metadata) nip45_count.CountError!void,
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
    const parsed_uri = try nip21_uri.uri_parse(npub_uri, tlv_scratch[0..]);
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

    var built_tag: nip51_lists.TagBuilder = .{};
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
