const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-31 example: extract and build alt tags" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "alt", "calendar reminder fallback" } },
    };
    const event = common.simple_event(30_001, [_]u8{0x31} ** 32, "", tags[0..]);
    var built: noztr.nip31_alt_tags.BuiltTag = .{};

    const summary = try noztr.nip31_alt_tags.alt_extract(&event);
    const tag = try noztr.nip31_alt_tags.alt_build_tag(&built, "calendar reminder fallback");

    try std.testing.expect(summary != null);
    try std.testing.expectEqualStrings("calendar reminder fallback", summary.?);
    try std.testing.expectEqualStrings("alt", tag.items[0]);
    try std.testing.expectEqualStrings("calendar reminder fallback", tag.items[1]);
}
