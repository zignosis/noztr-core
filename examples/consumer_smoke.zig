const std = @import("std");
const noztr = @import("noztr");

test "consumer package imports noztr and uses stable helpers" {
    try std.testing.expect(@TypeOf(noztr.nip05_identity.Address) == type);
    try std.testing.expect(@TypeOf(noztr.nip46_remote_signing.RemoteSigningMethod) == type);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const address = try noztr.nip05_identity.address_parse(
        "Alice@example.com",
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("alice", address.name);
    try std.testing.expectEqualStrings("example.com", address.domain);

    var url_buffer: [128]u8 = undefined;
    const lookup_url = try noztr.nip05_identity.address_compose_well_known_url(
        &url_buffer,
        &address,
    );
    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        lookup_url,
    );

    const parsed_method = try noztr.nip46_remote_signing.method_parse("connect");
    try std.testing.expectEqual(.connect, parsed_method);
}
