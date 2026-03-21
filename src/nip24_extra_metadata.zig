const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const url_with_host = @import("internal/url_with_host.zig");
const nip73_external_ids = @import("nip73_external_ids.zig");

pub const Nip24Error = error{
    OutOfMemory,
    InvalidJson,
    InvalidDisplayName,
    InvalidWebsite,
    InvalidBanner,
    InvalidBot,
    InvalidBirthday,
    InvalidTitleTag,
    DuplicateTitleTag,
    InvalidReferenceTag,
    InvalidExternalIdTag,
    InvalidHashtagTag,
    BufferTooSmall,
};

pub const Birthday = struct {
    year: ?u16 = null,
    month: ?u8 = null,
    day: ?u8 = null,
};

pub const MetadataExtras = struct {
    display_name: ?[]const u8 = null,
    website: ?[]const u8 = null,
    banner: ?[]const u8 = null,
    bot: ?bool = null,
    birthday: ?Birthday = null,
};

pub const CommonTagInfo = struct {
    title: ?[]const u8 = null,
    reference_count: u16 = 0,
    external_id_count: u16 = 0,
    hashtag_count: u16 = 0,
};

pub const BuiltTag = struct {
    items: [2][]const u8 = undefined,
    item_count: u8 = 0,

    /// Returns the built tag backed by this buffer.
    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Parses the NIP-24 kind-0 metadata extras from JSON.
///
/// Lifetime and ownership:
/// - returned string fields borrow from `input`
/// - keep `input` alive while using borrowed fields
pub fn metadata_extras_parse_json(
    input: []const u8,
    scratch: std.mem.Allocator,
) Nip24Error!MetadataExtras {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(input.len <= limits.content_bytes_max);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch |parse_error| {
        return map_json_parse_error(parse_error);
    };
    if (root != .object) return error.InvalidJson;

    var extras = MetadataExtras{};
    var iterator = root.object.iterator();
    while (iterator.next()) |entry| {
        try parse_known_extra_field(&extras, entry.key_ptr.*, entry.value_ptr.*);
    }

    return extras;
}

/// Serializes the NIP-24 kind-0 metadata extras to deterministic JSON.
pub fn metadata_extras_serialize_json(
    output: []u8,
    extras: *const MetadataExtras,
) Nip24Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(extras) != 0);

    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();
    var needs_comma = false;

    writer.writeByte('{') catch return error.BufferTooSmall;
    try write_optional_string_field(writer, &needs_comma, "display_name", extras.display_name);
    try write_optional_string_field(writer, &needs_comma, "website", extras.website);
    try write_optional_string_field(writer, &needs_comma, "banner", extras.banner);
    try write_optional_bool_field(writer, &needs_comma, "bot", extras.bot);
    try write_optional_birthday_field(writer, &needs_comma, "birthday", extras.birthday);
    writer.writeByte('}') catch return error.BufferTooSmall;

    return stream.getWritten();
}

/// Extracts generic NIP-24 tag meanings from a tag slice when no more specific NIP overrides apply.
///
/// Lifetime and ownership:
/// - returned title, reference URLs, and hashtags borrow from the input tag storage
pub fn common_tags_extract(
    tags: []const nip01_event.EventTag,
    out_reference_urls: [][]const u8,
    out_hashtags: [][]const u8,
) Nip24Error!CommonTagInfo {
    std.debug.assert(out_reference_urls.len <= std.math.maxInt(u16));
    std.debug.assert(out_hashtags.len <= std.math.maxInt(u16));

    var info = CommonTagInfo{};
    for (tags) |tag| {
        try apply_common_tag(tag, &info, out_reference_urls, &.{}, out_hashtags);
    }
    return info;
}

