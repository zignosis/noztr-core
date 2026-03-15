const std = @import("std");
const noztr = @import("noztr");

test "NIP-45 example: parse COUNT client messages and validate metadata" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const message = try noztr.nip45_count.count_client_message_parse(
        "[\"COUNT\",\"q1\",{\"kinds\":[1]}]",
        arena.allocator(),
    );
    try noztr.nip45_count.count_metadata_validate(
        &.{ .approximate = true, .hll = null },
    );

    try std.testing.expectEqualStrings("q1", message.query_id);
    try std.testing.expectEqual(@as(u8, 1), message.filters_count);
}
