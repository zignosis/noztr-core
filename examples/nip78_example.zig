const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-78 example: extract app-data identifier and build the d tag" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "user-settings" } },
    };
    const event = common.simple_event(
        noztr.nip78_app_data.app_data_kind,
        [_]u8{0x78} ** 32,
        "{\"theme\":\"dark\"}",
        tags[0..],
    );
    var built: noztr.nip78_app_data.BuiltTag = .{};

    const info = try noztr.nip78_app_data.app_data_extract(&event);
    const tag = try noztr.nip78_app_data.app_data_build_identifier_tag(&built, "user-settings");

    try std.testing.expect(noztr.nip78_app_data.app_data_is_supported(&event));
    try std.testing.expectEqualStrings("user-settings", info.identifier);
    try std.testing.expectEqualStrings("{\"theme\":\"dark\"}", info.content);
    try std.testing.expectEqualStrings("d", tag.items[0]);
}
