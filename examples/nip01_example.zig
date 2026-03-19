const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-01 example: canonical event lifecycle stays explicit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const secret_key = [_]u8{0x11} ** 32;
    const pubkey = try common.derive_public_key(&secret_key);
    var event = common.simple_event(1, pubkey, "hello", &.{});
    var event_json_output: [512]u8 = undefined;
    var preimage_output: [256]u8 = undefined;
    var relay_output: [640]u8 = undefined;
    var req_output: [640]u8 = undefined;
    var req_filters: [noztr.limits.message_filters_max]noztr.nip01_filter.Filter = undefined;

    try common.sign_event(&secret_key, &event);
    const event_json = try common.simple_event_json(event_json_output[0..], &event);
    const canonical_json = try noztr.nip01_event.event_serialize_canonical_json(
        preimage_output[0..],
        &event,
    );
    const reparsed = try noztr.nip01_event.event_parse_json(event_json, arena.allocator());
    const computed_id = try noztr.nip01_event.event_compute_id_checked(&reparsed);
    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"kinds\":[1],\"&t\":[\"nostr\",\"zig\"],\"#t\":[\"zig\",\"library\"]}",
        arena.allocator(),
    );
    const relay_json = try noztr.nip01_message.relay_message_serialize_json(
        relay_output[0..],
        &.{ .event = .{ .subscription_id = "sub", .event = reparsed } },
    );
    req_filters[0] = filter;
    const req_json = try noztr.nip01_message.client_message_serialize_json(
        req_output[0..],
        &.{ .req = .{
            .subscription_id = "sub",
            .filters = req_filters,
            .filters_count = 1,
        } },
    );

    try std.testing.expectEqualSlices(u8, event.id[0..], reparsed.id[0..]);
    try std.testing.expectEqualSlices(
        u8,
        event.id[0..],
        computed_id[0..],
    );
    try noztr.nip01_event.event_verify_id(&reparsed);
    try noztr.nip01_event.event_verify(&reparsed);
    try std.testing.expect(!noztr.nip01_filter.filter_matches_event(&filter, &reparsed));
    try std.testing.expect(std.mem.startsWith(u8, event_json, "{\"id\":\""));
    try std.testing.expect(std.mem.startsWith(u8, canonical_json, "[0,\""));
    try std.testing.expect(std.mem.indexOf(u8, relay_json, "\"EVENT\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, req_json, "\"&t\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, req_json, "\"#t\"") != null);
}
