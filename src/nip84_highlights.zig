const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const highlight_kind: u32 = 9802;

pub const Nip84Error = error{
    InvalidHighlightKind,
    DuplicateSourceTag,
    InvalidSourceTag,
    InvalidAuthorTag,
    InvalidUrlReferenceTag,
    DuplicateContextTag,
    InvalidContextTag,
    DuplicateCommentTag,
    InvalidCommentTag,
    BufferTooSmall,
};

pub const EventSource = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const AddressSource = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const UrlReference = struct {
    url: []const u8,
    marker: ?[]const u8 = null,
};

pub const HighlightSource = union(enum) {
    event: EventSource,
    address: AddressSource,
    url: UrlReference,
};

pub const HighlightAttribution = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
    role: ?[]const u8 = null,
};

pub const HighlightInfo = struct {
    source: ?HighlightSource = null,
    attribution_count: u16 = 0,
    url_reference_count: u16 = 0,
    context: ?[]const u8 = null,
    comment: ?[]const u8 = null,
};

pub const BuiltTag = struct {
    items: [4][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded NIP-84 highlight references, attributions, and optional quote metadata.
pub fn highlight_extract(
    event: *const nip01_event.Event,
    out_attributions: []HighlightAttribution,
    out_url_references: []UrlReference,
) Nip84Error!HighlightInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_attributions.len <= limits.tags_max);

    if (event.kind != highlight_kind) return error.InvalidHighlightKind;

    var info = HighlightInfo{};
    for (event.tags) |tag| {
        try apply_tag(tag, &info, out_attributions, out_url_references);
    }
    return info;
}

/// Builds a canonical highlight source `e` tag.
pub fn highlight_build_event_source_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
) Nip84Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_id_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(event_id_hex) catch return error.InvalidSourceTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |hint| {
        output.items[2] = parse_url(hint) catch return error.InvalidSourceTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical highlight source `a` tag.
pub fn highlight_build_address_source_tag(
    output: *BuiltTag,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) Nip84Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(coordinate_text.len <= limits.tag_item_bytes_max);

    _ = parse_coordinate(coordinate_text) catch return error.InvalidSourceTag;
    output.items[0] = "a";
    output.items[1] = coordinate_text;
    output.item_count = 2;
    if (relay_hint) |hint| {
        output.items[2] = parse_url(hint) catch return error.InvalidSourceTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical highlight URL `r` tag with optional source or mention marker.
pub fn highlight_build_url_reference_tag(
    output: *BuiltTag,
    url: []const u8,
    marker: ?[]const u8,
) Nip84Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(url.len <= limits.tag_item_bytes_max);

    output.items[0] = "r";
    output.items[1] = parse_url(url) catch return error.InvalidUrlReferenceTag;
    output.item_count = 2;
    if (marker) |value| {
        output.items[2] = parse_nonempty_utf8(value) catch return error.InvalidUrlReferenceTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical highlight attribution `p` tag.
pub fn highlight_build_author_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
    role: ?[]const u8,
) Nip84Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidAuthorTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |hint| {
        output.items[2] = parse_url(hint) catch return error.InvalidAuthorTag;
        output.item_count = 3;
    }
    if (role) |value| {
        output.items[output.item_count] = parse_nonempty_utf8(value) catch return error.InvalidAuthorTag;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a canonical `context` tag.
pub fn highlight_build_context_tag(
    output: *BuiltTag,
    context: []const u8,
) Nip84Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(context.len <= limits.tag_item_bytes_max);

    output.items[0] = "context";
    output.items[1] = parse_nonempty_utf8(context) catch return error.InvalidContextTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `comment` tag.
pub fn highlight_build_comment_tag(
    output: *BuiltTag,
    comment: []const u8,
) Nip84Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(comment.len <= limits.tag_item_bytes_max);

    output.items[0] = "comment";
    output.items[1] = parse_nonempty_utf8(comment) catch return error.InvalidCommentTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_tag(
    tag: nip01_event.EventTag,
    info: *HighlightInfo,
    out_attributions: []HighlightAttribution,
    out_url_references: []UrlReference,
) Nip84Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (std.mem.eql(u8, tag.items[0], "e")) return parse_event_source(tag, info);
    if (std.mem.eql(u8, tag.items[0], "a")) return parse_address_source(tag, info);
    if (std.mem.eql(u8, tag.items[0], "r")) return parse_url_reference(tag, info, out_url_references);
    if (std.mem.eql(u8, tag.items[0], "p")) return parse_attribution(tag, info, out_attributions);
    if (std.mem.eql(u8, tag.items[0], "context")) return parse_context(tag, info);
    if (std.mem.eql(u8, tag.items[0], "comment")) return parse_comment(tag, info);
}

fn parse_event_source(tag: nip01_event.EventTag, info: *HighlightInfo) Nip84Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len < 2) return error.InvalidSourceTag;
    if (info.source != null) return error.DuplicateSourceTag;

    info.source = .{
        .event = .{
            .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidSourceTag,
            .relay_hint = try parse_optional_url_item(tag, 2, error.InvalidSourceTag),
        },
    };
}

