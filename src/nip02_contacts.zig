const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const ContactsError = error{
    InvalidEventKind,
    InvalidContactTag,
    InvalidPubkey,
    BufferTooSmall,
};

pub const ContactEntry = struct {
    pubkey: [32]u8,
    relay: ?[]const u8 = null,
    petname: ?[]const u8 = null,
};

/// Extracts strict NIP-02 contact entries from a kind-3 event.
///
/// Lifetime and ownership:
/// - `ContactEntry.pubkey` is copied into `out`.
/// - `ContactEntry.relay` and `ContactEntry.petname` borrow from `event.tags` item storage.
/// - Keep `event` and its tag item backing storage alive and unmodified while using `out`.
pub fn contacts_extract(event: *const nip01_event.Event, out: []ContactEntry) ContactsError!u16 {
    std.debug.assert(event.tags.len <= std.math.maxInt(usize));
    std.debug.assert(out.len <= std.math.maxInt(usize));

    if (event.kind != 3) {
        return error.InvalidEventKind;
    }

    if (event.tags.len > limits.nip02_contacts_max) {
        return error.InvalidContactTag;
    }
    if (event.tags.len > out.len) {
        return error.BufferTooSmall;
    }

    var index: u16 = 0;
    while (index < event.tags.len) : (index += 1) {
        const tag = event.tags[index];
        const contact = try parse_contact_tag(tag);
        out[index] = contact;
    }

    return @intCast(event.tags.len);
}

fn parse_contact_tag(tag: nip01_event.EventTag) ContactsError!ContactEntry {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.nip02_contact_tag_items_max >= 2);

    if (tag.items.len < 2) {
        return error.InvalidContactTag;
    }
    if (tag.items.len > limits.nip02_contact_tag_items_max) {
        return error.InvalidContactTag;
    }

    if (!std.mem.eql(u8, tag.items[0], "p")) {
        return error.InvalidContactTag;
    }

    var pubkey: [32]u8 = undefined;
    try parse_pubkey(tag.items[1], &pubkey);

    var relay: ?[]const u8 = null;
    if (tag.items.len >= 3) {
        if (tag.items[2].len > limits.nip02_contact_relay_url_bytes_max) {
            return error.InvalidContactTag;
        }
        relay = tag.items[2];
    }

    var petname: ?[]const u8 = null;
    if (tag.items.len >= 4) {
        if (tag.items[3].len > limits.nip02_contact_petname_bytes_max) {
            return error.InvalidContactTag;
        }
        petname = tag.items[3];
    }

    return .{
        .pubkey = pubkey,
        .relay = relay,
        .petname = petname,
    };
}

fn parse_pubkey(source: []const u8, out: *[32]u8) ContactsError!void {
    std.debug.assert(@intFromPtr(out) != 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (source.len != limits.pubkey_hex_length) {
        return error.InvalidPubkey;
    }

    var index: u8 = 0;
    while (index < source.len) : (index += 1) {
        const byte = source[index];
        const is_digit = byte >= '0' and byte <= '9';
        if (is_digit) {
            continue;
        }

        const is_lower_hex = byte >= 'a' and byte <= 'f';
        if (!is_lower_hex) {
            return error.InvalidPubkey;
        }
    }

    _ = std.fmt.hexToBytes(out, source) catch {
        return error.InvalidPubkey;
    };
}

fn contact_event(kind: u32, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(tags.len <= std.math.maxInt(usize));

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 0,
        .content = "",
        .tags = tags,
    };
}

