const std = @import("std");
const noztr = @import("noztr");

test "NIP-47 adversarial example: malformed requests and notifications stay typed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidParams,
        noztr.nip47_wallet_connect.request_parse_json(
            "{\"method\":\"pay_invoice\",\"params\":{\"invoice\":123}}",
            arena.allocator(),
        ),
    );
    try std.testing.expectError(
        error.InvalidNotification,
        noztr.nip47_wallet_connect.notification_parse_json(
            "{\"notification_type\":\"payment_received\",\"notification\":{" ++
                "\"type\":\"outgoing\",\"invoice\":\"lnbc1\",\"preimage\":\"aa\"," ++
                "\"payment_hash\":\"bb\",\"amount\":1,\"fees_paid\":1," ++
                "\"created_at\":1,\"settled_at\":2}}",
            arena.allocator(),
        ),
    );
}
