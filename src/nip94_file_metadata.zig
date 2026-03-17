const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const file_metadata_kind: u32 = 1063;

pub const Nip94Error = error{
    InvalidFileMetadataKind,
    MissingUrlTag,
    MissingMimeTypeTag,
    MissingHashTag,
    DuplicateUrlTag,
    DuplicateMimeTypeTag,
    DuplicateHashTag,
    DuplicateOriginalHashTag,
    DuplicateSizeTag,
    DuplicateDimensionsTag,
    DuplicateMagnetTag,
    DuplicateInfohashTag,
    DuplicateBlurhashTag,
    DuplicateThumbTag,
    DuplicateImageTag,
    DuplicateSummaryTag,
    DuplicateAltTag,
    DuplicateServiceTag,
    InvalidUrlTag,
    InvalidMimeTypeTag,
    InvalidHashTag,
    InvalidOriginalHashTag,
    InvalidSizeTag,
    InvalidDimensionsTag,
    InvalidMagnetTag,
    InvalidInfohashTag,
    InvalidBlurhashTag,
    InvalidThumbTag,
    InvalidImageTag,
    InvalidSummaryTag,
    InvalidAltTag,
    InvalidFallbackTag,
    InvalidServiceTag,
    BufferTooSmall,
};

pub const Dimensions = struct {
    width: u32,
    height: u32,
};

pub const ImageReference = struct {
    url: []const u8,
    sha256: ?[32]u8 = null,
};

pub const FileMetadataInfo = struct {
    url: []const u8,
    mime_type: []const u8,
    sha256: [32]u8,
    original_sha256: ?[32]u8 = null,
    size: ?u64 = null,
    dimensions: ?Dimensions = null,
    magnet: ?[]const u8 = null,
    infohash: ?[]const u8 = null,
    blurhash: ?[]const u8 = null,
    thumb: ?ImageReference = null,
    image: ?ImageReference = null,
    summary: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    service: ?[]const u8 = null,
    fallback_count: u16 = 0,
    caption: []const u8,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    text_storage: [2][32]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded NIP-94 file metadata from a kind-1063 event.
///
/// Lifetime and ownership:
/// - all returned text fields borrow from the input event storage
/// - keep the event alive while using borrowed fields
pub fn file_metadata_extract(
    event: *const nip01_event.Event,
    out_fallback_urls: [][]const u8,
) Nip94Error!FileMetadataInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_fallback_urls.len <= limits.tags_max);

    if (event.kind != file_metadata_kind) return error.InvalidFileMetadataKind;

    var info = FileMetadataInfo{
        .url = undefined,
        .mime_type = undefined,
        .sha256 = undefined,
        .caption = event.content,
    };
    var state = ParseState{};
    for (event.tags) |tag| {
        try apply_tag(tag, &state, &info, out_fallback_urls);
    }
    try require_required_tags(&state, &info);
    return info;
}

