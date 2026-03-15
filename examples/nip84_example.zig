const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-84 example: extract one highlight source with context and comment" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "context", "chapter 1" } },
        .{ .items = &.{ "comment", "important line" } },
    };
    const event = common.simple_event(9802, [_]u8{0x84} ** 32, "highlight", tags[0..]);
    var attributions: [1]noztr.nip84_highlights.HighlightAttribution = undefined;
    var refs: [1]noztr.nip84_highlights.UrlReference = undefined;

    const info = try noztr.nip84_highlights.highlight_extract(
        &event,
        attributions[0..],
        refs[0..],
    );

    try std.testing.expect(info.source != null);
    try std.testing.expectEqualStrings("chapter 1", info.context.?);
}
