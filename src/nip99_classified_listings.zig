const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const url_with_host = @import("internal/url_with_host.zig");

pub const Nip99Error = error{
    UnsupportedKind,
    MissingIdentifier,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateTitleTag,
    InvalidTitleTag,
    DuplicateSummaryTag,
    InvalidSummaryTag,
    DuplicatePublishedAtTag,
    InvalidPublishedAtTag,
    DuplicateLocationTag,
    InvalidLocationTag,
    DuplicatePriceTag,
    InvalidPriceTag,
    DuplicateStatusTag,
    InvalidStatusTag,
    DuplicateGeohashTag,
    InvalidGeohashTag,
    InvalidImageTag,
    InvalidHashtagTag,
    InvalidContent,
    BufferTooSmall,
};

pub const ListingKind = enum(u32) {
    listing = 30402,
    draft = 30403,
};

pub const ListingStatus = union(enum) {
    active,
    sold,
    other: []const u8,
};

pub const PriceInfo = struct {
    amount: []const u8,
    currency: []const u8,
    frequency: ?[]const u8 = null,
};

pub const ImageInfo = struct {
    url: []const u8,
    dimensions: ?[]const u8 = null,
};

pub const ListingMetadata = struct {
    kind: ListingKind,
    identifier: []const u8,
    content: []const u8,
    title: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    published_at: ?u64 = null,
    location: ?[]const u8 = null,
    price: ?PriceInfo = null,
    status: ?ListingStatus = null,
    geohash: ?[]const u8 = null,
    image_count: u16 = 0,
    hashtag_count: u16 = 0,
};