/// Builds a canonical `url` tag.
pub fn file_metadata_build_url_tag(
    output: *BuiltTag,
    url: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(url.len <= std.math.maxInt(usize));

    output.items[0] = "url";
    output.items[1] = parse_url(url) catch return error.InvalidUrlTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `m` mime-type tag.
pub fn file_metadata_build_mime_type_tag(
    output: *BuiltTag,
    mime_type: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(mime_type.len <= std.math.maxInt(usize));

    output.items[0] = "m";
    output.items[1] = parse_mime_type(mime_type) catch return error.InvalidMimeTypeTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `x` sha256 tag.
pub fn file_metadata_build_hash_tag(
    output: *BuiltTag,
    sha256_hex: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(sha256_hex.len <= std.math.maxInt(usize));

    _ = parse_lower_hex_32(sha256_hex) catch return error.InvalidHashTag;
    output.items[0] = "x";
    output.items[1] = sha256_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `ox` sha256 tag.
pub fn file_metadata_build_original_hash_tag(
    output: *BuiltTag,
    sha256_hex: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(sha256_hex.len <= std.math.maxInt(usize));

    _ = parse_lower_hex_32(sha256_hex) catch return error.InvalidOriginalHashTag;
    output.items[0] = "ox";
    output.items[1] = sha256_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `size` tag.
pub fn file_metadata_build_size_tag(
    output: *BuiltTag,
    size: u64,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(size <= std.math.maxInt(u64));

    output.items[0] = "size";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0][0..], "{}", .{size}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `dim` tag.
pub fn file_metadata_build_dimensions_tag(
    output: *BuiltTag,
    dimensions: Dimensions,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    if (dimensions.width == 0) return error.InvalidDimensionsTag;
    if (dimensions.height == 0) return error.InvalidDimensionsTag;
    output.items[0] = "dim";
    output.items[1] = std.fmt.bufPrint(
        output.text_storage[0][0..],
        "{}x{}",
        .{ dimensions.width, dimensions.height },
    ) catch return error.BufferTooSmall;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `magnet` tag.
pub fn file_metadata_build_magnet_tag(
    output: *BuiltTag,
    magnet_uri: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(magnet_uri.len <= std.math.maxInt(usize));

    output.items[0] = "magnet";
    output.items[1] = parse_nonempty_utf8(magnet_uri) catch return error.InvalidMagnetTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `i` infohash tag.
pub fn file_metadata_build_infohash_tag(
    output: *BuiltTag,
    infohash: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(infohash.len <= std.math.maxInt(usize));

    output.items[0] = "i";
    output.items[1] = parse_nonempty_utf8(infohash) catch return error.InvalidInfohashTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `blurhash` tag.
pub fn file_metadata_build_blurhash_tag(
    output: *BuiltTag,
    blurhash: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(blurhash.len <= std.math.maxInt(usize));

    output.items[0] = "blurhash";
    output.items[1] = parse_nonempty_utf8(blurhash) catch return error.InvalidBlurhashTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `thumb` tag with optional sha256.
pub fn file_metadata_build_thumb_tag(
    output: *BuiltTag,
    url: []const u8,
    sha256_hex: ?[]const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(url.len <= std.math.maxInt(usize));

    output.items[0] = "thumb";
    output.items[1] = parse_url(url) catch return error.InvalidThumbTag;
    output.item_count = 2;
    if (sha256_hex) |value| {
        _ = parse_lower_hex_32(value) catch return error.InvalidThumbTag;
        output.items[2] = value;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical `image` tag with optional sha256.
pub fn file_metadata_build_image_tag(
    output: *BuiltTag,
    url: []const u8,
    sha256_hex: ?[]const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(url.len <= std.math.maxInt(usize));

    output.items[0] = "image";
    output.items[1] = parse_url(url) catch return error.InvalidImageTag;
    output.item_count = 2;
    if (sha256_hex) |value| {
        _ = parse_lower_hex_32(value) catch return error.InvalidImageTag;
        output.items[2] = value;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical `summary` tag.
pub fn file_metadata_build_summary_tag(
    output: *BuiltTag,
    summary: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(summary.len <= std.math.maxInt(usize));

    output.items[0] = "summary";
    output.items[1] = parse_nonempty_utf8(summary) catch return error.InvalidSummaryTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `alt` tag.
pub fn file_metadata_build_alt_tag(
    output: *BuiltTag,
    alt: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(alt.len <= std.math.maxInt(usize));

    output.items[0] = "alt";
    output.items[1] = parse_nonempty_utf8(alt) catch return error.InvalidAltTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `fallback` tag.
pub fn file_metadata_build_fallback_tag(
    output: *BuiltTag,
    url: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(url.len <= std.math.maxInt(usize));

    output.items[0] = "fallback";
    output.items[1] = parse_url(url) catch return error.InvalidFallbackTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `service` tag.
pub fn file_metadata_build_service_tag(
    output: *BuiltTag,
    service: []const u8,
) Nip94Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(service.len <= std.math.maxInt(usize));

    output.items[0] = "service";
    output.items[1] = parse_nonempty_utf8(service) catch return error.InvalidServiceTag;
    output.item_count = 2;
    return output.as_event_tag();
}

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
};

fn apply_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
    out_fallback_urls: [][]const u8,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;

    const name = tag.items[0];
    if (std.mem.eql(u8, name, "url")) return parse_url_tag(tag, state, info);
    if (std.mem.eql(u8, name, "m")) return parse_mime_type_tag(tag, state, info);
    if (std.mem.eql(u8, name, "x")) return parse_hash_tag(tag, state, info);
    if (std.mem.eql(u8, name, "ox")) return parse_original_hash_tag(tag, state, info);
    if (std.mem.eql(u8, name, "size")) return parse_size_tag(tag, state, info);
    if (std.mem.eql(u8, name, "dim")) return parse_dimensions_tag(tag, state, info);
    if (std.mem.eql(u8, name, "magnet")) return parse_magnet_tag(tag, state, info);
    if (std.mem.eql(u8, name, "i")) return parse_infohash_tag(tag, state, info);
    if (std.mem.eql(u8, name, "blurhash")) return parse_blurhash_tag(tag, state, info);
    if (std.mem.eql(u8, name, "thumb")) return parse_thumb_tag(tag, state, info);
    if (std.mem.eql(u8, name, "image")) return parse_image_tag(tag, state, info);
    if (std.mem.eql(u8, name, "summary")) return parse_summary_tag(tag, state, info);
    if (std.mem.eql(u8, name, "alt")) return parse_alt_tag(tag, state, info);
    if (std.mem.eql(u8, name, "fallback")) return parse_fallback_tag(tag, info, out_fallback_urls);
    if (std.mem.eql(u8, name, "service")) return parse_service_tag(tag, state, info);
}

fn parse_url_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_url) return error.DuplicateUrlTag;
    info.url = try parse_required_url_item(tag, error.InvalidUrlTag);
    state.saw_url = true;
}

fn parse_mime_type_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_mime) return error.DuplicateMimeTypeTag;
    info.mime_type = try parse_required_mime_type_item(tag, error.InvalidMimeTypeTag);
    state.saw_mime = true;
}

fn parse_hash_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_hash) return error.DuplicateHashTag;
    info.sha256 = try parse_required_hash_item(tag, error.InvalidHashTag);
    state.saw_hash = true;
}

fn parse_original_hash_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_original_hash) return error.DuplicateOriginalHashTag;
    info.original_sha256 = try parse_required_hash_item(tag, error.InvalidOriginalHashTag);
    state.saw_original_hash = true;
}

fn parse_size_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_size) return error.DuplicateSizeTag;
    info.size = try parse_required_u64_item(tag, error.InvalidSizeTag);
    state.saw_size = true;
}

fn parse_dimensions_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_dimensions) return error.DuplicateDimensionsTag;
    info.dimensions = try parse_required_dimensions_item(tag, error.InvalidDimensionsTag);
    state.saw_dimensions = true;
}

