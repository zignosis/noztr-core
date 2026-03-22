const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_scheme = @import("internal/url_with_scheme.zig");

pub const wiki_article_kind: u32 = 30818;
pub const wiki_merge_request_kind: u32 = 818;
pub const wiki_redirect_kind: u32 = 30819;

pub const WikiError = error{
    InvalidArticleKind,
    InvalidMergeRequestKind,
    InvalidRedirectKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateTitleTag,
    InvalidTitleTag,
    DuplicateSummaryTag,
    InvalidSummaryTag,
    InvalidForkReferenceTag,
    InvalidDeferReferenceTag,
    MissingTargetArticleTag,
    DuplicateTargetArticleTag,
    InvalidTargetArticleTag,
    DuplicateBaseRevisionTag,
    InvalidBaseRevisionTag,
    MissingSourceEventTag,
    InvalidSourceEventTag,
    MissingDestinationPubkeyTag,
    DuplicateDestinationPubkeyTag,
    InvalidDestinationPubkeyTag,
    MissingRedirectTargetTag,
    DuplicateRedirectTargetTag,
    InvalidRedirectTargetTag,
    BufferTooSmall,
};

pub const WikiArticleReference = struct {
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const WikiEventReference = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const WikiArticleInfo = struct {
    identifier: []const u8,
    content: []const u8,
    title: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    fork_count: u16 = 0,
    defer_count: u16 = 0,
};

pub const WikiMergeRequestInfo = struct {
    target_article: WikiArticleReference,
    base_revision: ?WikiEventReference = null,
    source_event: WikiEventReference,
    destination_pubkey: [32]u8,
    content: []const u8,
};

pub const WikiRedirectInfo = struct {
    identifier: []const u8,
    target_article: WikiArticleReference,
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

/// Extracts bounded article metadata from a `kind:30818` wiki article event.
pub fn wiki_article_extract(
    event: *const nip01_event.Event,
    out_forks: []WikiArticleReference,
    out_defers: []WikiArticleReference,
) WikiError!WikiArticleInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_forks.len <= limits.tags_max);

    if (event.kind != wiki_article_kind) return error.InvalidArticleKind;

    var identifier: ?[]const u8 = null;
    var info = WikiArticleInfo{ .identifier = undefined, .content = event.content };
    for (event.tags) |tag| {
        try apply_article_tag(tag, &identifier, &info, out_forks, out_defers);
    }
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    return info;
}

/// Extracts bounded merge-request metadata from a `kind:818` wiki merge request.
pub fn wiki_merge_request_extract(event: *const nip01_event.Event) WikiError!WikiMergeRequestInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != wiki_merge_request_kind) return error.InvalidMergeRequestKind;

    var target_article: ?WikiArticleReference = null;
    var base_revision: ?WikiEventReference = null;
    var source_event: ?WikiEventReference = null;
    var destination_pubkey: ?[32]u8 = null;
    for (event.tags) |tag| {
        try apply_merge_request_tag(tag, &target_article, &base_revision, &source_event, &destination_pubkey);
    }
    return .{
        .target_article = target_article orelse return error.MissingTargetArticleTag,
        .base_revision = base_revision,
        .source_event = source_event orelse return error.MissingSourceEventTag,
        .destination_pubkey = destination_pubkey orelse return error.MissingDestinationPubkeyTag,
        .content = event.content,
    };
}

/// Extracts bounded redirect metadata from a `kind:30819` wiki redirect event.
pub fn wiki_redirect_extract(event: *const nip01_event.Event) WikiError!WikiRedirectInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != wiki_redirect_kind) return error.InvalidRedirectKind;

    var identifier: ?[]const u8 = null;
    var target_article: ?WikiArticleReference = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "d")) try apply_identifier_tag(tag, &identifier);
        if (std.mem.eql(u8, tag.items[0], "a")) try apply_redirect_target(tag, &target_article);
    }
    return .{
        .identifier = identifier orelse return error.MissingIdentifierTag,
        .target_article = target_article orelse return error.MissingRedirectTargetTag,
    };
}

/// Normalizes an ASCII-heavy wiki title into a `d` identifier slug.
pub fn wiki_normalize_identifier_ascii(output: []u8, title: []const u8) WikiError![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(title.len <= limits.tag_item_bytes_max);

    if (!std.unicode.utf8ValidateSlice(title)) return error.InvalidIdentifierTag;
    var out_index: usize = 0;
    var previous_dash = false;
    for (title) |byte| {
        if (std.ascii.isWhitespace(byte)) {
            if (!previous_dash and out_index != 0) {
                output[out_index] = '-';
                out_index += 1;
            }
            previous_dash = true;
            continue;
        }
        if (std.ascii.isAlphanumeric(byte) or byte >= 0x80) {
            if (out_index == output.len) return error.BufferTooSmall;
            output[out_index] = if (byte < 0x80) std.ascii.toLower(byte) else byte;
            out_index += 1;
            previous_dash = false;
        }
    }
    if (out_index == 0) return error.InvalidIdentifierTag;
    if (output[out_index - 1] == '-') out_index -= 1;
    return output[0..out_index];
}

