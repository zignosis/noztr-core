const std = @import("std");

pub fn parse_utf8(text: []const u8, max_len: usize) error{InvalidUrl}![]const u8 {
    std.debug.assert(max_len > 0);

    if (text.len == 0) return error.InvalidUrl;
    if (text.len > max_len) return error.InvalidUrl;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUrl;

    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    return text;
}

test "scheme-only URL parser rejects empty and schemeless text" {
    try std.testing.expectError(error.InvalidUrl, parse_utf8("", 128));
    try std.testing.expectError(error.InvalidUrl, parse_utf8("example.com/path", 128));
}

test "scheme-only URL parser accepts mailto and custom schemes" {
    try std.testing.expectEqualStrings("mailto:test@example.com", try parse_utf8("mailto:test@example.com", 128));
    try std.testing.expectEqualStrings("nostr:note1xyz", try parse_utf8("nostr:note1xyz", 128));
}
