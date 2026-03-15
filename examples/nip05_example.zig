const std = @import("std");
const noztr = @import("noztr");

test "NIP-05 example: parse and format an address" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var output: [64]u8 = undefined;

    const address = try noztr.nip05_identity.address_parse(
        "alice@example.com",
        arena.allocator(),
    );
    const text = try noztr.nip05_identity.address_format(output[0..], &address);

    try std.testing.expectEqualStrings("alice", address.name);
    try std.testing.expectEqualStrings("alice@example.com", text);
}
