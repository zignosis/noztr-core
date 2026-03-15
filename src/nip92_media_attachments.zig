const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip94_file_metadata = @import("nip94_file_metadata.zig");

pub const Nip92Error = error{
    InvalidImetaTag,
    MissingUrlField,
    MissingMetadataField,
    DuplicateUrlField,
    DuplicateMimeTypeField,
    DuplicateHashField,
    DuplicateOriginalHashField,
    DuplicateSizeField,
    DuplicateDimensionsField,
    DuplicateMagnetField,
    DuplicateInfohashField,
    DuplicateBlurhashField,
    DuplicateThumbField,
    DuplicateImageField,
    DuplicateSummaryField,
    DuplicateAltField,
    DuplicateServiceField,
    InvalidUrlField,
    InvalidMimeTypeField,
    InvalidHashField,
    InvalidOriginalHashField,
    InvalidSizeField,
    InvalidDimensionsField,
    InvalidMagnetField,
    InvalidInfohashField,
    InvalidBlurhashField,
    InvalidThumbField,
    InvalidImageField,
    InvalidSummaryField,
    InvalidAltField,
    InvalidFallbackField,
    InvalidServiceField,
    BufferTooSmall,
};

pub const Dimensions = nip94_file_metadata.Dimensions;

pub const ImetaInfo = struct {
    url: []const u8,
    mime_type: ?[]const u8 = null,
    sha256: ?[32]u8 = null,
    original_sha256: ?[32]u8 = null,
    size: ?u64 = null,
    dimensions: ?Dimensions = null,
    magnet: ?[]const u8 = null,
    infohash: ?[]const u8 = null,
    blurhash: ?[]const u8 = null,
    thumb_url: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    service: ?[]const u8 = null,
    fallback_count: u16 = 0,
};

pub const BuiltField = struct {
    storage: [limits.tag_item_bytes_max]u8 = undefined,
};

pub const BuiltTag = struct {
    items: [limits.tag_items_max][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

const ParseState = struct {
    saw_url: bool = false,
    saw_mime: bool = false,
    saw_hash: bool = false,
    saw_original_hash: bool = false,
    saw_size: bool = false,
    saw_dimensions: bool = false,
    saw_magnet: bool = false,
    saw_infohash: bool = false,
    saw_blurhash: bool = false,
    saw_thumb: bool = false,
    saw_image: bool = false,
    saw_summary: bool = false,
    saw_alt: bool = false,
    saw_service: bool = false,
    saw_supported_metadata: bool = false,
};

/// Extracts bounded NIP-92 inline media metadata from one `imeta` tag.
pub fn imeta_extract(
    tag: nip01_event.EventTag,
    out_fallback_urls: [][]const u8,
) Nip92Error!ImetaInfo {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out_fallback_urls.len <= limits.tags_max);

    if (tag.items.len < 2) return error.InvalidImetaTag;
    if (!std.mem.eql(u8, tag.items[0], "imeta")) return error.InvalidImetaTag;

    var info = ImetaInfo{ .url = undefined };
    var state = ParseState{};
    for (tag.items[1..]) |field_text| {
        try apply_field_text(field_text, &state, &info, out_fallback_urls);
    }
    if (!state.saw_url) return error.MissingUrlField;
    if (!state.saw_supported_metadata) return error.MissingMetadataField;
    return info;
}

/// Returns whether the inline-media URL appears verbatim in the event content.
pub fn imeta_matches_content(content: []const u8, info: *const ImetaInfo) bool {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(info) != 0);

    return imeta_url_matches_content(content, info.url);
}

/// Returns whether a URL appears verbatim in event content.
pub fn imeta_url_matches_content(content: []const u8, url: []const u8) bool {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(url.len <= limits.tag_item_bytes_max);

    var offset: usize = 0;
    while (std.mem.indexOfPos(u8, content, offset, url)) |index| {
        const before_ok = index == 0 or is_content_url_boundary(content[index - 1], .before);
        const after_index = index + url.len;
        const after_ok = after_index == content.len or
            is_content_url_boundary(content[after_index], .after);
        if (before_ok and after_ok) return true;
        offset = index + 1;
    }
    return false;
}

