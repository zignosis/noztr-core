const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-36 example: extract content-warning reason and build the tag" {
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = &.{ "content-warning", "graphic" } }};
    const event = common.simple_event(1, [_]u8{0x36} ** 32, "", tags[0..]);
    var built: noztr.nip36_content_warning.BuiltTag = .{};

    const info = try noztr.nip36_content_warning.content_warning_extract(&event);
    const tag = try noztr.nip36_content_warning.build_content_warning_tag(&built, "graphic");

    try std.testing.expectEqualStrings("graphic", info.?.reason.?);
    try std.testing.expectEqualStrings("content-warning", tag.items[0]);
}
