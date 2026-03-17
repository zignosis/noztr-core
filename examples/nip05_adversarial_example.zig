const std = @import("std");
const noztr = @import("noztr");

test "NIP-05 adversarial example: malformed matched entries stay typed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const address = try noztr.nip05_identity.address_parse(
        "example.com",
        arena.allocator(),
    );
    const bad_pubkey_json =
        \\{"names":{"_":"NPUB1NOTHEX"}}
    ;
    const bad_relay_json =
        "{\"names\":{\"_\":\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\"}," ++
        "\"relays\":{\"68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272\":[" ++
        "\"https://not-a-websocket.example.com\"]}}";
    const expected_pubkey = [_]u8{
        0x68, 0xd8, 0x11, 0x65, 0x91, 0x81, 0x00, 0xb7,
        0xda, 0x43, 0xfc, 0x28, 0xf7, 0xd1, 0xfc, 0x12,
        0x55, 0x44, 0x66, 0xe1, 0x11, 0x58, 0x86, 0xb9,
        0xe7, 0xbb, 0x32, 0x6f, 0x65, 0xec, 0x42, 0x72,
    };

    try std.testing.expectError(
        error.InvalidPubkey,
        noztr.nip05_identity.profile_parse_json(
            &address,
            bad_pubkey_json,
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.InvalidRelayUrl,
        noztr.nip05_identity.profile_parse_json(
            &address,
            bad_relay_json,
            arena.allocator(),
        ),
    );
    try std.testing.expectEqual(
        false,
        try noztr.nip05_identity.profile_verify_json(
            &expected_pubkey,
            &address,
            "{\"names\":{}}",
            arena.allocator(),
        ),
    );
}
