const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-65 example: extract relay permissions from a kind-10002 event" {
    const relay_items = [_][]const u8{ "r", "wss://relay.one", "read" };
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = relay_items[0..] }};
    const event = common.simple_event(10002, [_]u8{0x66} ** 32, "", tags[0..]);
    var permissions: [1]noztr.nip65_relays.RelayPermission = undefined;

    const count = try noztr.nip65_relays.relay_list_extract(&event, permissions[0..]);

    try std.testing.expectEqual(@as(u16, 1), count);
    try std.testing.expectEqual(.read, permissions[0].marker);
}