/// Extracts generic NIP-24 tag meanings including NIP-73 external ids.
pub fn common_tags_extract_with_external_ids(
    tags: []const nip01_event.EventTag,
    out_reference_urls: [][]const u8,
    out_external_ids: []nip73_external_ids.ExternalId,
    out_hashtags: [][]const u8,
) Nip24Error!CommonTagInfo {
    std.debug.assert(out_reference_urls.len <= std.math.maxInt(u16));
    std.debug.assert(out_external_ids.len <= std.math.maxInt(u16));

    var info = CommonTagInfo{};
    for (tags) |tag| {
        try apply_common_tag(tag, &info, out_reference_urls, out_external_ids, out_hashtags);
    }
    return info;
}

/// Builds a generic NIP-24 `r` tag.
pub fn build_reference_tag(
    output: *BuiltTag,
    reference_url: []const u8,
) Nip24Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(reference_url.len <= limits.tag_item_bytes_max);

    output.items[0] = "r";
    output.items[1] = parse_url(reference_url) catch return error.InvalidReferenceTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a generic NIP-24 `title` tag.
pub fn build_title_tag(
    output: *BuiltTag,
    title: []const u8,
) Nip24Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(title.len <= limits.tag_item_bytes_max);

    output.items[0] = "title";
    output.items[1] = parse_nonempty_utf8(title) catch return error.InvalidTitleTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a generic NIP-24 lowercase `t` hashtag tag.
pub fn build_hashtag_tag(
    output: *BuiltTag,
    hashtag: []const u8,
) Nip24Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(hashtag.len <= limits.tag_item_bytes_max);

    output.items[0] = "t";
    output.items[1] = parse_hashtag_value(hashtag) catch return error.InvalidHashtagTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn parse_known_extra_field(
    extras: *MetadataExtras,
    key: []const u8,
    value: std.json.Value,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(extras) != 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (std.mem.eql(u8, key, "display_name")) {
        extras.display_name = parse_json_string_allow_empty(value) catch return error.InvalidDisplayName;
        return;
    }
    if (std.mem.eql(u8, key, "displayName")) {
        if (extras.display_name == null) {
            extras.display_name =
                parse_json_string_allow_empty(value) catch return error.InvalidDisplayName;
        }
        return;
    }
    if (std.mem.eql(u8, key, "website")) {
        const parsed = parse_json_string_allow_empty(value) catch return error.InvalidWebsite;
        extras.website = parse_url(parsed) catch return error.InvalidWebsite;
        return;
    }
    if (std.mem.eql(u8, key, "banner")) {
        const parsed = parse_json_string_allow_empty(value) catch return error.InvalidBanner;
        extras.banner = parse_url(parsed) catch return error.InvalidBanner;
        return;
    }
    if (std.mem.eql(u8, key, "bot")) {
        extras.bot = parse_json_bool(value) catch return error.InvalidBot;
        return;
    }
    if (std.mem.eql(u8, key, "birthday")) {
        extras.birthday = try parse_birthday(value);
    }
}

fn parse_json_string_allow_empty(value: std.json.Value) error{InvalidField}![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.content_bytes_max > 0);

    if (value != .string) return error.InvalidField;
    if (!std.unicode.utf8ValidateSlice(value.string)) return error.InvalidField;
    if (value.string.len > limits.content_bytes_max) return error.InvalidField;
    return value.string;
}

fn parse_json_bool(value: std.json.Value) error{InvalidField}!bool {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(bool) == 1);

    if (value != .bool) return error.InvalidField;
    return value.bool;
}

fn parse_birthday(value: std.json.Value) Nip24Error!?Birthday {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(Birthday) > 0);

    if (value != .object) return error.InvalidBirthday;

    var birthday = Birthday{};
    var iterator = value.object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const field = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "year")) {
            birthday.year = parse_birthday_year(field) catch return error.InvalidBirthday;
            continue;
        }
        if (std.mem.eql(u8, key, "month")) {
            birthday.month = parse_birthday_month(field) catch return error.InvalidBirthday;
            continue;
        }
        if (std.mem.eql(u8, key, "day")) {
            birthday.day = parse_birthday_day(field) catch return error.InvalidBirthday;
        }
    }
    return birthday;
}

