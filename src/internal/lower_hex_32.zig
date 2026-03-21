const std = @import("std");
const limits = @import("../limits.zig");

pub fn validate(text: []const u8) error{InvalidHex}!void {
    std.debug.assert(limits.pubkey_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length <= limits.tag_item_bytes_max);

    if (text.len != limits.pubkey_hex_length) return error.InvalidHex;
    for (text) |byte| {
        if (byte >= '0' and byte <= '9') continue;
        if (byte >= 'a' and byte <= 'f') continue;
        return error.InvalidHex;
    }
}

pub fn parse(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(limits.pubkey_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length <= limits.tag_item_bytes_max);

    try validate(text);
    var out: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&out, text) catch return error.InvalidHex;
    return out;
}

test "internal lower hex parser rejects non-canonical and overlong text" {
    try std.testing.expectError(error.InvalidHex, parse("aa"));
    try std.testing.expectError(
        error.InvalidHex,
        parse("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    );
}

test "internal lower hex parser accepts canonical lowercase text" {
    const parsed = try parse("00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff");
    try std.testing.expectEqual(@as(u8, 0x00), parsed[0]);
    try std.testing.expectEqual(@as(u8, 0xff), parsed[31]);
}