fn parse_magnet_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_magnet) return error.DuplicateMagnetTag;
    info.magnet = try parse_required_text_item(tag, error.InvalidMagnetTag);
    state.saw_magnet = true;
}

fn parse_infohash_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_infohash) return error.DuplicateInfohashTag;
    info.infohash = try parse_required_text_item(tag, error.InvalidInfohashTag);
    state.saw_infohash = true;
}

fn parse_blurhash_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_blurhash) return error.DuplicateBlurhashTag;
    info.blurhash = try parse_required_text_item(tag, error.InvalidBlurhashTag);
    state.saw_blurhash = true;
}

fn parse_thumb_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_thumb) return error.DuplicateThumbTag;
    info.thumb = try parse_image_reference(tag, error.InvalidThumbTag);
    state.saw_thumb = true;
}

fn parse_image_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_image) return error.DuplicateImageTag;
    info.image = try parse_image_reference(tag, error.InvalidImageTag);
    state.saw_image = true;
}

fn parse_summary_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_summary) return error.DuplicateSummaryTag;
    info.summary = try parse_required_text_item(tag, error.InvalidSummaryTag);
    state.saw_summary = true;
}

fn parse_alt_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_alt) return error.DuplicateAltTag;
    info.alt = try parse_required_text_item(tag, error.InvalidAltTag);
    state.saw_alt = true;
}

fn parse_fallback_tag(
    tag: nip01_event.EventTag,
    info: *FileMetadataInfo,
    out_fallback_urls: [][]const u8,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_fallback_urls.len <= limits.tags_max);

    if (info.fallback_count >= out_fallback_urls.len) return error.BufferTooSmall;
    out_fallback_urls[info.fallback_count] = try parse_required_url_item(
        tag,
        error.InvalidFallbackTag,
    );
    info.fallback_count += 1;
}

