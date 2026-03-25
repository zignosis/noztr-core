const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const url_with_host = @import("internal/url_with_host.zig");

pub const LongFormError = error{
    UnsupportedKind,
    MissingIdentifier,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateTitleTag,
    InvalidTitleTag,
    DuplicateImageTag,
    InvalidImageTag,
    DuplicateSummaryTag,
    InvalidSummaryTag,
    DuplicatePublishedAtTag,
    InvalidPublishedAtTag,
    InvalidHashtagTag,
    InvalidContent,
    BufferTooSmall,
};

pub const LongFormKind = enum(u32) {
    article = 30023,
    draft = 30024,
};

pub const Metadata = struct {
    kind: LongFormKind,
    identifier: []const u8,
    content: []const u8,
    title: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    image_dimensions: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    published_at: ?u64 = null,
    hashtag_count: u16 = 0,
};

pub const TagBuilder = struct {
    items: [3][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    /// Returns the built tag backed by this buffer.
    pub fn as_event_tag(self: *const TagBuilder) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Returns the supported strict NIP-23 kind, or `null` when unsupported.
pub fn long_form_kind_classify(kind: u32) ?LongFormKind {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(@sizeOf(LongFormKind) == @sizeOf(u32));

    return switch (kind) {
        30023 => .article,
        30024 => .draft,
        else => null,
    };
}

/// Returns whether the event kind is supported by the strict NIP-23 helper.
pub fn long_form_is_supported(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= limits.kind_max);

    return long_form_kind_classify(event.kind) != null;
}

/// Extract strict NIP-23 metadata and ordered hashtags from a long-form event.
///
/// Lifetime and ownership:
/// - metadata fields and hashtag slices borrow from `event`.
/// - keep `event` and its tag item storage alive while using the returned data.
pub fn long_form_extract(
    event: *const nip01_event.Event,
    out_hashtags: [][]const u8,
) LongFormError!Metadata {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_hashtags.len <= std.math.maxInt(u16));

    const kind = long_form_kind_classify(event.kind) orelse return error.UnsupportedKind;
    try validate_content(event.content);

    var identifier: ?[]const u8 = null;
    var metadata = Metadata{
        .kind = kind,
        .identifier = undefined,
        .content = event.content,
    };

    for (event.tags) |tag| {
        try apply_tag(tag, &identifier, &metadata, out_hashtags);
    }

    metadata.identifier = identifier orelse return error.MissingIdentifier;
    return metadata;
}

/// Builds a `d` tag for long-form content.
pub fn long_form_build_identifier_tag(
    output: *TagBuilder,
    identifier: []const u8,
) LongFormError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a `title` tag for long-form content.
pub fn long_form_build_title_tag(
    output: *TagBuilder,
    title: []const u8,
) LongFormError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(title.len <= limits.tag_item_bytes_max);

    output.items[0] = "title";
    output.items[1] = parse_nonempty_utf8(title) catch return error.InvalidTitleTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds an `image` tag for long-form content.
