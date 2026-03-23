const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-89 example: recommendation and client tag helpers" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "31337" } },
        .{ .items = &.{ "a", "31990:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:zapstr", "wss://relay.one", "web" } },
    };
    const recommendation = common.simple_event(
        noztr.nip89_handlers.recommendation_kind,
        [_]u8{0x89} ** 32,
        "",
        tags[0..],
    );
    var handlers: [1]noztr.nip89_handlers.Reference = undefined;
    const info = try noztr.nip89_handlers.recommendation_extract(&recommendation, handlers[0..]);

    var built: noztr.nip89_handlers.BuiltTag = .{};
    const client = try noztr.nip89_handlers.client_build_tag(
        &built,
        "My Client",
        "31990:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:zapstr",
        "wss://relay.one",
    );

    try std.testing.expectEqual(@as(u32, 31_337), info.supported_kind);
    try std.testing.expectEqualStrings("client", client.items[0]);
}
