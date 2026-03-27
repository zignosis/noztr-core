const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-34 example: extract repository announcement metadata" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "noztr" } },
        .{ .items = &.{ "name", "noztr" } },
        .{ .items = &.{ "description", "pure zig nostr protocol library" } },
        .{ .items = &.{ "web", "https://example.com/noztr" } },
        .{ .items = &.{ "clone", "https://git.example.com/noztr.git" } },
        .{ .items = &.{ "relays", "wss://relay.example.com" } },
        .{ .items = &.{
            "maintainers",
            "1111111111111111111111111111111111111111111111111111111111111111",
        } },
        .{ .items = &.{ "t", "nostr" } },
    };
    const event = common.simple_event(
        noztr.nip34_git.repository_announcement_kind,
        [_]u8{0x34} ** 32,
        "",
        tags[0..],
    );
    var web: [1][]const u8 = undefined;
    var clone: [1][]const u8 = undefined;
    var relays: [1][]const u8 = undefined;
    var maintainers: [1][32]u8 = undefined;
    var topics: [1][]const u8 = undefined;
    var built: noztr.nip34_git.TagBuilder = .{};

    const info = try noztr.nip34_git.announcement_extract(
        &event,
        web[0..],
        clone[0..],
        relays[0..],
        maintainers[0..],
        topics[0..],
    );
    const maintainer_tag = try noztr.nip34_git.build_maintainers_tag(
        &built,
        &.{"1111111111111111111111111111111111111111111111111111111111111111"},
    );

    try std.testing.expectEqualStrings("noztr", info.identifier);
    try std.testing.expectEqualStrings("noztr", info.name.?);
    try std.testing.expectEqual(@as(u16, 1), info.web_count);
    try std.testing.expectEqualStrings("maintainers", maintainer_tag.items[0]);
}
