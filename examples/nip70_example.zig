const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-70 example: protected-tag validation requires the authenticated pubkey" {
    const protected_items = [_][]const u8{"-"};
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = protected_items[0..] }};
    const pubkey = [_]u8{0x77} ** 32;
    const event = common.simple_event(1, pubkey, "", tags[0..]);

    try std.testing.expect(noztr.nip70_protected.event_has_protected_tag(&event));
    try noztr.nip70_protected.protected_event_validate(&event, &pubkey);
}