const BoundarySide = enum { before, after };

fn is_content_url_boundary(byte: u8, side: BoundarySide) bool {
    std.debug.assert(byte <= 0x7f);
    std.debug.assert(@sizeOf(BoundarySide) > 0);

    if (std.ascii.isWhitespace(byte)) return true;
    if (byte == '<' or byte == '>' or byte == '"' or byte == '\'') return true;
    if (side == .before) {
        return byte == '(' or byte == '[' or byte == '{';
    }
    return byte == ')' or byte == ']' or byte == '}' or byte == ',' or byte == '.';
}

/// Builds one canonical `imeta` field item such as `url https://...` or `m image/jpeg`.
pub fn imeta_build_field(
    output: *BuiltField,
    name: []const u8,
    value: []const u8,
) Nip92Error![]const u8 {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(name.len < limits.tag_item_bytes_max);

    try validate_field(name, value);
    return std.fmt.bufPrint(output.storage[0..], "{s} {s}", .{ name, value }) catch {
        return error.BufferTooSmall;
    };
}

/// Builds one canonical `imeta` tag from caller-owned field items.
pub fn imeta_build_tag(
    output: *BuiltTag,
    fields: []const []const u8,
) Nip92Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(fields.len + 1 <= limits.tag_items_max);

    if (fields.len == 0) return error.MissingUrlField;
    output.items[0] = "imeta";
    output.item_count = 1;

    var state = ParseState{};
    for (fields, 0..) |field_text, index| {
        output.items[index + 1] = field_text;
        output.item_count += 1;
        try apply_field_text(field_text, &state, null, &.{});
    }
    if (!state.saw_url) return error.MissingUrlField;
    if (!state.saw_supported_metadata) return error.MissingMetadataField;
    return output.as_event_tag();
}

fn apply_field_text(
    field_text: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
    out_fallback_urls: [][]const u8,
) Nip92Error!void {
    std.debug.assert(field_text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@intFromPtr(state) != 0);

    const separator = std.mem.indexOfScalar(u8, field_text, ' ') orelse return error.InvalidImetaTag;
    if (separator == 0 or separator + 1 >= field_text.len) return error.InvalidImetaTag;

    const name = field_text[0..separator];
    const value = field_text[separator + 1 ..];
    try apply_field(name, value, state, info, out_fallback_urls);
}

fn apply_field(
    name: []const u8,
    value: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
    out_fallback_urls: [][]const u8,
) Nip92Error!void {
    std.debug.assert(name.len <= limits.tag_item_bytes_max);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (std.mem.eql(u8, name, "url")) return parse_url_field(value, state, info);
    if (std.mem.eql(u8, name, "m")) return parse_mime_type_field(value, state, info);
    if (std.mem.eql(u8, name, "x")) return parse_hash_field(value, state, info);
    if (std.mem.eql(u8, name, "ox")) return parse_original_hash_field(value, state, info);
    if (std.mem.eql(u8, name, "size")) return parse_size_field(value, state, info);
    if (std.mem.eql(u8, name, "dim")) return parse_dimensions_field(value, state, info);
    if (std.mem.eql(u8, name, "magnet")) return parse_magnet_field(value, state, info);
    if (std.mem.eql(u8, name, "i")) return parse_infohash_field(value, state, info);
    if (std.mem.eql(u8, name, "blurhash")) return parse_blurhash_field(value, state, info);
    if (std.mem.eql(u8, name, "thumb")) return parse_thumb_field(value, state, info);
    if (std.mem.eql(u8, name, "image")) return parse_image_field(value, state, info);
    if (std.mem.eql(u8, name, "summary")) return parse_summary_field(value, state, info);
    if (std.mem.eql(u8, name, "alt")) return parse_alt_field(value, state, info);
    if (std.mem.eql(u8, name, "fallback")) {
        return parse_fallback_field(value, state, info, out_fallback_urls);
    }
    if (std.mem.eql(u8, name, "service")) return parse_service_field(value, state, info);
}

