const std = @import("std");
const noztr = @import("noztr");

test "NIP-11 example: parse the bounded relay information subset" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const document =
        "{\"name\":\"relay.one\",\"pubkey\":\"0123456789abcdef0123456789abcdef" ++
        "0123456789abcdef0123456789abcdef\",\"supported_nips\":[1,11,42]," ++
        "\"limitation\":{\"max_message_length\":65536}}";

    const parsed = try noztr.nip11.nip11_parse_document(document, arena.allocator());

    try std.testing.expectEqualStrings("relay.one", parsed.name.?);
    try std.testing.expectEqual(@as(usize, 3), parsed.supported_nips.len);
}
