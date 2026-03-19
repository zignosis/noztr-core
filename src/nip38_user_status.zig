const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip30_custom_emoji = @import("nip30_custom_emoji.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const user_status_kind: u32 = 30315;

pub const Nip38Error = error{
    InvalidStatusKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateExpirationTag,
    InvalidExpirationTag,
    InvalidUrlTag,
    InvalidPubkeyTag,
    InvalidEventTag,
    InvalidCoordinateTag,
    InvalidEmojiTag,
    BufferTooSmall,
};

pub const UserStatusInfo = struct {
    identifier: []const u8,
    content: []const u8,
    expiration: ?u64 = null,
    url_count: u16 = 0,
    pubkey_count: u16 = 0,
    event_count: u16 = 0,
    coordinate_count: u16 = 0,
    emoji_count: u16 = 0,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded user-status metadata from a `kind:30315` event.
pub fn user_status_extract(
    event: *const nip01_event.Event,
    out_urls: [][]const u8,
    out_pubkeys: [][32]u8,
    out_event_ids: [][32]u8,
    out_coordinates: [][]const u8,
    out_emojis: []nip30_custom_emoji.EmojiTagInfo,
) Nip38Error!UserStatusInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_urls.len <= limits.tags_max);

    if (event.kind != user_status_kind) return error.InvalidStatusKind;

    var identifier: ?[]const u8 = null;
    var info = UserStatusInfo{ .identifier = undefined, .content = event.content };
    for (event.tags) |tag| {
        try apply_status_tag(
            tag,
            &identifier,
            &info,
            out_urls,
            out_pubkeys,
            out_event_ids,
            out_coordinates,
            out_emojis,
        );
    }
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    return info;
}

pub fn user_status_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) Nip38Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn user_status_build_url_tag(
    output: *BuiltTag,
    url: []const u8,
) Nip38Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    output.items[0] = "r";
    output.items[1] = parse_url(url) catch return error.InvalidUrlTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn user_status_build_pubkey_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
) Nip38Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    _ = lower_hex_32.parse(pubkey_hex) catch return error.InvalidPubkeyTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn user_status_build_event_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
) Nip38Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    _ = lower_hex_32.parse(event_id_hex) catch return error.InvalidEventTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn user_status_build_coordinate_tag(
    output: *BuiltTag,
    coordinate: []const u8,
) Nip38Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 3);

    _ = parse_coordinate_text(coordinate) catch return error.InvalidCoordinateTag;
    output.items[0] = "a";
    output.items[1] = coordinate;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn user_status_build_expiration_tag(
    output: *BuiltTag,
    unix_seconds: u64,
) Nip38Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(unix_seconds <= std.math.maxInt(u64));

    output.items[0] = "expiration";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{unix_seconds}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_status_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *UserStatusInfo,
    out_urls: [][]const u8,
    out_pubkeys: [][32]u8,
    out_event_ids: [][32]u8,
    out_coordinates: [][]const u8,
    out_emojis: []nip30_custom_emoji.EmojiTagInfo,
) Nip38Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, tag.items[0], "expiration")) return apply_expiration_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "r")) return append_url(tag, info, out_urls);
    if (std.mem.eql(u8, tag.items[0], "p")) return append_pubkey(tag, info, out_pubkeys);
    if (std.mem.eql(u8, tag.items[0], "e")) return append_event(tag, info, out_event_ids);
    if (std.mem.eql(u8, tag.items[0], "a")) return append_coordinate(tag, info, out_coordinates);
    if (std.mem.eql(u8, tag.items[0], "emoji")) return append_emoji(tag, info, out_emojis);
}

fn apply_identifier_tag(tag: nip01_event.EventTag, identifier: *?[]const u8) Nip38Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    identifier.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn apply_expiration_tag(tag: nip01_event.EventTag, info: *UserStatusInfo) Nip38Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.expiration != null) return error.DuplicateExpirationTag;
    if (tag.items.len != 2) return error.InvalidExpirationTag;
    info.expiration = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch {
        return error.InvalidExpirationTag;
    };
}

fn append_url(
    tag: nip01_event.EventTag,
    info: *UserStatusInfo,
    out_urls: [][]const u8,
) Nip38Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.url_count <= out_urls.len);

    if (tag.items.len != 2) return error.InvalidUrlTag;
    if (info.url_count == out_urls.len) return error.BufferTooSmall;
    out_urls[info.url_count] = parse_url(tag.items[1]) catch return error.InvalidUrlTag;
    info.url_count += 1;
}

fn append_pubkey(
    tag: nip01_event.EventTag,
    info: *UserStatusInfo,
    out_pubkeys: [][32]u8,
) Nip38Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.pubkey_count <= out_pubkeys.len);

    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidPubkeyTag;
    if (info.pubkey_count == out_pubkeys.len) return error.BufferTooSmall;
    out_pubkeys[info.pubkey_count] = lower_hex_32.parse(tag.items[1]) catch {
        return error.InvalidPubkeyTag;
    };
    info.pubkey_count += 1;
}