pub const BuiltTag = struct {
    items: [4][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Returns the supported strict NIP-99 kind, or `null` when unsupported.
pub fn listing_kind_classify(kind: u32) ?ListingKind {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(@sizeOf(ListingKind) == @sizeOf(u32));

    return switch (kind) {
        30402 => .listing,
        30403 => .draft,
        else => null,
    };
}

/// Extracts bounded NIP-99 listing metadata, images, and ordered hashtags.
pub fn listing_extract(
    event: *const nip01_event.Event,
    out_images: []ImageInfo,
    out_hashtags: [][]const u8,
) Nip99Error!ListingMetadata {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_images.len <= std.math.maxInt(u16));

    const kind = listing_kind_classify(event.kind) orelse return error.UnsupportedKind;
    try validate_content(event.content);

    var identifier: ?[]const u8 = null;
    var metadata = ListingMetadata{
        .kind = kind,
        .identifier = undefined,
        .content = event.content,
    };
    for (event.tags) |tag| {
        try apply_tag(tag, &identifier, &metadata, out_images, out_hashtags);
    }
    metadata.identifier = identifier orelse return error.MissingIdentifier;
    return metadata;
}

/// Builds a listing `d` tag.
pub fn listing_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "d";
    output.items[1] = parse_scheme_less_url(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a listing `title` tag.
pub fn listing_build_title_tag(
    output: *BuiltTag,
    title: []const u8,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "title";
    output.items[1] = parse_nonempty_utf8(title) catch return error.InvalidTitleTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a listing `summary` tag.
pub fn listing_build_summary_tag(
    output: *BuiltTag,
    summary: []const u8,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "summary";
    output.items[1] = parse_nonempty_utf8(summary) catch return error.InvalidSummaryTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a listing `published_at` tag.
pub fn listing_build_published_at_tag(
    output: *BuiltTag,
    published_at: u64,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(published_at <= std.math.maxInt(u64));

    output.items[0] = "published_at";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{published_at}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a listing `location` tag.
pub fn listing_build_location_tag(
    output: *BuiltTag,
    location: []const u8,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "location";
    output.items[1] = parse_nonempty_utf8(location) catch return error.InvalidLocationTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a listing `price` tag.
pub fn listing_build_price_tag(
    output: *BuiltTag,
    price: *const PriceInfo,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(price) != 0);

    try validate_price(price);
    output.items[0] = "price";
    output.items[1] = price.amount;
    output.items[2] = price.currency;
    output.item_count = 3;
    if (price.frequency) |value| {
        output.items[3] = value;
        output.item_count = 4;
    }
    return output.as_event_tag();
}

/// Builds a listing `status` tag.
pub fn listing_build_status_tag(
    output: *BuiltTag,
    status: ListingStatus,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@sizeOf(ListingStatus) > 0);

    output.items[0] = "status";
    output.items[1] = switch (status) {
        .active => "active",
        .sold => "sold",
        .other => |value| parse_nonempty_utf8(value) catch return error.InvalidStatusTag,
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a listing geohash `g` tag.
pub fn listing_build_geohash_tag(
    output: *BuiltTag,
    geohash: []const u8,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "g";
    output.items[1] = parse_geohash(geohash) catch return error.InvalidGeohashTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a listing `image` tag.
pub fn listing_build_image_tag(
    output: *BuiltTag,
    image_url: []const u8,
    dimensions: ?[]const u8,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "image";
    output.items[1] = parse_url(image_url) catch return error.InvalidImageTag;
    output.item_count = 2;
    if (dimensions) |value| {
        output.items[2] = parse_dimensions(value) catch return error.InvalidImageTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a listing `t` hashtag tag.
pub fn listing_build_hashtag_tag(
    output: *BuiltTag,
    hashtag: []const u8,
) Nip99Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    output.items[0] = "t";
    output.items[1] = parse_hashtag_value(hashtag) catch return error.InvalidHashtagTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    metadata: *ListingMetadata,
    out_images: []ImageInfo,
    out_hashtags: [][]const u8,
) Nip99Error!void {
    std.debug.assert(@intFromPtr(identifier) != 0);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, name, "title")) return apply_title_tag(tag, metadata);
    if (std.mem.eql(u8, name, "summary")) return apply_summary_tag(tag, metadata);
    if (std.mem.eql(u8, name, "published_at")) return apply_published_at_tag(tag, metadata);
    if (std.mem.eql(u8, name, "location")) return apply_location_tag(tag, metadata);
    if (std.mem.eql(u8, name, "price")) return apply_price_tag(tag, metadata);
    if (std.mem.eql(u8, name, "status")) return apply_status_tag(tag, metadata);
    if (std.mem.eql(u8, name, "g")) return apply_geohash_tag(tag, metadata);
    if (std.mem.eql(u8, name, "image")) return apply_image_tag(tag, metadata, out_images);
    if (std.mem.eql(u8, name, "t")) return apply_hashtag_tag(tag, metadata, out_hashtags);
}

fn apply_identifier_tag(tag: nip01_event.EventTag, identifier: *?[]const u8) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    identifier.* = parse_identifier_value(tag) catch return error.InvalidIdentifierTag;
}

fn apply_title_tag(tag: nip01_event.EventTag, metadata: *ListingMetadata) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.title != null) return error.DuplicateTitleTag;
    metadata.title = parse_single_utf8_value(tag) catch return error.InvalidTitleTag;
}

fn apply_summary_tag(tag: nip01_event.EventTag, metadata: *ListingMetadata) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.summary != null) return error.DuplicateSummaryTag;
    metadata.summary = parse_single_utf8_value(tag) catch return error.InvalidSummaryTag;
}

fn apply_published_at_tag(tag: nip01_event.EventTag, metadata: *ListingMetadata) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.published_at != null) return error.DuplicatePublishedAtTag;
    metadata.published_at = parse_u64_value(tag) catch return error.InvalidPublishedAtTag;
}

fn apply_location_tag(tag: nip01_event.EventTag, metadata: *ListingMetadata) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.location != null) return error.DuplicateLocationTag;
    metadata.location = parse_single_utf8_value(tag) catch return error.InvalidLocationTag;
}