fn parse_service_tag(
    tag: nip01_event.EventTag,
    state: *ParseState,
    info: *FileMetadataInfo,
) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (state.saw_service) return error.DuplicateServiceTag;
    info.service = try parse_required_text_item(tag, error.InvalidServiceTag);
    state.saw_service = true;
}

fn require_required_tags(state: *const ParseState, info: *const FileMetadataInfo) Nip94Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (!state.saw_url) return error.MissingUrlTag;
    if (!state.saw_mime) return error.MissingMimeTypeTag;
    if (!state.saw_hash) return error.MissingHashTag;
}

fn parse_image_reference(tag: nip01_event.EventTag, invalid: Nip94Error) Nip94Error!ImageReference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(invalid == error.InvalidThumbTag or invalid == error.InvalidImageTag);

    if (tag.items.len != 2 and tag.items.len != 3) return invalid;
    var parsed = ImageReference{
        .url = try parse_required_image_url_item(tag, invalid),
        .sha256 = null,
    };
    if (tag.items.len >= 3) {
        parsed.sha256 = parse_lower_hex_32(tag.items[2]) catch return invalid;
    }
    return parsed;
}

fn parse_required_text_item(tag: nip01_event.EventTag, invalid: Nip94Error) Nip94Error![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(invalid != error.BufferTooSmall);

    if (tag.items.len != 2) return invalid;
    return parse_nonempty_utf8(tag.items[1]) catch return invalid;
}

fn parse_required_url_item(tag: nip01_event.EventTag, invalid: Nip94Error) Nip94Error![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(invalid != error.BufferTooSmall);

    if (tag.items.len != 2) return invalid;
    return parse_url(tag.items[1]) catch return invalid;
}

fn parse_required_image_url_item(
    tag: nip01_event.EventTag,
    invalid: Nip94Error,
) Nip94Error![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(invalid != error.BufferTooSmall);

    if (tag.items.len != 2 and tag.items.len != 3) return invalid;
    return parse_url(tag.items[1]) catch return invalid;
}

fn parse_required_hash_item(tag: nip01_event.EventTag, invalid: Nip94Error) Nip94Error![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(invalid != error.BufferTooSmall);

    if (tag.items.len != 2) return invalid;
    return parse_lower_hex_32(tag.items[1]) catch return invalid;
}

fn parse_required_u64_item(tag: nip01_event.EventTag, invalid: Nip94Error) Nip94Error!u64 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(invalid != error.BufferTooSmall);

    if (tag.items.len != 2) return invalid;
    return parse_decimal_u64(tag.items[1]) catch return invalid;
}

fn parse_required_dimensions_item(
    tag: nip01_event.EventTag,
    invalid: Nip94Error,
) Nip94Error!Dimensions {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(invalid != error.BufferTooSmall);

    if (tag.items.len != 2) return invalid;
    return parse_dimensions(tag.items[1]) catch return invalid;
}

fn parse_required_mime_type_item(
    tag: nip01_event.EventTag,
    invalid: Nip94Error,
) Nip94Error![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(invalid != error.BufferTooSmall);

    if (tag.items.len != 2) return invalid;
    return parse_mime_type(tag.items[1]) catch return invalid;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUtf8;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_mime_type(text: []const u8) error{InvalidMimeType}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len < 3) return error.InvalidMimeType;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidMimeType;
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
        if (std.ascii.isLower(byte)) continue;
        if (std.ascii.isDigit(byte)) continue;
        if (byte == '!' or byte == '#' or byte == '$') continue;
        if (byte == '&' or byte == '-' or byte == '^') continue;
        if (byte == '_' or byte == '.' or byte == '+') continue;
        if (byte == '\'' or byte == '*' or byte == '`') continue;
        if (byte == '|' or byte == '~') continue;
        return false;
    }
    return true;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUrl;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUrl;
    if (!is_url_shaped(text)) return error.InvalidUrl;
    return text;
}