fn parse_birthday_year(value: std.json.Value) error{InvalidField}!u16 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(u16) == 2);

    if (value != .integer) return error.InvalidField;
    if (value.integer <= 0) return error.InvalidField;
    return std.math.cast(u16, value.integer) orelse return error.InvalidField;
}

fn parse_birthday_month(value: std.json.Value) error{InvalidField}!u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(u8) == 1);

    if (value != .integer) return error.InvalidField;
    const parsed = std.math.cast(u8, value.integer) orelse return error.InvalidField;
    if (parsed < 1 or parsed > 12) return error.InvalidField;
    return parsed;
}

fn parse_birthday_day(value: std.json.Value) error{InvalidField}!u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(u8) == 1);

    if (value != .integer) return error.InvalidField;
    const parsed = std.math.cast(u8, value.integer) orelse return error.InvalidField;
    if (parsed < 1 or parsed > 31) return error.InvalidField;
    return parsed;
}

fn write_optional_string_field(
    writer: anytype,
    needs_comma: *bool,
    key: []const u8,
    value: ?[]const u8,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(needs_comma) != 0);
    std.debug.assert(key.len > 0);

    const text = value orelse return;
    try write_field_prefix(writer, needs_comma, key);
    try write_json_string(writer, text);
}

fn write_optional_bool_field(
    writer: anytype,
    needs_comma: *bool,
    key: []const u8,
    value: ?bool,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(needs_comma) != 0);
    std.debug.assert(key.len > 0);

    const parsed = value orelse return;
    try write_field_prefix(writer, needs_comma, key);
    writer.writeAll(if (parsed) "true" else "false") catch return error.BufferTooSmall;
}

fn write_optional_birthday_field(
    writer: anytype,
    needs_comma: *bool,
    key: []const u8,
    value: ?Birthday,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(needs_comma) != 0);
    std.debug.assert(key.len > 0);

    const birthday = value orelse return;
    try write_field_prefix(writer, needs_comma, key);
    writer.writeByte('{') catch return error.BufferTooSmall;

    var birthday_needs_comma = false;
    try write_optional_integer_field(writer, &birthday_needs_comma, "year", birthday.year);
    try write_optional_integer_field(writer, &birthday_needs_comma, "month", birthday.month);
    try write_optional_integer_field(writer, &birthday_needs_comma, "day", birthday.day);
    writer.writeByte('}') catch return error.BufferTooSmall;
}

fn write_optional_integer_field(
    writer: anytype,
    needs_comma: *bool,
    key: []const u8,
    value: anytype,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(needs_comma) != 0);
    std.debug.assert(key.len > 0);

    const parsed = value orelse return;
    try write_field_prefix(writer, needs_comma, key);
    writer.print("{d}", .{parsed}) catch return error.BufferTooSmall;
}

fn write_field_prefix(
    writer: anytype,
    needs_comma: *bool,
    key: []const u8,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(needs_comma) != 0);
    std.debug.assert(key.len > 0);

    if (needs_comma.*) {
        writer.writeByte(',') catch return error.BufferTooSmall;
    }
    try write_json_string(writer, key);
    writer.writeByte(':') catch return error.BufferTooSmall;
    needs_comma.* = true;
}

fn write_json_string(writer: anytype, text: []const u8) Nip24Error!void {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(@sizeOf(u8) == 1);

    writer.writeByte('"') catch return error.BufferTooSmall;
    for (text) |byte| {
        switch (byte) {
            '\\' => writer.writeAll("\\\\") catch return error.BufferTooSmall,
            '"' => writer.writeAll("\\\"") catch return error.BufferTooSmall,
            '\n' => writer.writeAll("\\n") catch return error.BufferTooSmall,
            '\r' => writer.writeAll("\\r") catch return error.BufferTooSmall,
            '\t' => writer.writeAll("\\t") catch return error.BufferTooSmall,
            0x08 => writer.writeAll("\\b") catch return error.BufferTooSmall,
            0x0C => writer.writeAll("\\f") catch return error.BufferTooSmall,
            0x00...0x07, 0x0B, 0x0E...0x1F => {
                writer.writeAll("\\u00") catch return error.BufferTooSmall;
                writer.print("{x:0>2}", .{byte}) catch return error.BufferTooSmall;
            },
            else => writer.writeByte(byte) catch return error.BufferTooSmall,
        }
    }
    writer.writeByte('"') catch return error.BufferTooSmall;
}

