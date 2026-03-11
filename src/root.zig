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

/// Phase H concrete export for the NIP-18 repost module.
pub const nip18_reposts = @import("nip18_reposts.zig");

/// Phase H concrete export for the NIP-22 comment module.
pub const nip22_comments = @import("nip22_comments.zig");

/// Phase H concrete export for the NIP-27 text-reference module.
pub const nip27_references = @import("nip27_references.zig");

/// Phase H concrete export for the NIP-25 reactions module.
pub const nip25_reactions = @import("nip25_reactions.zig");

/// Phase H concrete export for the NIP-51 public-list module.
pub const nip51_lists = @import("nip51_lists.zig");

/// Phase H concrete export for the NIP-46 remote-signing module.
pub const nip46_remote_signing = @import("nip46_remote_signing.zig");

/// Phase I5 concrete export for the NIP-44 encrypted direct-message module.
pub const nip44 = @import("nip44.zig");

/// Phase I5 concrete export for the NIP-59 gift-wrap module.
pub const nip59_wrap = @import("nip59_wrap.zig");

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
    try std.testing.expect(@TypeOf(nip13_pow.PowError) == type);
    try std.testing.expect(@TypeOf(nip19_bech32.Nip19Error) == type);
    try std.testing.expect(@TypeOf(nip21_uri.Nip21Error) == type);
    try std.testing.expect(@TypeOf(nip02_contacts.ContactsError) == type);
    try std.testing.expect(@TypeOf(nip65_relays.RelaysError) == type);
    try std.testing.expect(@TypeOf(nip10_threads.ThreadError) == type);
    try std.testing.expect(@TypeOf(nip18_reposts.RepostError) == type);
    try std.testing.expect(@TypeOf(nip22_comments.CommentError) == type);
    try std.testing.expect(@TypeOf(nip27_references.ReferencesError) == type);
    try std.testing.expect(@TypeOf(nip25_reactions.ReactionError) == type);
    try std.testing.expect(@TypeOf(nip51_lists.ListError) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.Nip46Error) == type);
    try std.testing.expect(@TypeOf(nip44.Nip44Error) == type);
    try std.testing.expect(@TypeOf(nip59_wrap.WrapError) == type);
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
    try std.testing.expect(@TypeOf(nip18_reposts.RepostTarget) == type);
    try std.testing.expect(@TypeOf(nip22_comments.CommentInfo) == type);
    try std.testing.expect(@TypeOf(nip27_references.ContentReference) == type);
    try std.testing.expect(@TypeOf(nip25_reactions.ReactionTarget) == type);
    try std.testing.expect(@TypeOf(nip51_lists.BuiltTag) == type);
    try std.testing.expect(@TypeOf(nip51_lists.BookmarkBuilderItem) == type);
    try std.testing.expect(@TypeOf(nip51_lists.ListItem) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ConnectRequest) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.PubkeyTextRequest) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ConnectResult) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ParsedRequest) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.DiscoveryInfo) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.Message) == type);
    try std.testing.expect(@TypeOf(nip46_remote_signing.ConnectionUri) == type);
    try std.testing.expect(@TypeOf(PowVerifiedIdError) == type);
    try std.testing.expect(@TypeOf(DeleteExtractCheckedError) == type);
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
        @TypeOf(nip46_remote_signing.message_parse_json) ==
            fn ([]const u8, std.mem.Allocator) nip46_remote_signing.Nip46Error!nip46_remote_signing.Message,
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
