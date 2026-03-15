const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-51 example: extract bookmark items from a public list" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "url", "https://example.com/article" } },
    };
    const event = common.simple_event(10003, [_]u8{0x51} ** 32, "", tags[0..]);
    var items: [2]noztr.nip51_lists.ListItem = undefined;

    const info = try noztr.nip51_lists.list_extract(&event, items[0..]);

    try std.testing.expectEqual(.bookmarks, info.kind);
    try std.testing.expect(items[0] == .event);
    try std.testing.expect(items[1] == .url);
}
