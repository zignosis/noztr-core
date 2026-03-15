const std = @import("std");
const noztr = @import("noztr");

test "NIP-47 example: parse a pairing URI and typed get_info flow" {
    var relays: [2][]const u8 = undefined;
    var request_output: [128]u8 = undefined;
    var response_output: [256]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const uri = try noztr.nip47_wallet_connect.connection_uri_parse(
        "nostr+walletconnect://0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
            "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two" ++
            "&secret=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        relays[0..],
        arena.allocator(),
    );
    const request = try noztr.nip47_wallet_connect.request_parse_json(
        "{\"method\":\"get_info\",\"params\":{}}",
        arena.allocator(),
    );
    const response = try noztr.nip47_wallet_connect.response_parse_json(
        "{\"result_type\":\"get_info\",\"error\":null,\"result\":{" ++
            "\"alias\":\"wallet\",\"methods\":[\"pay_invoice\",\"get_info\"]," ++
            "\"notifications\":[\"payment_received\"]}}",
        arena.allocator(),
    );

    const request_json = try noztr.nip47_wallet_connect.request_serialize_json(
        request_output[0..],
        request,
    );
    const response_json = try noztr.nip47_wallet_connect.response_serialize_json(
        response_output[0..],
        response,
    );

    try std.testing.expectEqualStrings("wss://relay.one", uri.relays[0]);
    try std.testing.expectEqualStrings("wss://relay.two", uri.relays[1]);
    try std.testing.expectEqualStrings("{\"method\":\"get_info\",\"params\":{}}", request_json);
    switch (response) {
        .get_info => |outcome| switch (outcome) {
            .result => |result| {
                try std.testing.expectEqualStrings("wallet", result.alias.?);
                try std.testing.expectEqualStrings("pay_invoice", result.methods[0]);
                try std.testing.expectEqualStrings(
                    "payment_received",
                    result.notifications[0],
                );
            },
            .err => return error.TestUnexpectedResult,
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expect(
        std.mem.indexOf(u8, response_json, "\"notifications\":[\"payment_received\"]") != null,
    );
}
