const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-22 example: parse strict external root and parent comment linkage" {
    const root_author = "1111111111111111111111111111111111111111111111111111111111111111";
    const parent_author = "2222222222222222222222222222222222222222222222222222222222222222";
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "I", "https://example.com/root" } },
        .{ .items = &.{ "K", "web" } },
        .{ .items = &.{ "P", root_author } },
        .{ .items = &.{ "i", "https://example.com/parent" } },
        .{ .items = &.{ "k", "web" } },
        .{ .items = &.{ "p", parent_author } },
    };
    const event = common.simple_event(1111, [_]u8{0x22} ** 32, "comment", tags[0..]);

    const comment = try noztr.nip22_comments.comment_parse(&event);

    try std.testing.expect(comment.root == .external);
    try std.testing.expect(comment.parent == .external);
}
