const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const url_with_host = @import("internal/url_with_host.zig");

pub const web_bookmark_kind: u32 = 39701;

pub const WebBookmarkError = error{
    UnsupportedKind,
    MissingIdentifier,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateTitleTag,
    InvalidTitleTag,
    DuplicatePublishedAtTag,
    InvalidPublishedAtTag,
    InvalidHashtagTag,
    InvalidContent,
    BufferTooSmall,
};

pub const WebBookmarkInfo = struct {
    identifier: []const u8,
    content: []const u8,
    title: ?[]const u8 = null,
    published_at: ?u64 = null,
    hashtag_count: u16 = 0,
};

pub const BuiltTag = struct {
    items: [2][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    /// Returns the built tag backed by this buffer.
    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Returns whether the event kind is supported by the strict NIP-B0 helper.
pub fn web_bookmark_is_supported(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= limits.kind_max);

    return event.kind == web_bookmark_kind;
}

/// Extracts bounded NIP-B0 bookmark metadata and ordered hashtags.
pub fn web_bookmark_extract(
    event: *const nip01_event.Event,
    out_hashtags: [][]const u8,
) WebBookmarkError!WebBookmarkInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_hashtags.len <= std.math.maxInt(u16));

    if (event.kind != web_bookmark_kind) return error.UnsupportedKind;
    try validate_content(event.content);

    var identifier: ?[]const u8 = null;
    var info = WebBookmarkInfo{
        .identifier = undefined,
        .content = event.content,
    };
    for (event.tags) |tag| {
        try apply_tag(tag, &identifier, &info, out_hashtags);
    }
    info.identifier = identifier orelse return error.MissingIdentifier;
    return info;
}

/// Builds a bookmark `d` tag with a scheme-less URL identifier.
pub fn web_bookmark_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) WebBookmarkError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_scheme_less_url(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bookmark `title` tag.
pub fn web_bookmark_build_title_tag(
    output: *BuiltTag,
    title: []const u8,
) WebBookmarkError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(title.len <= limits.tag_item_bytes_max);

    output.items[0] = "title";
    output.items[1] = parse_nonempty_utf8(title) catch return error.InvalidTitleTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bookmark `published_at` tag.
pub fn web_bookmark_build_published_at_tag(
    output: *BuiltTag,
    published_at: u64,
) WebBookmarkError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(published_at <= std.math.maxInt(u64));

    output.items[0] = "published_at";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{published_at}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bookmark `t` hashtag tag.
pub fn web_bookmark_build_hashtag_tag(
    output: *BuiltTag,
    hashtag: []const u8,
) WebBookmarkError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(hashtag.len <= limits.tag_item_bytes_max);

    output.items[0] = "t";
    output.items[1] = parse_hashtag_value(hashtag) catch return error.InvalidHashtagTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *WebBookmarkInfo,
    out_hashtags: [][]const u8,
) WebBookmarkError!void {
    std.debug.assert(@intFromPtr(identifier) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, name, "title")) return apply_title_tag(tag, info);
    if (std.mem.eql(u8, name, "published_at")) return apply_published_at_tag(tag, info);
    if (std.mem.eql(u8, name, "t")) return apply_hashtag_tag(tag, info, out_hashtags);
}

fn apply_identifier_tag(tag: nip01_event.EventTag, identifier: *?[]const u8) WebBookmarkError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    identifier.* = parse_identifier_value(tag) catch return error.InvalidIdentifierTag;
}

fn apply_title_tag(tag: nip01_event.EventTag, info: *WebBookmarkInfo) WebBookmarkError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.title != null) return error.DuplicateTitleTag;
    info.title = parse_single_utf8_value(tag) catch return error.InvalidTitleTag;
}

fn apply_published_at_tag(
    tag: nip01_event.EventTag,
    info: *WebBookmarkInfo,
) WebBookmarkError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.published_at != null) return error.DuplicatePublishedAtTag;
    info.published_at = parse_u64_value(tag) catch return error.InvalidPublishedAtTag;
}

fn apply_hashtag_tag(
    tag: nip01_event.EventTag,
    info: *WebBookmarkInfo,
    out_hashtags: [][]const u8,
) WebBookmarkError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    const hashtag = parse_hashtag_tag(tag) catch return error.InvalidHashtagTag;
    if (info.hashtag_count == out_hashtags.len) return error.BufferTooSmall;
    out_hashtags[info.hashtag_count] = hashtag;
    info.hashtag_count += 1;
}

fn parse_identifier_value(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_scheme_less_url(tag.items[1]) catch return error.InvalidValue;
}

fn parse_single_utf8_value(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_nonempty_utf8(tag.items[1]) catch return error.InvalidValue;
}

fn parse_u64_value(tag: nip01_event.EventTag) error{InvalidValue}!u64 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@sizeOf(u64) == 8);

    const text = try parse_single_utf8_value(tag);
    return std.fmt.parseUnsigned(u64, text, 10) catch return error.InvalidValue;
}

fn parse_hashtag_tag(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_hashtag_value(tag.items[1]) catch return error.InvalidValue;
}

fn validate_content(content: []const u8) WebBookmarkError!void {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (!std.unicode.utf8ValidateSlice(content)) return error.InvalidContent;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_hashtag_value(text: []const u8) error{InvalidHashtag}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    const value = parse_nonempty_utf8(text) catch return error.InvalidHashtag;
    for (value) |byte| {
        if (byte >= 'A' and byte <= 'Z') return error.InvalidHashtag;
        if (std.ascii.isWhitespace(byte)) return error.InvalidHashtag;
    }
    return value;
}