fn parse_url_field(value: []const u8, state: *ParseState, info: ?*ImetaInfo) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_url) return error.DuplicateUrlField;
    const parsed = parse_url(value) catch return error.InvalidUrlField;
    state.saw_url = true;
    if (info) |output| output.url = parsed;
}

fn parse_mime_type_field(
    value: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_mime) return error.DuplicateMimeTypeField;
    const parsed = parse_mime_type(value) catch return error.InvalidMimeTypeField;
    state.saw_mime = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.mime_type = parsed;
}

fn parse_hash_field(value: []const u8, state: *ParseState, info: ?*ImetaInfo) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_hash) return error.DuplicateHashField;
    const parsed = parse_lower_hex_32(value) catch return error.InvalidHashField;
    state.saw_hash = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.sha256 = parsed;
}

fn parse_original_hash_field(
    value: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_original_hash) return error.DuplicateOriginalHashField;
    const parsed = parse_lower_hex_32(value) catch return error.InvalidOriginalHashField;
    state.saw_original_hash = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.original_sha256 = parsed;
}

fn parse_size_field(value: []const u8, state: *ParseState, info: ?*ImetaInfo) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_size) return error.DuplicateSizeField;
    const parsed = parse_decimal_u64(value) catch return error.InvalidSizeField;
    state.saw_size = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.size = parsed;
}

fn parse_dimensions_field(
    value: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_dimensions) return error.DuplicateDimensionsField;
    const parsed = parse_dimensions(value) catch return error.InvalidDimensionsField;
    state.saw_dimensions = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.dimensions = parsed;
}

fn parse_magnet_field(value: []const u8, state: *ParseState, info: ?*ImetaInfo) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_magnet) return error.DuplicateMagnetField;
    const parsed = parse_nonempty_utf8(value) catch return error.InvalidMagnetField;
    state.saw_magnet = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.magnet = parsed;
}

fn parse_infohash_field(
    value: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_infohash) return error.DuplicateInfohashField;
    const parsed = parse_nonempty_utf8(value) catch return error.InvalidInfohashField;
    state.saw_infohash = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.infohash = parsed;
}

fn parse_blurhash_field(
    value: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_blurhash) return error.DuplicateBlurhashField;
    const parsed = parse_nonempty_utf8(value) catch return error.InvalidBlurhashField;
    state.saw_blurhash = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.blurhash = parsed;
}

fn parse_thumb_field(value: []const u8, state: *ParseState, info: ?*ImetaInfo) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_thumb) return error.DuplicateThumbField;
    const parsed = parse_url(value) catch return error.InvalidThumbField;
    state.saw_thumb = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.thumb_url = parsed;
}

fn parse_image_field(value: []const u8, state: *ParseState, info: ?*ImetaInfo) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_image) return error.DuplicateImageField;
    const parsed = parse_url(value) catch return error.InvalidImageField;
    state.saw_image = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.image_url = parsed;
}

fn parse_summary_field(value: []const u8, state: *ParseState, info: ?*ImetaInfo) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_summary) return error.DuplicateSummaryField;
    const parsed = parse_nonempty_utf8(value) catch return error.InvalidSummaryField;
    state.saw_summary = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.summary = parsed;
}

fn parse_alt_field(value: []const u8, state: *ParseState, info: ?*ImetaInfo) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_alt) return error.DuplicateAltField;
    const parsed = parse_nonempty_utf8(value) catch return error.InvalidAltField;
    state.saw_alt = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.alt = parsed;
}

fn parse_fallback_field(
    value: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
    out_fallback_urls: [][]const u8,
) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    const parsed = parse_url(value) catch return error.InvalidFallbackField;
    state.saw_supported_metadata = true;
    if (info) |output| {
        if (output.fallback_count >= out_fallback_urls.len) return error.BufferTooSmall;
        out_fallback_urls[output.fallback_count] = parsed;
        output.fallback_count += 1;
    }
}