fn append_event(
    tag: nip01_event.EventTag,
    info: *UserStatusInfo,
    out_event_ids: [][32]u8,
) Nip38Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.event_count <= out_event_ids.len);

    if (tag.items.len < 2 or tag.items.len > 4) return error.InvalidEventTag;
    if (info.event_count == out_event_ids.len) return error.BufferTooSmall;
    out_event_ids[info.event_count] = lower_hex_32.parse(tag.items[1]) catch {
        return error.InvalidEventTag;
    };
    info.event_count += 1;
}

fn append_coordinate(
    tag: nip01_event.EventTag,
    info: *UserStatusInfo,
    out_coordinates: [][]const u8,
) Nip38Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.coordinate_count <= out_coordinates.len);

    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidCoordinateTag;
    if (info.coordinate_count == out_coordinates.len) return error.BufferTooSmall;
    out_coordinates[info.coordinate_count] = parse_coordinate_text(tag.items[1]) catch {
        return error.InvalidCoordinateTag;
    };
    info.coordinate_count += 1;
}

fn append_emoji(
    tag: nip01_event.EventTag,
    info: *UserStatusInfo,
    out_emojis: []nip30_custom_emoji.EmojiTagInfo,
) Nip38Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.emoji_count <= out_emojis.len);

    if (info.emoji_count == out_emojis.len) return error.BufferTooSmall;
    out_emojis[info.emoji_count] = nip30_custom_emoji.emoji_tag_extract(tag) catch {
        return error.InvalidEmojiTag;
    };
    info.emoji_count += 1;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidUrl;
    if (text.len == 0) return error.InvalidUrl;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    return text;
}

fn parse_coordinate_text(text: []const u8) error{InvalidCoordinate}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidCoordinate;
    var parts = std.mem.splitScalar(u8, text, ':');
    const kind_text = parts.next() orelse return error.InvalidCoordinate;
    const pubkey_text = parts.next() orelse return error.InvalidCoordinate;
    const identifier = parts.next() orelse return error.InvalidCoordinate;
    if (parts.next() != null) return error.InvalidCoordinate;
    _ = std.fmt.parseUnsigned(u32, kind_text, 10) catch return error.InvalidCoordinate;
    _ = lower_hex_32.parse(pubkey_text) catch return error.InvalidCoordinate;
    if (identifier.len == 0) return error.InvalidCoordinate;
    if (!std.unicode.utf8ValidateSlice(identifier)) return error.InvalidCoordinate;
    return text;
}

test "NIP-38 extracts status metadata and links" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "music" } },
        .{ .items = &.{ "r", "https://nostr.world" } },
        .{ .items = &.{ "expiration", "1700000000" } },
        .{ .items = &.{ "emoji", "wave", "https://cdn.example/wave.png" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x38} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = user_status_kind,
        .tags = tags[0..],
        .content = "Working",
        .sig = [_]u8{0x22} ** 64,
    };
    var urls: [1][]const u8 = undefined;
    var pubkeys: [0][32]u8 = .{};
    var events: [0][32]u8 = .{};
    var coords: [0][]const u8 = .{};
    var emojis: [1]nip30_custom_emoji.EmojiTagInfo = undefined;

    const info = try user_status_extract(&event, urls[0..], pubkeys[0..], events[0..], coords[0..], emojis[0..]);

    try std.testing.expectEqualStrings("music", info.identifier);
    try std.testing.expectEqualStrings("Working", info.content);
    try std.testing.expectEqual(@as(?u64, 1_700_000_000), info.expiration);
    try std.testing.expectEqual(@as(u16, 1), info.url_count);
    try std.testing.expectEqual(@as(u16, 1), info.emoji_count);
}

test "NIP-38 rejects duplicate identifiers" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "general" } },
        .{ .items = &.{ "d", "music" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x39} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = user_status_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x23} ** 64,
    };

    try std.testing.expectError(
        error.DuplicateIdentifierTag,
        user_status_extract(&event, &.{}, &.{}, &.{}, &.{}, &.{}),
    );
}

test "NIP-38 builds identifier and expiration tags" {
    var built: BuiltTag = .{};
    var expiration_built: BuiltTag = .{};

    const identifier = try user_status_build_identifier_tag(&built, "general");
    const expiration = try user_status_build_expiration_tag(&expiration_built, 42);

    try std.testing.expectEqualStrings("d", identifier.items[0]);
    try std.testing.expectEqualStrings("general", identifier.items[1]);
    try std.testing.expectEqualStrings("expiration", expiration.items[0]);
    try std.testing.expectEqualStrings("42", expiration.items[1]);
}

test "NIP-38 rejects overlong pubkey builder input with typed error" {
    var built: BuiltTag = .{};
    const overlong = [_]u8{'a'} ** (limits.tag_item_bytes_max + 1);

    try std.testing.expectError(
        error.InvalidPubkeyTag,
        user_status_build_pubkey_tag(&built, overlong[0..]),
    );
}