test "contacts_extract valid vectors preserve ordering and optional fields" {
    const tag_one_items = [_][]const u8{
        "p",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "wss://relay.one",
        "alice",
    };
    const tag_two_items = [_][]const u8{
        "p",
        "2222222222222222222222222222222222222222222222222222222222222222",
    };
    const tag_three_items = [_][]const u8{
        "p",
        "3333333333333333333333333333333333333333333333333333333333333333",
        "",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = tag_one_items[0..] },
        .{ .items = tag_two_items[0..] },
        .{ .items = tag_three_items[0..] },
    };
    const event = contact_event(3, tags[0..]);
    var output: [limits.nip02_contacts_max]ContactEntry = undefined;

    const extracted_count = try contacts_extract(&event, output[0..]);

    try std.testing.expectEqual(@as(u16, 3), extracted_count);
    try std.testing.expect(output[0].pubkey[0] == 0x11);
    try std.testing.expect(output[1].pubkey[0] == 0x22);
    try std.testing.expect(output[2].pubkey[0] == 0x33);
    try std.testing.expectEqualStrings("wss://relay.one", output[0].relay.?);
    try std.testing.expect(output[1].relay == null);
    try std.testing.expectEqualStrings("", output[2].relay.?);
    try std.testing.expectEqualStrings("alice", output[0].petname.?);
    try std.testing.expect(output[1].petname == null);
    try std.testing.expect(output[2].petname == null);
}

test "contacts_extract valid vectors include empty list and relay-only" {
    const empty_event = contact_event(3, &.{});
    var empty_out: [1]ContactEntry = undefined;
    const empty_count = try contacts_extract(&empty_event, empty_out[0..]);
    try std.testing.expectEqual(@as(u16, 0), empty_count);

    const relay_only_items = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "wss://relay.only",
    };
    const relay_only_tags = [_]nip01_event.EventTag{.{ .items = relay_only_items[0..] }};
    const relay_only_event = contact_event(3, relay_only_tags[0..]);
    var relay_only_out: [1]ContactEntry = undefined;
    const relay_only_count = try contacts_extract(&relay_only_event, relay_only_out[0..]);

    try std.testing.expectEqual(@as(u16, 1), relay_only_count);
    try std.testing.expectEqualStrings("wss://relay.only", relay_only_out[0].relay.?);
    try std.testing.expect(relay_only_out[0].petname == null);
}

test "contacts_extract rejects wrong kind" {
    const tag_items = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = tag_items[0..] }};
    const event = contact_event(1, tags[0..]);
    var output: [1]ContactEntry = undefined;

    try std.testing.expectError(error.InvalidEventKind, contacts_extract(&event, output[0..]));
}

test "contacts_extract rejects non p tags in strict path" {
    const non_p_tag_items = [_][]const u8{
        "e",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = non_p_tag_items[0..] }};
    const event = contact_event(3, tags[0..]);
    var output: [1]ContactEntry = undefined;

    try std.testing.expectError(error.InvalidContactTag, contacts_extract(&event, output[0..]));
}

test "contacts_extract rejects malformed pubkey" {
    const bad_pubkey_case_items = [_][]const u8{
        "p",
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    };
    const bad_pubkey_length_items = [_][]const u8{
        "p",
        "abc",
    };
    const bad_case_tags = [_]nip01_event.EventTag{.{ .items = bad_pubkey_case_items[0..] }};
    const bad_length_tags = [_]nip01_event.EventTag{.{ .items = bad_pubkey_length_items[0..] }};
    const bad_case_event = contact_event(3, bad_case_tags[0..]);
    const bad_length_event = contact_event(3, bad_length_tags[0..]);
    var output: [1]ContactEntry = undefined;

    try std.testing.expectError(
        error.InvalidPubkey,
        contacts_extract(&bad_case_event, output[0..]),
    );
    try std.testing.expectError(
        error.InvalidPubkey,
        contacts_extract(&bad_length_event, output[0..]),
    );
}

test "contacts_extract returns buffer too small" {
    const first_tag = [_][]const u8{
        "p",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const second_tag = [_][]const u8{
        "p",
        "2222222222222222222222222222222222222222222222222222222222222222",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = first_tag[0..] },
        .{ .items = second_tag[0..] },
    };
    const event = contact_event(3, tags[0..]);
    var output: [1]ContactEntry = undefined;

    try std.testing.expectError(error.BufferTooSmall, contacts_extract(&event, output[0..]));
}
