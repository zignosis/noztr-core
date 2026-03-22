const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const url_with_host = @import("internal/url_with_host.zig");

pub const ExternalIdError = error{
    InvalidKind,
    InvalidValue,
    InvalidHint,
    InvalidTag,
    BufferTooSmall,
};

/// Canonical parsed external-id kind for NIP-73 content references.
pub const ExternalIdKind = union(enum) {
    web,
    hashtag,
    geo,
    iso3166,
    isbn,
    isan,
    doi,
    podcast_feed,
    podcast_episode,
    podcast_publisher,
    blockchain_tx: []const u8,
    blockchain_address: []const u8,

    pub fn eql(left: ExternalIdKind, right: ExternalIdKind) bool {
        std.debug.assert(@sizeOf(ExternalIdKind) > 0);
        std.debug.assert(@sizeOf(ExternalIdKind) > 0);

        return switch (left) {
            .web => right == .web,
            .hashtag => right == .hashtag,
            .geo => right == .geo,
            .iso3166 => right == .iso3166,
            .isbn => right == .isbn,
            .isan => right == .isan,
            .doi => right == .doi,
            .podcast_feed => right == .podcast_feed,
            .podcast_episode => right == .podcast_episode,
            .podcast_publisher => right == .podcast_publisher,
            .blockchain_tx => |left_chain| switch (right) {
                .blockchain_tx => |right_chain| std.mem.eql(u8, left_chain, right_chain),
                else => false,
            },
            .blockchain_address => |left_chain| switch (right) {
                .blockchain_address => |right_chain| std.mem.eql(u8, left_chain, right_chain),
                else => false,
            },
        };
    }
};

/// Parsed NIP-73 external content id with optional hint URL.
pub const ExternalId = struct {
    kind: ExternalIdKind,
    value: []const u8,
    hint: ?[]const u8 = null,
};

/// Fixed-capacity `i` or `k` tag builder for NIP-73 helpers.
pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    item_count: u8 = 0,
    kind_storage: [limits.tag_item_bytes_max]u8 = undefined,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Parses and validates a bounded NIP-73 external content id plus optional hint URL.
pub fn external_id_parse(value: []const u8, hint: ?[]const u8) ExternalIdError!ExternalId {
    std.debug.assert(value.len <= limits.tag_item_bytes_max);
    std.debug.assert(value.len <= limits.content_bytes_max);

    const parsed_value = try parse_nonempty_utf8(value);
    if (hint) |text| {
        _ = parse_url(text) catch return error.InvalidHint;
    }
    return .{
        .kind = try detect_kind(parsed_value),
        .value = parsed_value,
        .hint = hint,
    };
}

/// Parses a NIP-73 `k`/`K` kind token into the canonical kind model.
pub fn external_kind_parse(text: []const u8) ExternalIdError!ExternalIdKind {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    const parsed = parse_nonempty_utf8(text) catch return error.InvalidKind;
    if (std.mem.eql(u8, parsed, "web")) return .web;
    if (std.mem.eql(u8, parsed, "#")) return .hashtag;
    if (std.mem.eql(u8, parsed, "geo")) return .geo;
    if (std.mem.eql(u8, parsed, "iso3166")) return .iso3166;
    if (std.mem.eql(u8, parsed, "isbn")) return .isbn;
    if (std.mem.eql(u8, parsed, "isan")) return .isan;
    if (std.mem.eql(u8, parsed, "doi")) return .doi;
    if (std.mem.eql(u8, parsed, "podcast:guid")) return .podcast_feed;
    if (std.mem.eql(u8, parsed, "podcast:item:guid")) return .podcast_episode;
    if (std.mem.eql(u8, parsed, "podcast:publisher:guid")) return .podcast_publisher;
    if (try parse_blockchain_kind(parsed, ":tx:")) |chain| return .{ .blockchain_tx = chain };
    if (try parse_blockchain_kind(parsed, ":address:")) |chain| {
        return .{ .blockchain_address = chain };
    }
    return error.InvalidKind;
}

