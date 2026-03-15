const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-10 example: extract root and reply references from text-note tags" {
    const root_items = [_][]const u8{
        "e",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "",
        "root",
    };
    const reply_items = [_][]const u8{
        "e",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "",
        "reply",
    };
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = root_items[0..] },
        .{ .items = reply_items[0..] },
    };
    const event = common.simple_event(1, [_]u8{0x10} ** 32, "reply", tags[0..]);
    var mentions: [2]noztr.nip10_threads.ThreadReference = undefined;

    const thread = try noztr.nip10_threads.thread_extract(&event, mentions[0..]);

    try std.testing.expectEqual(@as(u16, 0), thread.mention_count);
    try std.testing.expect(thread.root != null);
    try std.testing.expect(thread.reply != null);
}