fn is_url_shaped(text: []const u8) bool {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return false;
    const parsed = std.Uri.parse(text) catch return false;
    if (parsed.scheme.len == 0) return false;
    return parsed.host != null;
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
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidNumber;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidNumber;
    return std.fmt.parseInt(u64, text, 10) catch return error.InvalidNumber;
}

fn parse_dimensions(text: []const u8) error{InvalidDimensions}!Dimensions {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidDimensions;
    const separator = std.mem.indexOfScalar(u8, text, 'x') orelse return error.InvalidDimensions;
    if (separator == 0) return error.InvalidDimensions;
    if (separator + 1 >= text.len) return error.InvalidDimensions;

    const width = parse_decimal_u32(text[0..separator]) catch return error.InvalidDimensions;
    const height = parse_decimal_u32(text[separator + 1 ..]) catch return error.InvalidDimensions;
    if (width == 0) return error.InvalidDimensions;
    if (height == 0) return error.InvalidDimensions;
    return .{ .width = width, .height = height };
}

fn parse_decimal_u32(text: []const u8) error{InvalidNumber}!u32 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidNumber;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidNumber;
    return std.fmt.parseInt(u32, text, 10) catch return error.InvalidNumber;
}

fn test_event(tags: []const nip01_event.EventTag, content: []const u8) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(content.len <= limits.content_bytes_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{1} ** 32,
        .sig = [_]u8{2} ** 64,
        .kind = file_metadata_kind,
        .created_at = 1,
        .content = content,
        .tags = tags,
    };
}

test "file metadata extract parses required and optional tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "url", "https://example.com/file.jpg" } },
        .{ .items = &.{ "m", "image/jpeg" } },
        .{ .items = &.{ "x", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "ox", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
        .{ .items = &.{ "size", "1024" } },
        .{ .items = &.{ "dim", "640x480" } },
        .{ .items = &.{ "thumb", "https://example.com/thumb.jpg", "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" } },
        .{ .items = &.{ "image", "https://example.com/preview.jpg" } },
        .{ .items = &.{ "summary", "preview text" } },
        .{ .items = &.{ "alt", "accessible description" } },
        .{ .items = &.{ "fallback", "https://backup.example/file.jpg" } },
        .{ .items = &.{ "fallback", "https://backup2.example/file.jpg" } },
        .{ .items = &.{ "service", "nip96" } },
    };
    var fallbacks: [2][]const u8 = undefined;

    const parsed = try file_metadata_extract(&test_event(tags[0..], "caption"), fallbacks[0..]);

    try std.testing.expectEqualStrings("https://example.com/file.jpg", parsed.url);
    try std.testing.expectEqualStrings("image/jpeg", parsed.mime_type);
    try std.testing.expectEqual(@as(u64, 1024), parsed.size.?);
    try std.testing.expectEqual(@as(u32, 640), parsed.dimensions.?.width);
    try std.testing.expectEqual(@as(u32, 480), parsed.dimensions.?.height);
    try std.testing.expectEqualStrings("https://example.com/thumb.jpg", parsed.thumb.?.url);
    try std.testing.expect(parsed.thumb.?.sha256 != null);
    try std.testing.expectEqualStrings("https://example.com/preview.jpg", parsed.image.?.url);
    try std.testing.expectEqual(@as(u16, 2), parsed.fallback_count);
    try std.testing.expectEqualStrings("https://backup.example/file.jpg", fallbacks[0]);
    try std.testing.expectEqualStrings("nip96", parsed.service.?);
    try std.testing.expectEqualStrings("caption", parsed.caption);
}