/// Serializes a canonical NIP-73 kind token into caller-owned storage.
pub fn external_kind_text(output: []u8, kind: ExternalIdKind) ExternalIdError![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(ExternalIdKind) > 0);

    return switch (kind) {
        .web => "web",
        .hashtag => "#",
        .geo => "geo",
        .iso3166 => "iso3166",
        .isbn => "isbn",
        .isan => "isan",
        .doi => "doi",
        .podcast_feed => "podcast:guid",
        .podcast_episode => "podcast:item:guid",
        .podcast_publisher => "podcast:publisher:guid",
        .blockchain_tx => |chain| std.fmt.bufPrint(output, "{s}:tx", .{chain}) catch {
            return error.BufferTooSmall;
        },
        .blockchain_address => |chain| std.fmt.bufPrint(output, "{s}:address", .{chain}) catch {
            return error.BufferTooSmall;
        },
    };
}

/// Returns whether the value matches the supplied NIP-73 kind token.
pub fn external_id_matches_kind(kind_text: []const u8, value: []const u8) bool {
    std.debug.assert(kind_text.len <= limits.tag_item_bytes_max);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    const kind = external_kind_parse(kind_text) catch return false;
    const parsed = external_id_parse(value, null) catch return false;
    return kind.eql(parsed.kind);
}

/// Builds a bounded canonical NIP-73 `i` tag.
pub fn external_id_build_i_tag(
    output: *BuiltTag,
    external_id: *const ExternalId,
) ExternalIdError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(external_id) != 0);

    const parsed = try external_id_parse(external_id.value, external_id.hint);
    if (!external_id.kind.eql(parsed.kind)) {
        return error.InvalidTag;
    }
    output.items[0] = "i";
    output.items[1] = external_id.value;
    output.item_count = 2;
    if (external_id.hint) |hint| {
        output.items[2] = hint;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a bounded canonical NIP-73 `k` tag.
pub fn external_id_build_k_tag(
    output: *BuiltTag,
    kind: ExternalIdKind,
) ExternalIdError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@sizeOf(ExternalIdKind) > 0);

    output.items[0] = "k";
    output.items[1] = try external_kind_text(output.kind_storage[0..], kind);
    output.item_count = 2;
    return output.as_event_tag();
}

fn detect_kind(value: []const u8) ExternalIdError!ExternalIdKind {
    std.debug.assert(value.len <= limits.tag_item_bytes_max);
    std.debug.assert(value.len <= limits.content_bytes_max);

    if (std.mem.startsWith(u8, value, "#") and value.len > 1) return .hashtag;
    if (std.mem.startsWith(u8, value, "geo:") and value.len > 4) return .geo;
    if (std.mem.startsWith(u8, value, "iso3166:") and value.len > 8) return .iso3166;
    if (std.mem.startsWith(u8, value, "isbn:") and value.len > 5) return .isbn;
    if (std.mem.startsWith(u8, value, "podcast:guid:") and value.len > 13) return .podcast_feed;
    if (std.mem.startsWith(u8, value, "podcast:item:guid:") and value.len > 18) {
        return .podcast_episode;
    }
    if (std.mem.startsWith(u8, value, "podcast:publisher:guid:") and value.len > 23) {
        return .podcast_publisher;
    }
    if (std.mem.startsWith(u8, value, "isan:") and value.len > 5) return .isan;
    if (std.mem.startsWith(u8, value, "doi:") and value.len > 4) return .doi;
    if (try parse_blockchain_value(value, ":tx:")) |chain| return .{ .blockchain_tx = chain };
    if (try parse_blockchain_value(value, ":address:")) |chain| {
        return .{ .blockchain_address = chain };
    }
    if (is_url_shaped(value)) return .web;
    return error.InvalidValue;
}

fn parse_blockchain_kind(text: []const u8, suffix: []const u8) ExternalIdError!?[]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(suffix.len > 0);

    if (!std.mem.endsWith(u8, text, suffix[0 .. suffix.len - 1])) return null;
    const chain = text[0 .. text.len - (suffix.len - 1)];
    try validate_chain_token(chain);
    return chain;
}

fn parse_blockchain_value(value: []const u8, separator: []const u8) ExternalIdError!?[]const u8 {
    std.debug.assert(value.len <= limits.tag_item_bytes_max);
    std.debug.assert(separator.len > 0);

    const marker = std.mem.indexOf(u8, value, separator) orelse return null;
    if (marker == 0) return error.InvalidValue;
    if (marker + separator.len >= value.len) return error.InvalidValue;

    const prefix = value[0..marker];
    const chain = if (std.mem.indexOfScalar(u8, prefix, ':')) |index| prefix[0..index] else prefix;
    validate_chain_token(chain) catch return error.InvalidValue;
    return chain;
}

