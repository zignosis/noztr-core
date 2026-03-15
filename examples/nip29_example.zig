const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-29 example: parse group references and metadata snapshots" {
    const reference = try noztr.nip29_relay_groups.group_reference_parse(
        "groups.example'my-group",
    );
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "my-group" } },
        .{ .items = &.{ "name", "Example Group" } },
        .{ .items = &.{ "public" } },
    };
    const event = common.simple_event(39000, [_]u8{0x29} ** 32, "", tags[0..]);
    const metadata = try noztr.nip29_relay_groups.group_metadata_extract(&event);

    try std.testing.expectEqualStrings("groups.example", reference.host);
    try std.testing.expectEqualStrings("my-group", metadata.group_id);
}
