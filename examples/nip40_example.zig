const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-40 example: read expiration metadata and compare against now" {
    const expiration_items = [_][]const u8{ "expiration", "1700000005" };
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = expiration_items[0..] }};
    const event = common.simple_event(1, [_]u8{0x33} ** 32, "", tags[0..]);

    const expiration = try noztr.nip40_expire.event_expiration_unix_seconds(&event);
    const expired = try noztr.nip40_expire.event_is_expired_at(&event, 1_700_000_006);

    try std.testing.expectEqual(@as(?u64, 1_700_000_005), expiration);
    try std.testing.expect(expired);
}