fn parse_address_source(tag: nip01_event.EventTag, info: *HighlightInfo) Nip84Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len < 2) return error.InvalidSourceTag;
    if (info.source != null) return error.DuplicateSourceTag;

    var parsed = parse_coordinate(tag.items[1]) catch return error.InvalidSourceTag;
    parsed.relay_hint = try parse_optional_url_item(tag, 2, error.InvalidSourceTag);
    info.source = .{ .address = parsed };
}

fn parse_url_reference(
    tag: nip01_event.EventTag,
    info: *HighlightInfo,
    out_url_references: []UrlReference,
) Nip84Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out_url_references.len <= limits.tags_max);

    if (tag.items.len < 2) return error.InvalidUrlReferenceTag;
    if (info.url_reference_count >= out_url_references.len) return error.BufferTooSmall;

    const marker = try parse_optional_text_item(tag, 2, error.InvalidUrlReferenceTag);
    const parsed = UrlReference{
        .url = parse_url(tag.items[1]) catch return error.InvalidUrlReferenceTag,
        .marker = marker,
    };
    out_url_references[info.url_reference_count] = parsed;
    info.url_reference_count += 1;
    if (!is_source_marker(parsed.marker)) return;
    if (info.source != null) return error.DuplicateSourceTag;
    info.source = .{ .url = parsed };
}

fn parse_attribution(
    tag: nip01_event.EventTag,
    info: *HighlightInfo,
    out_attributions: []HighlightAttribution,
) Nip84Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out_attributions.len <= limits.tags_max);

    if (tag.items.len < 2) return error.InvalidAuthorTag;
    if (info.attribution_count >= out_attributions.len) return error.BufferTooSmall;

    out_attributions[info.attribution_count] = .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidAuthorTag,
        .relay_hint = try parse_optional_url_item(tag, 2, error.InvalidAuthorTag),
        .role = try parse_optional_text_item(tag, 3, error.InvalidAuthorTag),
    };
    info.attribution_count += 1;
}

fn parse_context(tag: nip01_event.EventTag, info: *HighlightInfo) Nip84Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len < 2) return error.InvalidContextTag;
    if (info.context != null) return error.DuplicateContextTag;
    info.context = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidContextTag;
}

fn parse_comment(tag: nip01_event.EventTag, info: *HighlightInfo) Nip84Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len < 2) return error.InvalidCommentTag;
    if (info.comment != null) return error.DuplicateCommentTag;
    info.comment = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidCommentTag;
}

fn is_source_marker(marker: ?[]const u8) bool {
    std.debug.assert(@sizeOf(?[]const u8) > 0);
    std.debug.assert(@sizeOf([]const u8) > 0);

    if (marker) |value| return std.mem.eql(u8, value, "source");
    return true;
}

fn parse_coordinate(text: []const u8) error{InvalidCoordinate}!AddressSource {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidCoordinate;
    if (first_colon == 0) return error.InvalidCoordinate;
    const second_offset = std.mem.indexOfScalarPos(u8, text, first_colon + 1, ':') orelse {
        return error.InvalidCoordinate;
    };
    if (second_offset == first_colon + 1 or second_offset + 1 > text.len) {
        return error.InvalidCoordinate;
    }

    const kind_text = text[0..first_colon];
    const pubkey_text = text[first_colon + 1 .. second_offset];
    const identifier = text[second_offset + 1 ..];
    const kind = std.fmt.parseInt(u32, kind_text, 10) catch return error.InvalidCoordinate;
    try validate_coordinate_kind(kind, identifier);
    return .{
        .kind = kind,
        .pubkey = parse_lower_hex_32(pubkey_text) catch return error.InvalidCoordinate,
        .identifier = identifier,
    };
}

fn validate_coordinate_kind(kind: u32, identifier: []const u8) error{InvalidCoordinate}!void {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    const replaceable = kind >= 10000 and kind < 20000;
    const addressable = kind >= 30000 and kind < 40000;
    if (!replaceable and !addressable) return error.InvalidCoordinate;
    if (replaceable and identifier.len != 0) return error.InvalidCoordinate;
    if (addressable and identifier.len == 0) return error.InvalidCoordinate;
}