/// Builds a canonical wiki `d` tag.
pub fn wiki_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) WikiError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical wiki `title` tag.
pub fn wiki_build_title_tag(
    output: *BuiltTag,
    title: []const u8,
) WikiError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(title.len <= limits.tag_item_bytes_max);

    output.items[0] = "title";
    output.items[1] = parse_nonempty_utf8(title) catch return error.InvalidTitleTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical wiki `summary` tag.
pub fn wiki_build_summary_tag(
    output: *BuiltTag,
    summary: []const u8,
) WikiError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(summary.len <= limits.tag_item_bytes_max);

    output.items[0] = "summary";
    output.items[1] = parse_nonempty_utf8(summary) catch return error.InvalidSummaryTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical wiki article reference `a` tag with optional marker.
pub fn wiki_build_article_reference_tag(
    output: *BuiltTag,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
    marker: ?[]const u8,
) WikiError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(coordinate_text.len <= limits.tag_item_bytes_max);

    _ = parse_article_coordinate_text(coordinate_text) catch return error.InvalidTargetArticleTag;
    output.items[0] = "a";
    output.items[1] = coordinate_text;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidTargetArticleTag;
        output.item_count = 3;
    }
    if (marker) |value| {
        output.items[output.item_count] = parse_marker(value) catch return error.InvalidTargetArticleTag;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a canonical wiki event reference `e` tag with optional marker.
pub fn wiki_build_event_reference_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
    marker: ?[]const u8,
) WikiError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_id_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(event_id_hex) catch return error.InvalidSourceEventTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidSourceEventTag;
        output.item_count = 3;
    }
    if (marker) |value| {
        output.items[output.item_count] = parse_marker(value) catch return error.InvalidSourceEventTag;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a canonical merge-request destination `p` tag.
pub fn wiki_build_destination_pubkey_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
) WikiError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidDestinationPubkeyTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_article_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *WikiArticleInfo,
    out_forks: []WikiArticleReference,
    out_defers: []WikiArticleReference,
) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, tag.items[0], "title")) return apply_text_tag(tag, &info.title, error.DuplicateTitleTag, error.InvalidTitleTag);
    if (std.mem.eql(u8, tag.items[0], "summary")) return apply_text_tag(tag, &info.summary, error.DuplicateSummaryTag, error.InvalidSummaryTag);
    if (!std.mem.eql(u8, tag.items[0], "a")) return;
    if (tag.items.len < 2) return error.InvalidForkReferenceTag;
    const marker = parse_optional_marker(tag, 3, error.InvalidForkReferenceTag) catch {
        return error.InvalidForkReferenceTag;
    };
    if (marker == null or std.mem.eql(u8, marker.?, "fork")) return append_article_ref(tag, &info.fork_count, out_forks, error.InvalidForkReferenceTag);
    if (std.mem.eql(u8, marker.?, "defer")) return append_article_ref(tag, &info.defer_count, out_defers, error.InvalidDeferReferenceTag);
}

fn apply_merge_request_tag(
    tag: nip01_event.EventTag,
    target_article: *?WikiArticleReference,
    base_revision: *?WikiEventReference,
    source_event: *?WikiEventReference,
    destination_pubkey: *?[32]u8,
) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(target_article) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "a")) return apply_target_article(tag, target_article);
    if (std.mem.eql(u8, tag.items[0], "p")) return apply_destination_pubkey(tag, destination_pubkey);
    if (!std.mem.eql(u8, tag.items[0], "e")) return;
    const marker = parse_optional_marker(tag, 3, error.InvalidBaseRevisionTag) catch {
        return error.InvalidBaseRevisionTag;
    };
    if (marker != null and std.mem.eql(u8, marker.?, "source")) return apply_source_event(tag, source_event);
    return apply_base_revision(tag, base_revision);
}

fn apply_identifier_tag(tag: nip01_event.EventTag, identifier: *?[]const u8) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    identifier.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn apply_text_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: WikiError,
    invalid_error: WikiError,
) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
}

fn append_article_ref(
    tag: nip01_event.EventTag,
    count: *u16,
    out: []WikiArticleReference,
    invalid_error: WikiError,
) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(count) != 0);

    if (count.* == out.len) return error.BufferTooSmall;
    const parsed = parse_article_reference_tag(tag) catch return invalid_error;
    out[count.*] = parsed;
    count.* += 1;
}

fn apply_target_article(tag: nip01_event.EventTag, target: *?WikiArticleReference) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(target) != 0);

    if (target.* != null) return error.DuplicateTargetArticleTag;
    target.* = parse_article_reference_tag(tag) catch return error.InvalidTargetArticleTag;
}

fn apply_source_event(tag: nip01_event.EventTag, source: *?WikiEventReference) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(source) != 0);

    if (tag.items.len < 2) return error.InvalidSourceEventTag;
    source.* = .{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidSourceEventTag,
        .relay_hint = parse_optional_url_item(tag, 2, error.InvalidSourceEventTag) catch {
            return error.InvalidSourceEventTag;
        },
    };
}

