const std = @import("std");
const noztr = @import("noztr");

test "NIP-86 example: parse and serialize a relay-management request" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var output: [256]u8 = undefined;
    const input =
        "{\"method\":\"banpubkey\",\"params\":[\"0123456789abcdef0123456789abcdef" ++
        "0123456789abcdef0123456789abcdef\",\"spam\"]}";

    const request = try noztr.nip86_relay_management.request_parse_json(
        input,
        arena.allocator(),
    );
    const encoded = try noztr.nip86_relay_management.request_serialize_json(
        output[0..],
        request,
    );

    try std.testing.expect(request == .banpubkey);
    try std.testing.expectEqualStrings(input, encoded);
}
