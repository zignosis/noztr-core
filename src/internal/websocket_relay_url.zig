const std = @import("std");
const relay_origin = @import("relay_origin.zig");

pub fn parse_origin(text: []const u8, max_len: usize) error{InvalidRelayUrl}!relay_origin.WebsocketOrigin {
    std.debug.assert(max_len > 0);
    std.debug.assert(@sizeOf(relay_origin.WebsocketOrigin) > 0);

    if (text.len == 0 or text.len > max_len) return error.InvalidRelayUrl;
    if (has_forbidden_byte(text)) return error.InvalidRelayUrl;

    const origin = relay_origin.parse_websocket_origin(text) orelse return error.InvalidRelayUrl;
    if (origin.port == 0) return error.InvalidRelayUrl;
    return origin;
}

fn has_forbidden_byte(text: []const u8) bool {
    for (text) |byte| {
        if (byte <= 0x20) return true;
        if (byte == '\\') return true;
    }
    return false;
}

test "websocket relay URL parser rejects whitespace and invalid scheme" {
    try std.testing.expectError(error.InvalidRelayUrl, parse_origin("wss://relay.example.com bad", 128));
    try std.testing.expectError(error.InvalidRelayUrl, parse_origin("https://relay.example.com", 128));
}

test "websocket relay URL parser accepts canonical relay origin" {
    const origin = try parse_origin("wss://relay.example.com/path", 128);
    try std.testing.expectEqualStrings("wss", origin.scheme);
    try std.testing.expectEqualStrings("relay.example.com", origin.host);
    try std.testing.expectEqual(@as(u16, 443), origin.port);
    try std.testing.expectEqualStrings("/path", origin.path);
}