pub fn long_form_build_image_tag(
    output: *TagBuilder,
    image_url: []const u8,
    image_dimensions: ?[]const u8,
) LongFormError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(image_url.len <= limits.tag_item_bytes_max);

    output.items[0] = "image";
    output.items[1] = parse_url(image_url) catch return error.InvalidImageTag;
    output.item_count = 2;
    if (image_dimensions) |dimensions| {
        output.items[2] = parse_nonempty_utf8(dimensions) catch return error.InvalidImageTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a `summary` tag for long-form content.
pub fn long_form_build_summary_tag(
    output: *TagBuilder,
    summary: []const u8,
) LongFormError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(summary.len <= limits.tag_item_bytes_max);

    output.items[0] = "summary";
    output.items[1] = parse_nonempty_utf8(summary) catch return error.InvalidSummaryTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a `published_at` tag for long-form content.
pub fn long_form_build_published_at_tag(
    output: *TagBuilder,
    published_at: u64,
) LongFormError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(published_at <= std.math.maxInt(u64));

    output.items[0] = "published_at";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{published_at}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a `t` hashtag tag for long-form content.
pub fn long_form_build_hashtag_tag(
    output: *TagBuilder,
    hashtag: []const u8,
) LongFormError!nip01_event.EventTag {
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
    metadata: *Metadata,
    out_hashtags: [][]const u8,
) LongFormError!void {
    std.debug.assert(@intFromPtr(identifier) != 0);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, name, "title")) return apply_title_tag(tag, metadata);
    if (std.mem.eql(u8, name, "image")) return apply_image_tag(tag, metadata);
    if (std.mem.eql(u8, name, "summary")) return apply_summary_tag(tag, metadata);
    if (std.mem.eql(u8, name, "published_at")) return apply_published_at_tag(tag, metadata);
    if (std.mem.eql(u8, name, "t")) return apply_hashtag_tag(tag, metadata, out_hashtags);
}

fn apply_identifier_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
) LongFormError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    identifier.* = parse_single_value(tag, error.InvalidIdentifierTag) catch {
        return error.InvalidIdentifierTag;
    };
}

fn apply_title_tag(tag: nip01_event.EventTag, metadata: *Metadata) LongFormError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.title != null) return error.DuplicateTitleTag;
    metadata.title = parse_single_value(tag, error.InvalidTitleTag) catch {
        return error.InvalidTitleTag;
    };
}

fn apply_image_tag(tag: nip01_event.EventTag, metadata: *Metadata) LongFormError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.image_url != null) return error.DuplicateImageTag;
    const parsed = parse_image_value(tag) catch return error.InvalidImageTag;
    metadata.image_url = parsed.url;
    metadata.image_dimensions = parsed.dimensions;
}

fn apply_summary_tag(tag: nip01_event.EventTag, metadata: *Metadata) LongFormError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.summary != null) return error.DuplicateSummaryTag;
    metadata.summary = parse_single_value(tag, error.InvalidSummaryTag) catch {
        return error.InvalidSummaryTag;
    };
}

fn apply_published_at_tag(
    tag: nip01_event.EventTag,
    metadata: *Metadata,
) LongFormError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    if (metadata.published_at != null) return error.DuplicatePublishedAtTag;
    metadata.published_at = parse_published_at_value(tag) catch return error.InvalidPublishedAtTag;
}

fn apply_hashtag_tag(
    tag: nip01_event.EventTag,
    metadata: *Metadata,
    out_hashtags: [][]const u8,
) LongFormError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(metadata) != 0);

    const hashtag = parse_hashtag_tag(tag) catch return error.InvalidHashtagTag;
    if (metadata.hashtag_count == out_hashtags.len) return error.BufferTooSmall;
    out_hashtags[metadata.hashtag_count] = hashtag;
    metadata.hashtag_count += 1;
}

fn parse_hashtag_tag(tag: nip01_event.EventTag) error{InvalidHashtagTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidHashtagTag;
    return parse_hashtag_value(tag.items[1]) catch return error.InvalidHashtagTag;
}

fn validate_content(content: []const u8) LongFormError!void {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (!std.unicode.utf8ValidateSlice(content)) return error.InvalidContent;
}

fn parse_single_value(
    tag: nip01_event.EventTag,
    invalid_error: LongFormError,
) LongFormError![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@typeInfo(LongFormError) == .error_set);

    if (tag.items.len != 2) return invalid_error;
    return parse_nonempty_utf8(tag.items[1]) catch invalid_error;
}

const ImageValue = struct {
    url: []const u8,
    dimensions: ?[]const u8 = null,
};

fn parse_image_value(tag: nip01_event.EventTag) LongFormError!ImageValue {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 3);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidImageTag;
    var value = ImageValue{
        .url = parse_url(tag.items[1]) catch return error.InvalidImageTag,
    };
    if (tag.items.len == 3) {
        value.dimensions = parse_nonempty_utf8(tag.items[2]) catch return error.InvalidImageTag;
    }
    return value;
}