fn parse_optional_url_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: Nip84Error,
) Nip84Error!?[]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(@typeInfo(Nip84Error) == .error_set);

    if (tag.items.len <= index) return null;
    if (tag.items[index].len == 0) return null;
    return parse_url(tag.items[index]) catch return invalid_error;
}

fn parse_optional_text_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: Nip84Error,
) Nip84Error!?[]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(@typeInfo(Nip84Error) == .error_set);

    if (tag.items.len <= index) return null;
    if (tag.items[index].len == 0) return null;
    return parse_nonempty_utf8(tag.items[index]) catch return invalid_error;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0 or parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    var output: [32]u8 = undefined;
    if (text.len != limits.id_hex_length) return error.InvalidHex;
    for (text) |byte| {
        if (!std.ascii.isHex(byte) or std.ascii.isUpper(byte)) return error.InvalidHex;
    }
    _ = std.fmt.hexToBytes(&output, text) catch return error.InvalidHex;
    return output;
}

fn test_event(kind: u32, content: []const u8, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 0,
        .tags = tags,
        .content = content,
    };
}

test "highlight extract parses event source attributions and quote metadata" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "e",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "wss://relay.example",
            "root",
        } },
        .{ .items = &.{ "p", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "", "author" } },
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "", "mention" } },
        .{ .items = &.{ "r", "https://example.com/full-article", "mention" } },
        .{ .items = &.{ "context", "The sentence before and after." } },
        .{ .items = &.{ "comment", "Quoted because this paragraph matters." } },
    };
    var attributions: [4]HighlightAttribution = undefined;
    var urls: [4]UrlReference = undefined;

    const parsed = try highlight_extract(&test_event(highlight_kind, "important words", &tags), &attributions, &urls);

    try std.testing.expect(parsed.source != null);
    try std.testing.expect(parsed.source.? == .event);
    try std.testing.expectEqualStrings("wss://relay.example", parsed.source.?.event.relay_hint.?);
    try std.testing.expectEqual(@as(u16, 2), parsed.attribution_count);
    try std.testing.expectEqual(@as(u16, 1), parsed.url_reference_count);
    try std.testing.expectEqualStrings("author", attributions[0].role.?);
    try std.testing.expectEqualStrings("mention", attributions[1].role.?);
    try std.testing.expectEqualStrings("mention", urls[0].marker.?);
    try std.testing.expectEqualStrings("The sentence before and after.", parsed.context.?);
    try std.testing.expectEqualStrings("Quoted because this paragraph matters.", parsed.comment.?);
}

test "highlight extract parses url source and mention urls" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "r", "https://example.com/source", "source" } },
        .{ .items = &.{ "r", "https://example.com/mention", "mention" } },
    };
    var attributions: [1]HighlightAttribution = undefined;
    var urls: [2]UrlReference = undefined;

    const parsed = try highlight_extract(&test_event(highlight_kind, "", &tags), &attributions, &urls);

    try std.testing.expect(parsed.source != null);
    try std.testing.expect(parsed.source.? == .url);
    try std.testing.expectEqualStrings("https://example.com/source", parsed.source.?.url.url);
    try std.testing.expectEqual(@as(u16, 2), parsed.url_reference_count);
    try std.testing.expectEqualStrings("mention", urls[1].marker.?);
}

test "highlight extract rejects duplicate source tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "e",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
        .{ .items = &.{ "r", "https://example.com/source" } },
    };
    var attributions: [1]HighlightAttribution = undefined;
    var urls: [2]UrlReference = undefined;

    try std.testing.expectError(
        error.DuplicateSourceTag,
        highlight_extract(&test_event(highlight_kind, "dup", &tags), &attributions, &urls),
    );
}

test "highlight builders emit canonical tags" {
    var built = BuiltTag{};

    const event_tag = try highlight_build_event_source_tag(
        &built,
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        "wss://relay.example",
    );
    try std.testing.expectEqual(@as(usize, 3), event_tag.items.len);
    try std.testing.expectEqualStrings("e", event_tag.items[0]);
    try std.testing.expectEqualStrings("wss://relay.example", event_tag.items[2]);

    const author_tag = try highlight_build_author_tag(
        &built,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        null,
        "editor",
    );
    try std.testing.expectEqual(@as(usize, 3), author_tag.items.len);
    try std.testing.expectEqualStrings("p", author_tag.items[0]);
    try std.testing.expectEqualStrings("editor", author_tag.items[2]);

    const url_tag = try highlight_build_url_reference_tag(&built, "https://example.com", "source");
    try std.testing.expectEqual(@as(usize, 3), url_tag.items.len);
    try std.testing.expectEqualStrings("source", url_tag.items[2]);
}