fn apply_price_tag(tag: nip01_event.EventTag, metadata: *ListingMetadata) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.price != null) return error.DuplicatePriceTag;
    metadata.price = try parse_price(tag);
}

fn apply_status_tag(tag: nip01_event.EventTag, metadata: *ListingMetadata) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.status != null) return error.DuplicateStatusTag;
    metadata.status = try parse_status(tag);
}

fn apply_geohash_tag(tag: nip01_event.EventTag, metadata: *ListingMetadata) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.geohash != null) return error.DuplicateGeohashTag;
    const value = parse_single_utf8_value(tag) catch return error.InvalidGeohashTag;
    metadata.geohash = parse_geohash(value) catch return error.InvalidGeohashTag;
}

fn apply_image_tag(
    tag: nip01_event.EventTag,
    metadata: *ListingMetadata,
    out_images: []ImageInfo,
) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.image_count == out_images.len) return error.BufferTooSmall;
    out_images[metadata.image_count] = .{
        .url = try parse_required_url_item(tag, 1, error.InvalidImageTag),
        .dimensions = try parse_optional_dimensions_item(tag, 2, error.InvalidImageTag),
    };
    metadata.image_count += 1;
}

fn apply_hashtag_tag(
    tag: nip01_event.EventTag,
    metadata: *ListingMetadata,
    out_hashtags: [][]const u8,
) Nip99Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.hashtag_count == out_hashtags.len) return error.BufferTooSmall;
    if (tag.items.len != 2) return error.InvalidHashtagTag;
    out_hashtags[metadata.hashtag_count] =
        parse_hashtag_value(tag.items[1]) catch return error.InvalidHashtagTag;
    metadata.hashtag_count += 1;
}

fn parse_price(tag: nip01_event.EventTag) Nip99Error!PriceInfo {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 4);

    if (tag.items.len != 3 and tag.items.len != 4) return error.InvalidPriceTag;
    const amount = parse_numeric_amount(tag.items[1]) catch return error.InvalidPriceTag;
    const currency = parse_currency(tag.items[2]) catch return error.InvalidPriceTag;
    const frequency = if (tag.items.len == 4)
        parse_nonempty_utf8(tag.items[3]) catch return error.InvalidPriceTag
    else
        null;
    return .{ .amount = amount, .currency = currency, .frequency = frequency };
}

fn validate_price(price: *const PriceInfo) Nip99Error!void {
    std.debug.assert(@intFromPtr(price) != 0);
    std.debug.assert(price.amount.len <= limits.tag_item_bytes_max);

    _ = parse_numeric_amount(price.amount) catch return error.InvalidPriceTag;
    _ = parse_currency(price.currency) catch return error.InvalidPriceTag;
    if (price.frequency) |value| {
        _ = parse_nonempty_utf8(value) catch return error.InvalidPriceTag;
    }
}

fn parse_status(tag: nip01_event.EventTag) Nip99Error!ListingStatus {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@sizeOf(ListingStatus) > 0);

    const value = parse_single_utf8_value(tag) catch return error.InvalidStatusTag;
    if (std.mem.eql(u8, value, "active")) return .active;
    if (std.mem.eql(u8, value, "sold")) return .sold;
    return .{ .other = value };
}

fn validate_content(content: []const u8) Nip99Error!void {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (!std.unicode.utf8ValidateSlice(content)) return error.InvalidContent;
}

fn parse_single_utf8_value(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_nonempty_utf8(tag.items[1]) catch return error.InvalidValue;
}

fn parse_identifier_value(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_scheme_less_url(tag.items[1]) catch return error.InvalidValue;
}

fn parse_u64_value(tag: nip01_event.EventTag) error{InvalidValue}!u64 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return std.fmt.parseInt(u64, tag.items[1], 10) catch return error.InvalidValue;
}