fn parse_published_at_value(tag: nip01_event.EventTag) LongFormError!u64 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@sizeOf(u64) == 8);

    const text = try parse_single_value(tag, error.InvalidPublishedAtTag);
    return std.fmt.parseUnsigned(u64, text, 10) catch error.InvalidPublishedAtTag;
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
    std.debug.assert(text.len <= limits.content_bytes_max);

    const parsed = parse_nonempty_utf8(text) catch return error.InvalidHashtag;
    for (parsed) |byte| {
        if (std.ascii.isWhitespace(byte)) return error.InvalidHashtag;
        if (std.ascii.isUpper(byte)) return error.InvalidHashtag;
    }
    return parsed;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    return url_with_host.parse(text, limits.tag_item_bytes_max);
}

test "long form classify supports article and draft kinds" {
    try std.testing.expectEqual(LongFormKind.article, long_form_kind_classify(30023).?);
    try std.testing.expectEqual(LongFormKind.draft, long_form_kind_classify(30024).?);
    try std.testing.expectEqual(@as(?LongFormKind, null), long_form_kind_classify(30025));
}

test "long form extract parses standard metadata and ordered hashtags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "lorem-ipsum" } },
        .{ .items = &.{ "title", "Lorem Ipsum" } },
        .{ .items = &.{ "image", "https://example.com/image.png" } },
        .{ .items = &.{ "summary", "Article summary" } },
        .{ .items = &.{ "published_at", "1296962229" } },
        .{ .items = &.{ "t", "placeholder" } },
        .{ .items = &.{ "t", "nostr" } },
        .{ .items = &.{ "a", "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:ipsum" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 30023,
        .created_at = 1_700_000_000,
        .content = "Long-form markdown body",
        .tags = tags[0..],
    };
    var hashtags: [2][]const u8 = undefined;

    const parsed = try long_form_extract(&event, hashtags[0..]);

    try std.testing.expectEqual(LongFormKind.article, parsed.kind);
    try std.testing.expectEqualStrings("lorem-ipsum", parsed.identifier);
    try std.testing.expectEqualStrings("Long-form markdown body", parsed.content);
    try std.testing.expectEqualStrings("Lorem Ipsum", parsed.title.?);
    try std.testing.expectEqualStrings("https://example.com/image.png", parsed.image_url.?);
    try std.testing.expectEqual(@as(?[]const u8, null), parsed.image_dimensions);
    try std.testing.expectEqualStrings("Article summary", parsed.summary.?);
    try std.testing.expectEqual(@as(?u64, 1296962229), parsed.published_at);
    try std.testing.expectEqual(@as(u16, 2), parsed.hashtag_count);
    try std.testing.expectEqualStrings("placeholder", hashtags[0]);
    try std.testing.expectEqualStrings("nostr", hashtags[1]);
}

test "long form extract accepts draft image dimensions" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "draft-id" } },
        .{ .items = &.{ "image", "https://example.com/image.png", "800x600" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 30024,
        .created_at = 1_700_000_001,
        .content = "",
        .tags = tags[0..],
    };
    var hashtags: [1][]const u8 = undefined;

    const parsed = try long_form_extract(&event, hashtags[0..]);

    try std.testing.expectEqual(LongFormKind.draft, parsed.kind);
    try std.testing.expectEqualStrings("draft-id", parsed.identifier);
    try std.testing.expectEqualStrings("https://example.com/image.png", parsed.image_url.?);
    try std.testing.expectEqualStrings("800x600", parsed.image_dimensions.?);
    try std.testing.expectEqual(@as(u16, 0), parsed.hashtag_count);
}