test "file metadata extract rejects invalid mime types and extra supported-tag slots" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "url", "https://example.com/file.jpg", "ignored" } },
        .{ .items = &.{ "m", "Image/JPEG" } },
        .{ .items = &.{ "x", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "ignored" } },
    };
    var fallbacks: [0][]const u8 = .{};

    try std.testing.expectError(
        error.InvalidUrlTag,
        file_metadata_extract(&test_event(tags[0..], ""), fallbacks[0..]),
    );

    const invalid_mime = [_]nip01_event.EventTag{
        .{ .items = &.{ "url", "https://example.com/file.jpg" } },
        .{ .items = &.{ "m", "Image/JPEG" } },
        .{ .items = &.{ "x", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
    };
    try std.testing.expectError(
        error.InvalidMimeTypeTag,
        file_metadata_extract(&test_event(invalid_mime[0..], ""), fallbacks[0..]),
    );

    const invalid_size = [_]nip01_event.EventTag{
        .{ .items = &.{ "url", "https://example.com/file.jpg" } },
        .{ .items = &.{ "m", "image/jpeg" } },
        .{ .items = &.{ "x", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "size", "42", "ignored" } },
    };
    try std.testing.expectError(
        error.InvalidSizeTag,
        file_metadata_extract(&test_event(invalid_size[0..], ""), fallbacks[0..]),
    );
}

test "file metadata extract rejects missing required or malformed supported tags" {
    const missing_required = [_]nip01_event.EventTag{
        .{ .items = &.{ "url", "https://example.com/file.jpg" } },
        .{ .items = &.{ "m", "image/jpeg" } },
    };
    var fallbacks: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.MissingHashTag,
        file_metadata_extract(&test_event(missing_required[0..], ""), fallbacks[0..]),
    );

    const invalid_thumb = [_]nip01_event.EventTag{
        .{ .items = &.{ "url", "https://example.com/file.jpg" } },
        .{ .items = &.{ "m", "image/jpeg" } },
        .{ .items = &.{ "x", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "thumb", "https://example.com/thumb.jpg", "bad-hash" } },
    };
    try std.testing.expectError(
        error.InvalidThumbTag,
        file_metadata_extract(&test_event(invalid_thumb[0..], ""), fallbacks[0..]),
    );
}

test "file metadata builders create canonical tags" {
    var size_tag: BuiltTag = .{};
    var dimensions_tag: BuiltTag = .{};
    var image_tag: BuiltTag = .{};
    var mime_tag: BuiltTag = .{};

    const built_size = try file_metadata_build_size_tag(&size_tag, 2048);
    const built_dimensions = try file_metadata_build_dimensions_tag(
        &dimensions_tag,
        .{ .width = 1280, .height = 720 },
    );
    const built_image = try file_metadata_build_image_tag(
        &image_tag,
        "https://example.com/preview.jpg",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    const built_mime = try file_metadata_build_mime_type_tag(&mime_tag, "image/webp");

    try std.testing.expectEqualStrings("size", built_size.items[0]);
    try std.testing.expectEqualStrings("2048", built_size.items[1]);
    try std.testing.expectEqualStrings("dim", built_dimensions.items[0]);
    try std.testing.expectEqualStrings("1280x720", built_dimensions.items[1]);
    try std.testing.expectEqualStrings("image", built_image.items[0]);
    try std.testing.expectEqualStrings(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        built_image.items[2],
    );
    try std.testing.expectEqualStrings("m", built_mime.items[0]);
    try std.testing.expectEqualStrings("image/webp", built_mime.items[1]);
}

test "file metadata mime builder rejects non-canonical mime values" {
    var mime_tag: BuiltTag = .{};

    try std.testing.expectError(
        error.InvalidMimeTypeTag,
        file_metadata_build_mime_type_tag(&mime_tag, "Image/JPEG"),
    );
    try std.testing.expectError(
        error.InvalidMimeTypeTag,
        file_metadata_build_mime_type_tag(&mime_tag, "not a mime"),
    );
}

test "file metadata builders reject overlong caller input with typed errors" {
    var tag: BuiltTag = .{};
    const overlong_url = "https://" ++ ("a" ** 5000) ++ ".example";
    const overlong_text = "x" ** 5000;

    try std.testing.expectError(
        error.InvalidUrlTag,
        file_metadata_build_url_tag(&tag, overlong_url),
    );
    try std.testing.expectError(
        error.InvalidSummaryTag,
        file_metadata_build_summary_tag(&tag, overlong_text),
    );
    try std.testing.expectError(
        error.InvalidServiceTag,
        file_metadata_build_service_tag(&tag, overlong_text),
    );
    try std.testing.expectError(
        error.InvalidDimensionsTag,
        file_metadata_build_dimensions_tag(&tag, .{ .width = 0, .height = 1 }),
    );
}