fn apply_common_tag(
    tag: nip01_event.EventTag,
    info: *CommonTagInfo,
    out_reference_urls: [][]const u8,
    out_external_ids: []nip73_external_ids.ExternalId,
    out_hashtags: [][]const u8,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_reference_urls.len <= std.math.maxInt(u16));

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "title")) return apply_title_tag(tag, info);
    if (std.mem.eql(u8, name, "r")) return apply_reference_tag(tag, info, out_reference_urls);
    if (std.mem.eql(u8, name, "i")) return apply_external_id_tag(tag, info, out_external_ids);
    if (std.mem.eql(u8, name, "t")) return apply_hashtag_tag(tag, info, out_hashtags);
}

fn apply_title_tag(tag: nip01_event.EventTag, info: *CommonTagInfo) Nip24Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (info.title != null) return error.DuplicateTitleTag;
    info.title = parse_single_utf8_value(tag) catch return error.InvalidTitleTag;
}

fn apply_reference_tag(
    tag: nip01_event.EventTag,
    info: *CommonTagInfo,
    out_reference_urls: [][]const u8,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_reference_urls.len <= std.math.maxInt(u16));

    const reference = parse_reference_value(tag) catch return error.InvalidReferenceTag;
    if (info.reference_count == out_reference_urls.len) return error.BufferTooSmall;
    out_reference_urls[info.reference_count] = reference;
    info.reference_count += 1;
}

fn apply_hashtag_tag(
    tag: nip01_event.EventTag,
    info: *CommonTagInfo,
    out_hashtags: [][]const u8,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_hashtags.len <= std.math.maxInt(u16));

    const hashtag = parse_hashtag_tag(tag) catch return error.InvalidHashtagTag;
    if (info.hashtag_count == out_hashtags.len) return error.BufferTooSmall;
    out_hashtags[info.hashtag_count] = hashtag;
    info.hashtag_count += 1;
}

fn apply_external_id_tag(
    tag: nip01_event.EventTag,
    info: *CommonTagInfo,
    out_external_ids: []nip73_external_ids.ExternalId,
) Nip24Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_external_ids.len <= std.math.maxInt(u16));

    const external_id = parse_external_id_tag(tag) catch return error.InvalidExternalIdTag;
    if (info.external_id_count == out_external_ids.len) return error.BufferTooSmall;
    out_external_ids[info.external_id_count] = external_id;
    info.external_id_count += 1;
}

fn parse_single_utf8_value(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTag;
}

fn parse_reference_value(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_url(tag.items[1]) catch return error.InvalidTag;
}

fn parse_hashtag_tag(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_hashtag_value(tag.items[1]) catch return error.InvalidTag;
}

fn parse_external_id_tag(
    tag: nip01_event.EventTag,
) error{InvalidTag}!nip73_external_ids.ExternalId {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len < 2) return error.InvalidTag;
    if (tag.items.len > 3) return error.InvalidTag;

    const hint = if (tag.items.len == 3) tag.items[2] else null;
    return nip73_external_ids.external_id_parse(tag.items[1], hint) catch return error.InvalidTag;
}

fn parse_hashtag_value(text: []const u8) error{InvalidTag}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    const parsed = parse_nonempty_utf8(text) catch return error.InvalidTag;
    if (has_ascii_whitespace(parsed)) return error.InvalidTag;
    if (has_ascii_uppercase(parsed)) return error.InvalidTag;
    return parsed;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    return url_with_host.parse(text, limits.content_bytes_max);
}

fn has_ascii_whitespace(text: []const u8) bool {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(@sizeOf(u8) == 1);

    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) return true;
    }
    return false;
}