test "long form extract rejects missing or malformed metadata" {
    const invalid_image = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "article" } },
        .{ .items = &.{ "image", "not-a-url" } },
    };
    const duplicate_title = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "article" } },
        .{ .items = &.{ "title", "A" } },
        .{ .items = &.{ "title", "B" } },
    };
    const missing_d = [_]nip01_event.EventTag{.{ .items = &.{ "title", "A" } }};
    const invalid_published_at = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "article" } },
        .{ .items = &.{ "published_at", "abc" } },
    };
    var hashtags: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.MissingIdentifier,
        long_form_extract(
            &.{
                .id = [_]u8{0} ** 32,
                .pubkey = [_]u8{0} ** 32,
                .sig = [_]u8{0} ** 64,
                .kind = 30023,
                .created_at = 0,
                .content = "body",
                .tags = missing_d[0..],
            },
            hashtags[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidImageTag,
        long_form_extract(
            &.{
                .id = [_]u8{0} ** 32,
                .pubkey = [_]u8{0} ** 32,
                .sig = [_]u8{0} ** 64,
                .kind = 30023,
                .created_at = 0,
                .content = "body",
                .tags = invalid_image[0..],
            },
            hashtags[0..],
        ),
    );
    try std.testing.expectError(
        error.DuplicateTitleTag,
        long_form_extract(
            &.{
                .id = [_]u8{0} ** 32,
                .pubkey = [_]u8{0} ** 32,
                .sig = [_]u8{0} ** 64,
                .kind = 30023,
                .created_at = 0,
                .content = "body",
                .tags = duplicate_title[0..],
            },
            hashtags[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidPublishedAtTag,
        long_form_extract(
            &.{
                .id = [_]u8{0} ** 32,
                .pubkey = [_]u8{0} ** 32,
                .sig = [_]u8{0} ** 64,
                .kind = 30023,
                .created_at = 0,
                .content = "body",
                .tags = invalid_published_at[0..],
            },
            hashtags[0..],
        ),
    );
}

test "long form builders emit bounded metadata tags" {
    var identifier_tag: TagBuilder = .{};
    var title_tag: TagBuilder = .{};
    var image_tag: TagBuilder = .{};
    var summary_tag: TagBuilder = .{};
    var published_at_tag: TagBuilder = .{};
    var hashtag_tag: TagBuilder = .{};

    try std.testing.expectEqualStrings(
        "d",
        (try long_form_build_identifier_tag(&identifier_tag, "lorem")).items[0],
    );
    try std.testing.expectEqualStrings(
        "title",
        (try long_form_build_title_tag(&title_tag, "Lorem Ipsum")).items[0],
    );
    const built_image = try long_form_build_image_tag(
        &image_tag,
        "https://example.com/image.png",
        "800x600",
    );
    try std.testing.expectEqualStrings("image", built_image.items[0]);
    try std.testing.expectEqualStrings("800x600", built_image.items[2]);
    try std.testing.expectEqualStrings(
        "summary",
        (try long_form_build_summary_tag(&summary_tag, "Article summary")).items[0],
    );
    try std.testing.expectEqualStrings(
        "published_at",
        (try long_form_build_published_at_tag(&published_at_tag, 1296962229)).items[0],
    );
    try std.testing.expectEqualStrings(
        "t",
        (try long_form_build_hashtag_tag(&hashtag_tag, "nostr")).items[0],
    );
    try std.testing.expectError(
        error.InvalidHashtagTag,
        long_form_build_hashtag_tag(&hashtag_tag, "Nostr"),
    );
}

test "long form extract rejects uppercase hashtags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "article" } },
        .{ .items = &.{ "t", "Nostr" } },
    };
    var hashtags: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.InvalidHashtagTag,
        long_form_extract(
            &.{
                .id = [_]u8{0} ** 32,
                .pubkey = [_]u8{0} ** 32,
                .sig = [_]u8{0} ** 64,
                .kind = 30023,
                .created_at = 0,
                .content = "body",
                .tags = tags[0..],
            },
            hashtags[0..],
        ),
    );
}