fn apply_base_revision(tag: nip01_event.EventTag, base: *?WikiEventReference) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(base) != 0);

    if (base.* != null) return error.DuplicateBaseRevisionTag;
    if (tag.items.len < 2) return error.InvalidBaseRevisionTag;
    base.* = .{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidBaseRevisionTag,
        .relay_hint = parse_optional_url_item(tag, 2, error.InvalidBaseRevisionTag) catch {
            return error.InvalidBaseRevisionTag;
        },
    };
}

fn apply_destination_pubkey(tag: nip01_event.EventTag, pubkey: *?[32]u8) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(pubkey) != 0);

    if (pubkey.* != null) return error.DuplicateDestinationPubkeyTag;
    if (tag.items.len != 2) return error.InvalidDestinationPubkeyTag;
    pubkey.* = parse_lower_hex_32(tag.items[1]) catch return error.InvalidDestinationPubkeyTag;
}

fn apply_redirect_target(tag: nip01_event.EventTag, target: *?WikiArticleReference) WikiError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(target) != 0);

    if (target.* != null) return error.DuplicateRedirectTargetTag;
    target.* = parse_article_reference_tag(tag) catch return error.InvalidRedirectTargetTag;
}

fn parse_article_reference_tag(tag: nip01_event.EventTag) error{InvalidTag}!WikiArticleReference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len < 2) return error.InvalidTag;
    var parsed = parse_article_coordinate_text(tag.items[1]) catch return error.InvalidTag;
    parsed.relay_hint = parse_optional_url_item(tag, 2, error.InvalidTag) catch return error.InvalidTag;
    return parsed;
}

fn parse_article_coordinate_text(text: []const u8) error{InvalidCoordinate}!WikiArticleReference {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidCoordinate;
    const second_colon = std.mem.indexOfScalarPos(u8, text, first_colon + 1, ':') orelse {
        return error.InvalidCoordinate;
    };
    const kind = std.fmt.parseUnsigned(u32, text[0..first_colon], 10) catch {
        return error.InvalidCoordinate;
    };
    if (kind != wiki_article_kind) return error.InvalidCoordinate;
    return .{
        .pubkey = parse_lower_hex_32(text[first_colon + 1 .. second_colon]) catch {
            return error.InvalidCoordinate;
        },
        .identifier = parse_nonempty_utf8(text[second_colon + 1 ..]) catch {
            return error.InvalidCoordinate;
        },
    };
}

fn parse_optional_url_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: anyerror,
) anyerror!?[]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len <= index) return null;
    if (tag.items[index].len == 0) return null;
    return parse_url(tag.items[index]) catch return invalid_error;
}

fn parse_optional_marker(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: anyerror,
) anyerror!?[]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len <= index) return null;
    if (tag.items[index].len == 0) return null;
    return parse_marker(tag.items[index]) catch return invalid_error;
}

fn parse_marker(text: []const u8) error{InvalidMarker}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    const parsed = parse_nonempty_utf8(text) catch return error.InvalidMarker;
    if (!std.mem.eql(u8, parsed, "fork") and !std.mem.eql(u8, parsed, "defer") and !std.mem.eql(u8, parsed, "source")) {
        return error.InvalidMarker;
    }
    return parsed;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    return url_with_scheme.parse_utf8(text, limits.tag_item_bytes_max);
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return lower_hex_32.parse(text);
}

test "NIP-54 extracts wiki article metadata and fork reference" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "wiki" } },
        .{ .items = &.{ "title", "Wiki" } },
        .{ .items = &.{ "a", "30818:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:wiki", "", "fork" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x54} ** 32,
        .pubkey = [_]u8{0x41} ** 32,
        .created_at = 1,
        .kind = wiki_article_kind,
        .tags = tags[0..],
        .content = "body",
        .sig = [_]u8{0x51} ** 64,
    };
    var forks: [1]WikiArticleReference = undefined;
    var defers: [1]WikiArticleReference = undefined;

    const info = try wiki_article_extract(&event, forks[0..], defers[0..]);

    try std.testing.expectEqualStrings("wiki", info.identifier);
    try std.testing.expectEqual(@as(u16, 1), info.fork_count);
}

test "NIP-54 extracts merge-request metadata" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "a", "30818:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:wiki" } },
        .{ .items = &.{ "p", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "e", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "", "source" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x55} ** 32,
        .pubkey = [_]u8{0x42} ** 32,
        .created_at = 2,
        .kind = wiki_merge_request_kind,
        .tags = tags[0..],
        .content = "merge me",
        .sig = [_]u8{0x52} ** 64,
    };

    const info = try wiki_merge_request_extract(&event);

    try std.testing.expectEqualStrings("wiki", info.target_article.identifier);
    try std.testing.expectEqualStrings("merge me", info.content);
}

test "NIP-54 normalizes ASCII wiki title into identifier" {
    var output: [32]u8 = undefined;

    const normalized = try wiki_normalize_identifier_ascii(output[0..], "What's Up?");

    try std.testing.expectEqualStrings("whats-up", normalized);
}
