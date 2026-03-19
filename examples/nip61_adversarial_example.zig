const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "adversarial NIP-61 example: target kind without event stays typed" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "proof", "{\"amount\":1}" } },
        .{ .items = &.{ "u", "https://mint.example" } },
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
        .{ .items = &.{ "k", "1" } },
    };
    const event = common.simple_event(
        noztr.nip61_nutzaps.nutzap_kind,
        [_]u8{0x61} ** 32,
        "Thanks",
        tags[0..],
    );
    var proofs: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.TargetKindWithoutEvent,
        noztr.nip61_nutzaps.nutzap_extract(&event, proofs[0..]),
    );
}