fn parse_required_url_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid: Nip99Error,
) Nip99Error![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(index < limits.tag_items_max);

    if (tag.items.len <= index) return invalid;
    return parse_url(tag.items[index]) catch return invalid;
}

fn parse_optional_dimensions_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid: Nip99Error,
) Nip99Error!?[]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(index < limits.tag_items_max);

    if (tag.items.len <= index) return null;
    if (tag.items.len != index + 1) return invalid;
    return parse_dimensions(tag.items[index]) catch return invalid;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUtf8;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_scheme_less_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

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
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return url_with_host.parse(text, limits.tag_item_bytes_max);
}

fn parse_dimensions(text: []const u8) error{InvalidDimensions}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidDimensions;
    const separator = std.mem.indexOfScalar(u8, text, 'x') orelse return error.InvalidDimensions;
    if (separator == 0 or separator + 1 >= text.len) return error.InvalidDimensions;
    _ = std.fmt.parseInt(u32, text[0..separator], 10) catch return error.InvalidDimensions;
    _ = std.fmt.parseInt(u32, text[separator + 1 ..], 10) catch return error.InvalidDimensions;
    return text;
}

fn parse_numeric_amount(text: []const u8) error{InvalidAmount}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidAmount;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidAmount;
    var saw_dot = false;
    for (text, 0..) |byte, index| {
        if (byte == '.') {
            if (saw_dot or index == 0 or index + 1 == text.len) return error.InvalidAmount;
            saw_dot = true;
            continue;
        }
        if (!std.ascii.isDigit(byte)) return error.InvalidAmount;
    }
    return text;
}

fn parse_currency(text: []const u8) error{InvalidCurrency}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidCurrency;
    if (text.len < 3 or text.len > 8) return error.InvalidCurrency;
    for (text) |byte| {
        if (!std.ascii.isAlphanumeric(byte)) return error.InvalidCurrency;
    }
    return text;
}

fn parse_geohash(text: []const u8) error{InvalidGeohash}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidGeohash;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidGeohash;
    for (text) |byte| {
        if (byte >= '0' and byte <= '9') continue;
        if (byte == 'b' or byte == 'c' or byte == 'd') continue;
        if (byte == 'e' or byte == 'f' or byte == 'g') continue;
        if (byte == 'h' or byte == 'j' or byte == 'k') continue;
        if (byte == 'm' or byte == 'n' or byte == 'p') continue;
        if (byte == 'q' or byte == 'r' or byte == 's') continue;
        if (byte == 't' or byte == 'u' or byte == 'v') continue;
        if (byte == 'w' or byte == 'x' or byte == 'y' or byte == 'z') continue;
        return error.InvalidGeohash;
    }
    return text;
}

fn parse_hashtag_value(text: []const u8) error{InvalidHashtag}![]const u8 {
    std.debug.assert(text.len <= std.math.maxInt(usize));
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidHashtag;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidHashtag;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidHashtag;
    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) return error.InvalidHashtag;
        if (std.ascii.isUpper(byte)) return error.InvalidHashtag;
    }
    return text;
}

fn test_event(tags: []const nip01_event.EventTag, content: []const u8, kind: u32) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(content.len <= limits.content_bytes_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{1} ** 32,
        .sig = [_]u8{2} ** 64,
        .kind = kind,
        .created_at = 1,
        .content = content,
        .tags = tags,
    };
}

