const std = @import("std");
const noztr = @import("noztr");

test "recipe: identity lookup and bunker discovery stay obvious" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const address = try noztr.nip05_identity.address_parse(
        "alice@example.com",
        arena.allocator(),
    );
    var lookup_url_buffer: [128]u8 = undefined;
    const lookup_url = try noztr.nip05_identity.address_compose_well_known_url(
        lookup_url_buffer[0..],
        &address,
    );

    const document =
        "{\"names\":{\"_\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
        "\"alice\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"}," ++
        "\"relays\":{\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\":" ++
        "[\"wss://relay.one\"]},\"nip46\":{\"relays\":[\"wss://relay.one\"]," ++
        "\"nostrconnect_url\":\"https://bunker.example/<nostrconnect>\"}}";

    const profile = try noztr.nip05_identity.profile_parse_json(
        &address,
        document,
        arena.allocator(),
    );
    const discovery = try noztr.nip46_remote_signing.discovery_parse_well_known(
        document,
        arena.allocator(),
    );

    try std.testing.expectEqualStrings(
        "https://example.com/.well-known/nostr.json?name=alice",
        lookup_url,
    );
    try std.testing.expectEqual(@as(usize, 1), profile.relays.len);
    try std.testing.expectEqual(@as(usize, 1), discovery.relays.len);
    try std.testing.expectEqualStrings("wss://relay.one", discovery.relays[0]);
}