fn has_ascii_uppercase(text: []const u8) bool {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(@sizeOf(u8) == 1);

    for (text) |byte| {
        if (std.ascii.isUpper(byte)) return true;
    }
    return false;
}

fn map_json_parse_error(parse_error: anyerror) Nip24Error {
    std.debug.assert(@typeInfo(@TypeOf(parse_error)) == .error_set);
    std.debug.assert(@typeInfo(Nip24Error) == .error_set);

    return switch (parse_error) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidJson,
    };
}

test "metadata extras parse supports canonical and deprecated display name input" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const canonical =
        \\{"display_name":"Display","website":"https://example.com","banner":"https://example.com/banner.png","bot":true,"birthday":{"year":1984,"month":1,"day":24}}
    ;
    const canonical_parsed = try metadata_extras_parse_json(canonical, arena.allocator());
    try std.testing.expectEqualStrings("Display", canonical_parsed.display_name.?);
    try std.testing.expectEqualStrings("https://example.com", canonical_parsed.website.?);
    try std.testing.expectEqualStrings(
        "https://example.com/banner.png",
        canonical_parsed.banner.?,
    );
    try std.testing.expectEqual(@as(?bool, true), canonical_parsed.bot);
    try std.testing.expectEqual(@as(?u16, 1984), canonical_parsed.birthday.?.year);
    try std.testing.expectEqual(@as(?u8, 1), canonical_parsed.birthday.?.month);
    try std.testing.expectEqual(@as(?u8, 24), canonical_parsed.birthday.?.day);

    const deprecated =
        \\{"displayName":"Compat","username":"ignored"}
    ;
    const deprecated_parsed = try metadata_extras_parse_json(deprecated, arena.allocator());
    try std.testing.expectEqualStrings("Compat", deprecated_parsed.display_name.?);
    try std.testing.expect(deprecated_parsed.website == null);
}

test "metadata extras parse rejects malformed fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const bad_website =
        \\{"website":"not-a-url"}
    ;
    const bad_banner =
        \\{"banner":false}
    ;
    const bad_bot =
        \\{"bot":"true"}
    ;
    const bad_birthday =
        \\{"birthday":{"month":13}}
    ;

    try std.testing.expectError(
        error.InvalidWebsite,
        metadata_extras_parse_json(bad_website, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidBanner,
        metadata_extras_parse_json(bad_banner, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidBot,
        metadata_extras_parse_json(bad_bot, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidBirthday,
        metadata_extras_parse_json(bad_birthday, arena.allocator()),
    );
}

test "metadata extras serialize is deterministic and omits absent fields" {
    var output: [256]u8 = undefined;
    const extras = MetadataExtras{
        .display_name = "Display",
        .website = "https://example.com",
        .bot = false,
        .birthday = .{ .month = 5 },
    };

    const serialized = try metadata_extras_serialize_json(output[0..], &extras);

    try std.testing.expectEqualStrings(
        "{\"display_name\":\"Display\",\"website\":\"https://example.com\",\"bot\":false,\"birthday\":{\"month\":5}}",
        serialized,
    );
}

test "metadata extras serialize escapes JSON string content" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var output: [256]u8 = undefined;
    const extras = MetadataExtras{
        .display_name = "A\"B\\C\nD",
    };

    const serialized = try metadata_extras_serialize_json(output[0..], &extras);
    try std.testing.expectEqualStrings(
        "{\"display_name\":\"A\\\"B\\\\C\\nD\"}",
        serialized,
    );

    const reparsed = try metadata_extras_parse_json(serialized, arena.allocator());
    try std.testing.expectEqualStrings("A\"B\\C\nD", reparsed.display_name.?);
}

test "common tags extract parses title references and hashtags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "title", "Article title" } },
        .{ .items = &.{ "r", "https://example.com/post" } },
        .{ .items = &.{ "t", "nostr" } },
        .{ .items = &.{ "p", "ignored" } },
    };
    var references: [1][]const u8 = undefined;
    var hashtags: [1][]const u8 = undefined;

    const parsed = try common_tags_extract(tags[0..], references[0..], hashtags[0..]);

    try std.testing.expectEqualStrings("Article title", parsed.title.?);
    try std.testing.expectEqual(@as(u16, 1), parsed.reference_count);
    try std.testing.expectEqual(@as(u16, 1), parsed.hashtag_count);
    try std.testing.expectEqualStrings("https://example.com/post", references[0]);
    try std.testing.expectEqualStrings("nostr", hashtags[0]);
}

