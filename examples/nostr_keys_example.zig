const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "nostr key example: derive x-only public key and sign event" {
    const secret_key = [_]u8{0x11} ** 32;
    const public_key = try common.derive_public_key(&secret_key);
    var event = common.simple_event(1, public_key, "signed by kernel helper", &.{});

    try common.sign_event(&secret_key, &event);
    try noztr.nip01_event.event_verify(&event);
    try std.testing.expect(event.id[0] != 0);
}