fn parse_scheme_less_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    _ = parse_nonempty_utf8(text) catch return error.InvalidUrl;
    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) return error.InvalidUrl;
    }
    if (std.mem.indexOf(u8, text, "://") != null) return error.InvalidUrl;

    var buffer: [limits.tag_item_bytes_max + 8]u8 = undefined;
    const rendered = std.fmt.bufPrint(buffer[0..], "https://{s}", .{text}) catch {
        return error.InvalidUrl;
    };
    _ = parse_url(rendered) catch return error.InvalidUrl;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max >= limits.tag_item_bytes_max);

    return url_with_host.parse(text, limits.content_bytes_max);
}

test "web bookmark extract parses bounded metadata and hashtags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "alice.blog/post" } },
        .{ .items = &.{ "title", "Blog insights by Alice" } },
        .{ .items = &.{ "published_at", "1738863000" } },
        .{ .items = &.{ "t", "post" } },
        .{ .items = &.{ "t", "insight" } },
    };
    var hashtags: [2][]const u8 = undefined;

    const parsed = try web_bookmark_extract(
        &.{
            .id = [_]u8{0} ** 32,
            .pubkey = [_]u8{0} ** 32,
            .sig = [_]u8{0} ** 64,
            .kind = web_bookmark_kind,
            .created_at = 0,
            .content = "A detailed bookmark note.",
            .tags = tags[0..],
        },
        hashtags[0..],
    );

    try std.testing.expectEqualStrings("alice.blog/post", parsed.identifier);
    try std.testing.expectEqualStrings("Blog insights by Alice", parsed.title.?);
    try std.testing.expectEqual(@as(u64, 1738863000), parsed.published_at.?);
    try std.testing.expectEqual(@as(u16, 2), parsed.hashtag_count);
    try std.testing.expectEqualStrings("post", hashtags[0]);
    try std.testing.expectEqualStrings("insight", hashtags[1]);
}

test "web bookmark extract rejects malformed required and supported tags" {
    const missing_d = [_]nip01_event.EventTag{.{ .items = &.{ "title", "A" } }};
    const invalid_identifier = [_]nip01_event.EventTag{.{ .items = &.{ "d", "not a url id" } }};
    const duplicate_title = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "alice.blog/post" } },
        .{ .items = &.{ "title", "A" } },
        .{ .items = &.{ "title", "B" } },
    };
    const invalid_published_at = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "alice.blog/post" } },
        .{ .items = &.{ "published_at", "abc" } },
    };
    const invalid_hashtag = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "alice.blog/post" } },
        .{ .items = &.{ "t", "Insight" } },
    };
    var hashtags: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.MissingIdentifier,
        web_bookmark_extract(&test_event(missing_d[0..], "body"), hashtags[0..]),
    );
    try std.testing.expectError(
        error.InvalidIdentifierTag,
        web_bookmark_extract(&test_event(invalid_identifier[0..], "body"), hashtags[0..]),
    );
    try std.testing.expectError(
        error.DuplicateTitleTag,
        web_bookmark_extract(&test_event(duplicate_title[0..], "body"), hashtags[0..]),
    );
    try std.testing.expectError(
        error.InvalidPublishedAtTag,
        web_bookmark_extract(&test_event(invalid_published_at[0..], "body"), hashtags[0..]),
    );
    try std.testing.expectError(
        error.InvalidHashtagTag,
        web_bookmark_extract(&test_event(invalid_hashtag[0..], "body"), hashtags[0..]),
    );
}

test "web bookmark builders emit canonical bounded tags" {
    var identifier_tag: BuiltTag = .{};
    var title_tag: BuiltTag = .{};
    var published_at_tag: BuiltTag = .{};
    var hashtag_tag: BuiltTag = .{};

    const identifier = try web_bookmark_build_identifier_tag(&identifier_tag, "alice.blog/post");
    try std.testing.expectEqualStrings("d", identifier.items[0]);
    try std.testing.expectEqualStrings("alice.blog/post", identifier.items[1]);
    try std.testing.expectEqualStrings(
        "title",
        (try web_bookmark_build_title_tag(&title_tag, "Blog insights by Alice")).items[0],
    );
    try std.testing.expectEqualStrings(
        "published_at",
        (try web_bookmark_build_published_at_tag(&published_at_tag, 1738863000)).items[0],
    );
    try std.testing.expectEqualStrings(
        "t",
        (try web_bookmark_build_hashtag_tag(&hashtag_tag, "post")).items[0],
    );
    try std.testing.expectError(
        error.InvalidIdentifierTag,
        web_bookmark_build_identifier_tag(&identifier_tag, "https://example.com/post"),
    );
}

test "web bookmark extract rejects unsupported kind and invalid content" {
    const tags = [_]nip01_event.EventTag{.{ .items = &.{ "d", "alice.blog/post" } }};
    var hashtags: [0][]const u8 = .{};
    const invalid_content = [_]u8{ 0xff };
    const wrong_kind_event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 0,
        .content = "body",
        .tags = tags[0..],
    };

    try std.testing.expectError(
        error.UnsupportedKind,
        web_bookmark_extract(&wrong_kind_event, hashtags[0..]),
    );
    try std.testing.expectError(
        error.InvalidContent,
        web_bookmark_extract(
            &.{
                .id = [_]u8{0} ** 32,
                .pubkey = [_]u8{0} ** 32,
                .sig = [_]u8{0} ** 64,
                .kind = web_bookmark_kind,
                .created_at = 0,
                .content = invalid_content[0..],
                .tags = tags[0..],
            },
            hashtags[0..],
        ),
    );
}

fn test_event(tags: []const nip01_event.EventTag, content: []const u8) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(content.len <= limits.content_bytes_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = web_bookmark_kind,
        .created_at = 0,
        .content = content,
        .tags = tags,
    };
}
