const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-23 example: extract long-form metadata and ordered hashtags" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "article-1" } },
        .{ .items = &.{ "title", "Example Article" } },
        .{ .items = &.{ "t", "nostr" } },
    };
    const event = common.simple_event(30023, [_]u8{0x23} ** 32, "body", tags[0..]);
    var hashtags: [2][]const u8 = undefined;

    const metadata = try noztr.nip23_long_form.extract(&event, hashtags[0..]);

    try std.testing.expectEqualStrings("article-1", metadata.identifier);
    try std.testing.expectEqual(@as(u16, 1), metadata.hashtag_count);
}
