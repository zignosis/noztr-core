const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-25 example: parse a like reaction target from kind-7 tags" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "p", "1111111111111111111111111111111111111111111111111111111111111111" } },
    };
    const event = common.simple_event(7, [_]u8{0x25} ** 32, "+", tags[0..]);

    const target = try noztr.nip25_reactions.reaction_parse(&event);

    try std.testing.expectEqual(.like, target.reaction_type);
    try std.testing.expect(target.author_pubkey != null);
}