fn validate_chain_token(chain: []const u8) ExternalIdError!void {
    std.debug.assert(chain.len <= limits.tag_item_bytes_max);
    std.debug.assert(chain.len <= limits.content_bytes_max);

    if (chain.len == 0) return error.InvalidKind;
    for (chain) |byte| {
        if (std.ascii.isLower(byte) or std.ascii.isDigit(byte)) continue;
        return error.InvalidKind;
    }
}

fn parse_nonempty_utf8(text: []const u8) ExternalIdError![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidValue;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidValue;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    return url_with_host.parse(text, limits.tag_item_bytes_max);
}

fn is_url_shaped(text: []const u8) bool {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    _ = parse_url(text) catch return false;
    return true;
}

test "external id parse detects fixed and blockchain kinds" {
    const web = try external_id_parse("https://example.com/post#ignored", null);
    const podcast = try external_id_parse("podcast:guid:feed-guid", "https://fountain.fm/show/1");
    const ethereum_tx = try external_id_parse(
        "ethereum:1:tx:0x98f7812be496f97f80e2e98d66358d1fc733cf34176a8356d171ea7fbbe97ccd",
        null,
    );

    try std.testing.expect(web.kind == .web);
    try std.testing.expectEqualStrings("https://fountain.fm/show/1", podcast.hint.?);
    try std.testing.expectEqualStrings("ethereum", ethereum_tx.kind.blockchain_tx);
}

test "external kind parse format and match stay deterministic" {
    var buffer: [64]u8 = undefined;
    const bitcoin_tx = try external_kind_parse("bitcoin:tx");
    const ethereum_addr = try external_kind_parse("ethereum:address");

    try std.testing.expectEqualStrings("bitcoin:tx", try external_kind_text(buffer[0..], bitcoin_tx));
    try std.testing.expectEqualStrings(
        "ethereum:address",
        try external_kind_text(buffer[0..], ethereum_addr),
    );
    try std.testing.expect(
        external_id_matches_kind(
            "bitcoin:tx",
            "bitcoin:tx:a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d",
        ),
    );
    try std.testing.expect(
        !external_id_matches_kind(
            "podcast:item:guid",
            "podcast:guid:c90e609a-df1e-596a-bd5e-57bcc8aad6cc",
        ),
    );
}

test "external id tag builders emit canonical tag names" {
    var built_i: BuiltTag = .{};
    var built_k: BuiltTag = .{};
    const external_id = ExternalId{
        .kind = .podcast_episode,
        .value = "podcast:item:guid:d98d189b-dc7b-45b1-8720-d4b98690f31f",
        .hint = "https://fountain.fm/episode/z1y9TMQRuqXl2awyrQxg",
    };

    const i_tag = try external_id_build_i_tag(&built_i, &external_id);
    const k_tag = try external_id_build_k_tag(&built_k, external_id.kind);

    try std.testing.expectEqualStrings("i", i_tag.items[0]);
    try std.testing.expectEqualStrings(external_id.value, i_tag.items[1]);
    try std.testing.expectEqualStrings(external_id.hint.?, i_tag.items[2]);
    try std.testing.expectEqualStrings("k", k_tag.items[0]);
    try std.testing.expectEqualStrings("podcast:item:guid", k_tag.items[1]);
}

test "external id parse rejects malformed value hint and kind" {
    try std.testing.expectError(error.InvalidValue, external_id_parse("", null));
    try std.testing.expectError(
        error.InvalidHint,
        external_id_parse("isbn:9780765382030", "notaurl"),
    );
    try std.testing.expectError(error.InvalidKind, external_kind_parse("ethereum:1:tx"));
    try std.testing.expectError(error.InvalidValue, external_id_parse("bitcoin::tx:", null));
    try std.testing.expectError(error.InvalidValue, external_id_parse("Bitcoin:tx:abcd", null));

    var built: BuiltTag = .{};
    const mismatched = ExternalId{
        .kind = .podcast_episode,
        .value = "podcast:guid:feed-guid",
    };
    try std.testing.expectError(error.InvalidTag, external_id_build_i_tag(&built, &mismatched));
}
