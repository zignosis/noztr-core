const std = @import("std");
const noztr = @import("noztr");

test "NIP-24 example: parse metadata extras and common tags with NIP-73 ids" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const extras_json =
        "{\"display_name\":\"Alice\",\"website\":\"https://example.com\",\"bot\":false}";
    const extras = try noztr.nip24_extra_metadata.metadata_extras_parse_json(
        extras_json,
        arena.allocator(),
    );
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "title", "Profile" } },
        .{ .items = &.{ "r", "https://example.com" } },
        .{ .items = &.{ "i", "https://example.com/alice" } },
        .{ .items = &.{ "t", "zig" } },
    };
    var refs: [1][]const u8 = undefined;
    var ids: [1]noztr.nip73_external_ids.ExternalId = undefined;
    var hashtags: [1][]const u8 = undefined;

    const info = try noztr.nip24_extra_metadata.common_tags_extract_with_external_ids(
        tags[0..],
        refs[0..],
        ids[0..],
        hashtags[0..],
    );

    try std.testing.expectEqualStrings("Alice", extras.display_name.?);
    try std.testing.expectEqual(@as(u16, 1), info.external_id_count);
}
