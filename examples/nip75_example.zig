const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-75 example: extract and build zap-goal tags" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relays", "wss://relay.one" } },
        .{ .items = &.{ "amount", "21000" } },
    };
    const event = common.simple_event(
        noztr.nip75_zap_goals.goal_kind,
        [_]u8{0x75} ** 32,
        "Support the project",
        tags[0..],
    );
    var relays: [1][]const u8 = undefined;
    const info = try noztr.nip75_zap_goals.goal_extract(&event, relays[0..]);

    var built: noztr.nip75_zap_goals.BuiltTag = .{};
    const amount = try noztr.nip75_zap_goals.goal_build_amount_tag(&built, 21_000);

    try std.testing.expectEqual(@as(u64, 21_000), info.amount_msats);
    try std.testing.expectEqualStrings("amount", amount.items[0]);
}
