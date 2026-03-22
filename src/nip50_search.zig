const std = @import("std");
const limits = @import("limits.zig");

/// Typed bounded search-validation failures.
pub const SearchError = error{InvalidSearchValue};

/// Supported NIP-50 strict extension token keys.
pub const SearchTokenKey = enum {
    include,
    domain,
    language,
    sentiment,
    nsfw,
};

/// Parsed strict extension token.
///
/// Lifetime and ownership:
/// - `value` borrows from the `search` input buffer.
/// - Keep the input slice alive while using parsed tokens.
pub const SearchToken = struct {
    key: SearchTokenKey,
    value: []const u8,
};

/// Validates bounded NIP-50 search-field size and UTF-8 shape.
pub fn search_field_validate(value: []const u8) SearchError!void {
    std.debug.assert(limits.nip50_search_field_bytes_max > 0);
    std.debug.assert(limits.nip50_search_field_bytes_max <= limits.tag_item_bytes_max);

    if (value.len > limits.nip50_search_field_bytes_max) {
        return error.InvalidSearchValue;
    }
    if (!std.unicode.utf8ValidateSlice(value)) {
        return error.InvalidSearchValue;
    }
}

/// Parses supported strict `key:value` extension tokens from a `search` field.
///
/// Token policy:
/// - Whitespace-separated tokens are scanned left-to-right.
/// - Plain terms and unsupported `key:value` tokens are ignored.
/// - Supported `key:value` tokens are emitted in input order.
pub fn search_tokens_parse(
    value: []const u8,
    out_tokens: []SearchToken,
) error{ BufferTooSmall, InvalidSearchValue }!u16 {
    std.debug.assert(out_tokens.len <= std.math.maxInt(u16));
    std.debug.assert(limits.nip50_search_field_bytes_max > 0);

    try search_field_validate(value);

    var count: u16 = 0;
    var token_index: usize = 0;
    while (token_next(value, &token_index)) |token| {
        const parsed = strict_token_parse(token);
        if (parsed) |supported_token| {
            if (count == out_tokens.len) {
                return error.BufferTooSmall;
            }
            out_tokens[count] = supported_token;
            count += 1;
        }
    }

    return count;
}

fn strict_token_parse(token: []const u8) ?SearchToken {
    std.debug.assert(token.len > 0);
    std.debug.assert(token.len <= limits.nip50_search_field_bytes_max);

    const first_colon = std.mem.indexOfScalar(u8, token, ':') orelse return null;
    if (first_colon == 0) {
        return null;
    }
    const key_slice = token[0..first_colon];
    const token_key = search_token_key_parse(key_slice) orelse return null;

    if (first_colon + 1 >= token.len) {
        return null;
    }
    if (std.mem.indexOfScalarPos(u8, token, first_colon + 1, ':') != null) {
        return null;
    }

    const value_slice = token[first_colon + 1 ..];
    return .{ .key = token_key, .value = value_slice };
}

fn search_token_key_parse(key: []const u8) ?SearchTokenKey {
    std.debug.assert(key.len > 0);
    std.debug.assert(key.len <= limits.nip50_search_field_bytes_max);

    if (std.mem.eql(u8, key, "include")) {
        return .include;
    }
    if (std.mem.eql(u8, key, "domain")) {
        return .domain;
    }
    if (std.mem.eql(u8, key, "language")) {
        return .language;
    }
    if (std.mem.eql(u8, key, "sentiment")) {
        return .sentiment;
    }
    if (std.mem.eql(u8, key, "nsfw")) {
        return .nsfw;
    }
    return null;
}

fn token_next(value: []const u8, index: *usize) ?[]const u8 {
    std.debug.assert(index.* <= value.len);
    std.debug.assert(value.len <= limits.nip50_search_field_bytes_max);

    while (index.* < value.len) {
        if (!std.ascii.isWhitespace(value[index.*])) {
            break;
        }
        index.* += 1;
    }
    if (index.* >= value.len) {
        return null;
    }

    const start = index.*;
    while (index.* < value.len) {
        if (std.ascii.isWhitespace(value[index.*])) {
            break;
        }
        index.* += 1;
    }
    return value[start..index.*];
}

test "search field validate accepts plain UTF-8 query" {
    try search_field_validate("best nostr apps");
}

test "search field validate accepts supported strict tokens" {
    try search_field_validate("nostr include:spam domain:nostr.com");
}

test "search token parse emits supported tokens and ignores unsupported" {
    var out_tokens: [4]SearchToken = undefined;
    const count = try search_tokens_parse(
        "  hello  include:spam unknown:value\nnsfw:true  ",
        out_tokens[0..],
    );

    try std.testing.expectEqual(@as(u16, 2), count);
    try std.testing.expect(out_tokens[0].key == .include);
    try std.testing.expectEqualStrings("spam", out_tokens[0].value);
    try std.testing.expect(out_tokens[1].key == .nsfw);
    try std.testing.expectEqualStrings("true", out_tokens[1].value);
}

test "search field validate accepts malformed extension-like tokens as raw search text" {
    try search_field_validate("include:");
    try search_field_validate(":spam");
    try search_field_validate("language:en:us");
}

test "search field validate rejects invalid UTF-8" {
    const invalid_utf8 = [_]u8{ 0xC3, 0x28 };
    try std.testing.expectError(error.InvalidSearchValue, search_field_validate(invalid_utf8[0..]));
}

test "search token parse ignores malformed supported strict tokens" {
    var out_tokens: [2]SearchToken = undefined;
    const count = try search_tokens_parse("include: language:en:us domain:nostr.com", out_tokens[0..]);

    try std.testing.expectEqual(@as(u16, 1), count);
    try std.testing.expect(out_tokens[0].key == .domain);
    try std.testing.expectEqualStrings("nostr.com", out_tokens[0].value);
}

test "search field validate ignores unsupported token with multiple colons" {
    try search_field_validate("hello custom:alpha:beta include:spam");
}

test "search token parse ignores unsupported token with multiple colons" {
    var out_tokens: [2]SearchToken = undefined;
    const count = try search_tokens_parse(
        "custom:alpha:beta include:spam",
        out_tokens[0..],
    );

    try std.testing.expectEqual(@as(u16, 1), count);
    try std.testing.expect(out_tokens[0].key == .include);
    try std.testing.expectEqualStrings("spam", out_tokens[0].value);
}

test "search token parse returns buffer too small when output overflows" {
    var out_tokens: [1]SearchToken = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        search_tokens_parse("include:spam domain:example.com", out_tokens[0..]),
    );
}
