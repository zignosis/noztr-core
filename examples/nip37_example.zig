const std = @import("std");
const noztr = @import("noztr");

test "NIP-37 example: encrypt validated draft JSON and parse the wrap metadata" {
    const private_key = [_]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
    };
    var pubkey: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(
        pubkey[0..],
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
    );
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var encrypted: [noztr.limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const draft_json = "{\"kind\":1,\"tags\":[],\"content\":\"draft\"}";
    const ciphertext = try noztr.nip37_drafts.draft_wrap_encrypt_json(
        encrypted[0..],
        &private_key,
        &pubkey,
        draft_json,
        arena.allocator(),
    );
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "draft-1" } },
        .{ .items = &.{ "k", "1" } },
    };
    const event = noztr.nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 31234,
        .created_at = 1,
        .content = ciphertext,
        .tags = tags[0..],
    };

    const info = try noztr.nip37_drafts.draft_wrap_parse(&event);

    try std.testing.expectEqualStrings("draft-1", info.identifier);
    try std.testing.expect(!info.is_deleted);
}
