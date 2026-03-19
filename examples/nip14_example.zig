const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-14 example: extract and build subject tags" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "subject", "Release planning" } },
    };
    const event = common.simple_event(1, [_]u8{0x14} ** 32, "hello", tags[0..]);
    var built: noztr.nip14_subjects.BuiltTag = .{};

    const subject = try noztr.nip14_subjects.subject_extract(&event);
    const tag = try noztr.nip14_subjects.subject_build_tag(&built, "Release planning");

    try std.testing.expect(subject != null);
    try std.testing.expectEqualStrings("Release planning", subject.?);
    try std.testing.expectEqualStrings("subject", tag.items[0]);
    try std.testing.expectEqualStrings("Release planning", tag.items[1]);
}