fn parse_service_field(
    value: []const u8,
    state: *ParseState,
    info: ?*ImetaInfo,
) Nip92Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (state.saw_service) return error.DuplicateServiceField;
    const parsed = parse_nonempty_utf8(value) catch return error.InvalidServiceField;
    state.saw_service = true;
    state.saw_supported_metadata = true;
    if (info) |output| output.service = parsed;
}

fn validate_field(name: []const u8, value: []const u8) Nip92Error!void {
    std.debug.assert(name.len <= limits.tag_item_bytes_max);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    if (!is_supported_field_name(name)) return error.InvalidImetaTag;
    var state = ParseState{};
    try apply_field(name, value, &state, null, &.{});
}

fn is_supported_field_name(name: []const u8) bool {
    std.debug.assert(name.len <= limits.tag_item_bytes_max);
    std.debug.assert(name.len <= limits.content_bytes_max);

    if (std.mem.eql(u8, name, "url")) return true;
    if (std.mem.eql(u8, name, "m")) return true;
    if (std.mem.eql(u8, name, "x")) return true;
    if (std.mem.eql(u8, name, "ox")) return true;
    if (std.mem.eql(u8, name, "size")) return true;
    if (std.mem.eql(u8, name, "dim")) return true;
    if (std.mem.eql(u8, name, "magnet")) return true;
    if (std.mem.eql(u8, name, "i")) return true;
    if (std.mem.eql(u8, name, "blurhash")) return true;
    if (std.mem.eql(u8, name, "thumb")) return true;
    if (std.mem.eql(u8, name, "image")) return true;
    if (std.mem.eql(u8, name, "summary")) return true;
    if (std.mem.eql(u8, name, "alt")) return true;
    if (std.mem.eql(u8, name, "fallback")) return true;
    return std.mem.eql(u8, name, "service");
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
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_mime_type(text: []const u8) error{InvalidMimeType}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len < 3) return error.InvalidMimeType;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidMimeType;

    const slash = std.mem.indexOfScalar(u8, text, '/') orelse return error.InvalidMimeType;
    if (slash == 0 or slash + 1 >= text.len) return error.InvalidMimeType;
    if (std.mem.indexOfScalarPos(u8, text, slash + 1, '/')) |_| return error.InvalidMimeType;
    if (!is_mime_token(text[0..slash])) return error.InvalidMimeType;
    if (!is_mime_token(text[slash + 1 ..])) return error.InvalidMimeType;
    return text;
}

fn is_mime_token(text: []const u8) bool {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return false;
    for (text) |byte| {
        if (std.ascii.isUpper(byte)) return false;
        if (std.ascii.isLower(byte) or std.ascii.isDigit(byte)) continue;
        if (byte == '!' or byte == '#' or byte == '$') continue;
        if (byte == '&' or byte == '-' or byte == '^') continue;
        if (byte == '_' or byte == '.' or byte == '+') continue;
        if (byte == '\'' or byte == '*' or byte == '`') continue;
        if (byte == '|' or byte == '~') continue;
        return false;
    }
    return true;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    var output: [32]u8 = undefined;
    if (text.len != 64) return error.InvalidHex;
    _ = std.fmt.hexToBytes(output[0..], text) catch return error.InvalidHex;
    for (text) |byte| {
        if (!std.ascii.isHex(byte)) return error.InvalidHex;
        if (std.ascii.isUpper(byte)) return error.InvalidHex;
    }
    return output;
}

fn parse_decimal_u64(text: []const u8) error{InvalidNumber}!u64 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidNumber;
    return std.fmt.parseInt(u64, text, 10) catch return error.InvalidNumber;
}

