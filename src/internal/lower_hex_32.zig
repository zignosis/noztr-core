const std = @import("std");
const limits = @import("../limits.zig");

pub fn parse(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(limits.pubkey_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length <= limits.tag_item_bytes_max);

    if (text.len != limits.pubkey_hex_length) return error.InvalidHex;

    var out: [32]u8 = undefined;
    var index: usize = 0;
    while (index < out.len) : (index += 1) {
        const start = index * 2;
        out[index] = std.fmt.parseUnsigned(u8, text[start .. start + 2], 16) catch {
            return error.InvalidHex;
        };
    }
    if (!std.mem.eql(u8, &std.fmt.bytesToHex(out, .lower), text)) return error.InvalidHex;
    return out;
}

test "internal lower hex parser rejects non-canonical and overlong text" {
    try std.testing.expectError(error.InvalidHex, parse("aa"));
    try std.testing.expectError(
        error.InvalidHex,
        parse("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    );
}