test "listing extract parses bounded metadata images and hashtags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "alice.blog/post" } },
        .{ .items = &.{ "title", "Road bike" } },
        .{ .items = &.{ "summary", "Fast and light" } },
        .{ .items = &.{ "published_at", "1710000000" } },
        .{ .items = &.{ "location", "Lisbon" } },
        .{ .items = &.{ "price", "500.50", "EUR", "month" } },
        .{ .items = &.{ "status", "active" } },
        .{ .items = &.{ "g", "ezjp" } },
        .{ .items = &.{ "image", "https://example.com/bike.jpg", "800x600" } },
        .{ .items = &.{ "t", "cycling" } },
    };
    var images: [2]ImageInfo = undefined;
    var hashtags: [2][]const u8 = undefined;

    const parsed = try listing_extract(&test_event(tags[0..], "bike details", 30402), images[0..], hashtags[0..]);

    try std.testing.expectEqualStrings("alice.blog/post", parsed.identifier);
    try std.testing.expectEqualStrings("Road bike", parsed.title.?);
    try std.testing.expectEqualStrings("500.50", parsed.price.?.amount);
    try std.testing.expectEqualStrings("EUR", parsed.price.?.currency);
    try std.testing.expectEqual(@as(u16, 1), parsed.image_count);
    try std.testing.expectEqualStrings("https://example.com/bike.jpg", images[0].url);
    try std.testing.expectEqualStrings("cycling", hashtags[0]);
}

test "listing extract rejects malformed required and supported tags" {
    const missing_identifier = [_]nip01_event.EventTag{
        .{ .items = &.{ "title", "Road bike" } },
    };
    var images: [0]ImageInfo = .{};
    var hashtags: [0][]const u8 = .{};

    try std.testing.expectError(
        error.MissingIdentifier,
        listing_extract(&test_event(missing_identifier[0..], "", 30402), images[0..], hashtags[0..]),
    );

    const invalid_price = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "alice.blog/post" } },
        .{ .items = &.{ "price", "free", "USD" } },
    };
    try std.testing.expectError(
        error.InvalidPriceTag,
        listing_extract(&test_event(invalid_price[0..], "", 30402), images[0..], hashtags[0..]),
    );

    const invalid_identifier = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "not a url id" } },
    };
    try std.testing.expectError(
        error.InvalidIdentifierTag,
        listing_extract(&test_event(invalid_identifier[0..], "", 30402), images[0..], hashtags[0..]),
    );
}

test "listing builders create canonical tags" {
    var identifier_tag: BuiltTag = .{};
    var price_tag: BuiltTag = .{};
    var image_tag: BuiltTag = .{};
    var status_tag: BuiltTag = .{};

    const identifier = try listing_build_identifier_tag(&identifier_tag, "alice.blog/post");
    const price = try listing_build_price_tag(
        &price_tag,
        &.{ .amount = "50", .currency = "USD", .frequency = null },
    );
    const image = try listing_build_image_tag(&image_tag, "https://example.com/item.jpg", "400x300");
    const status = try listing_build_status_tag(&status_tag, .active);

    try std.testing.expectEqualStrings("d", identifier.items[0]);
    try std.testing.expectEqualStrings("alice.blog/post", identifier.items[1]);
    try std.testing.expectEqualStrings("price", price.items[0]);
    try std.testing.expectEqualStrings("50", price.items[1]);
    try std.testing.expectEqualStrings("image", image.items[0]);
    try std.testing.expectEqualStrings("400x300", image.items[2]);
    try std.testing.expectEqualStrings("status", status.items[0]);
    try std.testing.expectEqualStrings("active", status.items[1]);

    try std.testing.expectError(
        error.InvalidIdentifierTag,
        listing_build_identifier_tag(&identifier_tag, "https://example.com/post"),
    );
}

test "listing builders reject overlong caller input with typed errors" {
    var title_tag: BuiltTag = .{};
    var image_tag: BuiltTag = .{};
    const overlong_text = "x" ** (limits.tag_item_bytes_max + 1);
    const overlong_url = "https://" ++ ("a" ** limits.tag_item_bytes_max) ++ ".example";

    try std.testing.expectError(
        error.InvalidTitleTag,
        listing_build_title_tag(&title_tag, overlong_text[0..]),
    );
    try std.testing.expectError(
        error.InvalidImageTag,
        listing_build_image_tag(&image_tag, overlong_url[0..], null),
    );
}