fn parse_dimensions(text: []const u8) error{InvalidDimensions}!Dimensions {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    const separator = std.mem.indexOfScalar(u8, text, 'x') orelse return error.InvalidDimensions;
    if (separator == 0 or separator + 1 >= text.len) return error.InvalidDimensions;

    const width = parse_decimal_u32(text[0..separator]) catch return error.InvalidDimensions;
    const height = parse_decimal_u32(text[separator + 1 ..]) catch return error.InvalidDimensions;
    if (width == 0 or height == 0) return error.InvalidDimensions;
    return .{ .width = width, .height = height };
}

fn parse_decimal_u32(text: []const u8) error{InvalidNumber}!u32 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidNumber;
    return std.fmt.parseInt(u32, text, 10) catch return error.InvalidNumber;
}

test "imeta extract parses bounded supported fields" {
    const tag = nip01_event.EventTag{
        .items = &.{
            "imeta",
            "url https://example.com/cat.jpg",
            "m image/jpeg",
            "x aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "dim 640x480",
            "alt cat on a wall",
            "fallback https://backup.example/cat.jpg",
            "fallback https://backup2.example/cat.jpg",
            "unknown ignored",
        },
    };
    var fallbacks: [2][]const u8 = undefined;

    const parsed = try imeta_extract(tag, fallbacks[0..]);

    try std.testing.expectEqualStrings("https://example.com/cat.jpg", parsed.url);
    try std.testing.expectEqualStrings("image/jpeg", parsed.mime_type.?);
    try std.testing.expectEqual(@as(u32, 640), parsed.dimensions.?.width);
    try std.testing.expectEqual(@as(u16, 2), parsed.fallback_count);
    try std.testing.expectEqualStrings("https://backup.example/cat.jpg", fallbacks[0]);
    try std.testing.expectEqualStrings("cat on a wall", parsed.alt.?);
}

test "imeta extract rejects malformed or incomplete tags" {
    var fallbacks: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.MissingMetadataField,
        imeta_extract(.{ .items = &.{ "imeta", "url https://example.com/cat.jpg" } }, fallbacks[0..]),
    );
    try std.testing.expectError(
        error.InvalidMimeTypeField,
        imeta_extract(
            .{
                .items = &.{
                    "imeta",
                    "url https://example.com/cat.jpg",
                    "m Image/JPEG",
                },
            },
            fallbacks[0..],
        ),
    );
    try std.testing.expectError(
        error.DuplicateUrlField,
        imeta_extract(
            .{
                .items = &.{
                    "imeta",
                    "url https://example.com/cat.jpg",
                    "url https://example.com/other.jpg",
                    "x aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                },
            },
            fallbacks[0..],
        ),
    );
}

test "imeta builders create canonical fields and tags" {
    var url_field: BuiltField = .{};
    var mime_field: BuiltField = .{};
    var hash_field: BuiltField = .{};
    var built_tag: BuiltTag = .{};

    const url = try imeta_build_field(&url_field, "url", "https://example.com/cat.jpg");
    const mime = try imeta_build_field(&mime_field, "m", "image/jpeg");
    const hash = try imeta_build_field(
        &hash_field,
        "x",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    const built = try imeta_build_tag(&built_tag, &.{ url, mime, hash });

    try std.testing.expectEqualStrings("imeta", built.items[0]);
    try std.testing.expectEqualStrings("url https://example.com/cat.jpg", built.items[1]);
    try std.testing.expectEqualStrings("m image/jpeg", built.items[2]);
    try std.testing.expectEqualStrings(
        "x aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        built.items[3],
    );

    try std.testing.expectError(
        error.InvalidImetaTag,
        imeta_build_field(&url_field, "unknown", "value"),
    );
}

test "imeta content match checks exact url presence" {
    const info = ImetaInfo{ .url = "https://example.com/cat.jpg" };

    try std.testing.expect(imeta_matches_content("see https://example.com/cat.jpg now", &info));
    try std.testing.expect(imeta_matches_content("(https://example.com/cat.jpg)", &info));
    try std.testing.expect(!imeta_matches_content("see https://example.com/dog.jpg now", &info));
    try std.testing.expect(
        !imeta_matches_content("see https://example.com/cat.jpg?size=1 now", &info),
    );
}
