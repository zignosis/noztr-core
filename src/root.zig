const std = @import("std");

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
    try std.testing.expect(@TypeOf(nip19_bech32.Nip19Entity) == type);
    try std.testing.expect(@TypeOf(nip21_uri.Nip21Reference) == type);
    try std.testing.expect(@TypeOf(nip02_contacts.ContactEntry) == type);
    try std.testing.expect(@TypeOf(nip65_relays.RelayPermission) == type);
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

    try std.testing.expectError(
        error.InvalidFilter,
        nip01_filter.filter_parse_json("{\"unexpected\":1}", std.testing.allocator),
    );
    try std.testing.expectError(
        error.InvalidCommand,
        nip01_message.relay_message_parse_json("[\"UNKNOWN\",\"sub\"]", std.testing.allocator),
    );
}
