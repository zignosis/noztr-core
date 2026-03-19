const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-01 adversarial example: reject malformed and-filter keys" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidTagKey,
        noztr.nip01_filter.filter_parse_json("{\"&ab\":[\"meme\"]}", arena.allocator()),
    );
}

test "NIP-01 adversarial example: same-key and-filter still wins over overlapping or-filter values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const filter = try noztr.nip01_filter.filter_parse_json(
        "{\"&t\":[\"meme\",\"cat\"],\"#t\":[\"cat\"]}",
        arena.allocator(),
    );
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "t", "meme" } },
        .{ .items = &.{ "t", "dog" } },
    };
    const event = common.simple_event(1, [_]u8{0x01} ** 32, "missing cat", tags[0..]);

    try std.testing.expect(!noztr.nip01_filter.filter_matches_event(&filter, &event));
}
