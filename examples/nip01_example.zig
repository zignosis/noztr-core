const std = @import("std");
const noztr = @import("noztr");

test "NIP-01 example: parse event, match filter, and encode relay message" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const event_json =
        "{\"id\":\"4ca8d5f0ac83a3f6c7f7a75e8f2a9f1f66a11f88d0f8bcb6d78f35f6db6a5d1e\"," ++
        "\"pubkey\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
        "\"created_at\":1,\"kind\":1,\"tags\":[],\"content\":\"hello\"," ++
        "\"sig\":\"0000000000000000000000000000000000000000000000000000000000000000" ++
        "0000000000000000000000000000000000000000000000000000000000000000\"}";
    const event = try noztr.nip01_event.event_parse_json(event_json, arena.allocator());
    const filter = try noztr.nip01_filter.filter_parse_json("{\"kinds\":[1]}", arena.allocator());
    var output: [512]u8 = undefined;
    const relay_json = try noztr.nip01_message.relay_message_serialize_json(
        output[0..],
        &.{ .event = .{ .subscription_id = "sub", .event = event } },
    );

    try std.testing.expect(noztr.nip01_filter.filter_matches_event(&filter, &event));
    try std.testing.expect(std.mem.indexOf(u8, relay_json, "\"EVENT\"") != null);
}