test "common tags extract with external ids parses generic i tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "title", "Article title" } },
        .{ .items = &.{ "i", "podcast:guid:feed-guid", "https://fountain.fm/show/1" } },
        .{ .items = &.{ "r", "https://example.com/post" } },
        .{ .items = &.{ "t", "nostr" } },
    };
    var references: [1][]const u8 = undefined;
    var external_ids: [1]nip73_external_ids.ExternalId = undefined;
    var hashtags: [1][]const u8 = undefined;

    const parsed = try common_tags_extract_with_external_ids(
        tags[0..],
        references[0..],
        external_ids[0..],
        hashtags[0..],
    );

    try std.testing.expectEqual(@as(u16, 1), parsed.external_id_count);
    try std.testing.expect(external_ids[0].kind == .podcast_feed);
    try std.testing.expectEqualStrings("podcast:guid:feed-guid", external_ids[0].value);
    try std.testing.expectEqualStrings("https://fountain.fm/show/1", external_ids[0].hint.?);
}

test "common tags extract rejects malformed supported tags and duplicate titles" {
    const duplicate_title = [_]nip01_event.EventTag{
        .{ .items = &.{ "title", "A" } },
        .{ .items = &.{ "title", "B" } },
    };
    const bad_reference = [_]nip01_event.EventTag{.{ .items = &.{ "r", "not-a-url" } }};
    const bad_external_id = [_]nip01_event.EventTag{.{ .items = &.{ "i", "bad-external-id" } }};
    const bad_hashtag = [_]nip01_event.EventTag{.{ .items = &.{ "t", "bad tag" } }};
    const uppercase_hashtag = [_]nip01_event.EventTag{.{ .items = &.{ "t", "Nostr" } }};
    var references: [1][]const u8 = undefined;
    var external_ids: [1]nip73_external_ids.ExternalId = undefined;
    var hashtags: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.DuplicateTitleTag,
        common_tags_extract(duplicate_title[0..], references[0..], hashtags[0..]),
    );
    try std.testing.expectError(
        error.InvalidReferenceTag,
        common_tags_extract(bad_reference[0..], references[0..], hashtags[0..]),
    );
    try std.testing.expectError(
        error.InvalidExternalIdTag,
        common_tags_extract_with_external_ids(
            bad_external_id[0..],
            references[0..],
            external_ids[0..],
            hashtags[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidHashtagTag,
        common_tags_extract(bad_hashtag[0..], references[0..], hashtags[0..]),
    );
    try std.testing.expectError(
        error.InvalidHashtagTag,
        common_tags_extract(uppercase_hashtag[0..], references[0..], hashtags[0..]),
    );
}

test "builders emit canonical generic tags" {
    var reference_tag: BuiltTag = .{};
    var title_tag: BuiltTag = .{};
    var hashtag_tag: BuiltTag = .{};

    try std.testing.expectEqualStrings(
        "r",
        (try build_reference_tag(&reference_tag, "https://example.com/post")).items[0],
    );
    try std.testing.expectEqualStrings(
        "title",
        (try build_title_tag(&title_tag, "Title")).items[0],
    );
    const built_hashtag = try build_hashtag_tag(&hashtag_tag, "nostr");
    try std.testing.expectEqualStrings("t", built_hashtag.items[0]);

    try std.testing.expectError(
        error.InvalidHashtagTag,
        build_hashtag_tag(&hashtag_tag, "Nostr"),
    );
}
