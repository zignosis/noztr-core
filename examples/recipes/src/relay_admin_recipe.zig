const std = @import("std");
const noztr = @import("noztr");

test "recipe: relay admin requests and responses stay typed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const request_json =
        "{\"method\":\"banpubkey\",\"params\":[\"0123456789abcdef0123456789abcdef" ++
        "0123456789abcdef0123456789abcdef\",\"spam\"]}";
    const request = try noztr.nip86_relay_management.request_parse_json(
        request_json,
        arena.allocator(),
    );
    var request_output: [256]u8 = undefined;
    const encoded_request = try noztr.nip86_relay_management.request_serialize_json(
        request_output[0..],
        request,
    );

    var pubkeys: [1]noztr.nip86_relay_management.PubkeyReason = undefined;
    var methods: [1][]const u8 = undefined;
    var events: [1]noztr.nip86_relay_management.EventIdReason = undefined;
    var kinds: [1]u32 = undefined;
    var ips: [1]noztr.nip86_relay_management.IpReason = undefined;
    const response = try noztr.nip86_relay_management.response_parse_json(
        "{\"result\":true,\"error\":null}",
        .banpubkey,
        methods[0..],
        pubkeys[0..],
        events[0..],
        kinds[0..],
        ips[0..],
        arena.allocator(),
    );

    try std.testing.expect(request == .banpubkey);
    try std.testing.expectEqualStrings(request_json, encoded_request);
    try std.testing.expect(response.result == .ack);
}
