const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-58 example: extract badge definition metadata" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "bravery" } },
        .{ .items = &.{ "name", "Bravery" } },
    };
    const event = common.simple_event(30009, [_]u8{0x58} ** 32, "", tags[0..]);
    var thumbs: [1]noztr.nip58_badges.ImageInfo = undefined;

    const definition = try noztr.nip58_badges.badge_definition_extract(&event, thumbs[0..]);

    try std.testing.expectEqualStrings("bravery", definition.identifier);
    try std.testing.expectEqualStrings("Bravery", definition.name.?);
}
