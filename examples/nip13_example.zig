const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-13 example: canonical PoW check verifies the event id first" {
    const nonce_items = [_][]const u8{ "nonce", "1", "0" };
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = nonce_items[0..] }};
    var event = common.simple_event(1, [_]u8{0x55} ** 32, "pow", tags[0..]);
    try common.finalize_event_id(&event);

    const meets = try noztr.pow_meets_difficulty_verified_id(&event, 0);

    try std.testing.expect(meets);
    try std.testing.expectEqual(@as(u16, 0), try noztr.nip13_pow.pow_extract_nonce_target(&event));
}
