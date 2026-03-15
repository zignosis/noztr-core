const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-57 example: extract bounded zap-request tags" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "p", "1111111111111111111111111111111111111111111111111111111111111111" } },
        .{ .items = &.{ "relays", "wss://relay.one" } },
        .{ .items = &.{ "amount", "1000" } },
    };
    const event = common.simple_event(9734, [_]u8{0x57} ** 32, "", tags[0..]);
    var relays: [2][]const u8 = undefined;

    const request = try noztr.nip57_zaps.zap_request_extract(&event, relays[0..]);

    try std.testing.expectEqual(@as(usize, 1), request.receipt_relays.len);
    try std.testing.expectEqual(@as(?u64, 1000), request.amount_msats);
}
