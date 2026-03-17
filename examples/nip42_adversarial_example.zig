const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "adversarial NIP-42 example: mismatched challenge stays typed" {
    const secret_key = [_]u8{0x41} ** 32;
    const pubkey = try common.derive_public_key(&secret_key);
    const relay_items = [_][]const u8{ "relay", "wss://relay.example.com/chat" };
    const challenge_items = [_][]const u8{ "challenge", "expected-challenge" };
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = relay_items[0..] },
        .{ .items = challenge_items[0..] },
    };
    var auth_event = common.simple_event(noztr.nip42_auth.auth_event_kind, pubkey, "", tags[0..]);
    auth_event.created_at = 42;
    try common.sign_event(&secret_key, &auth_event);

    try std.testing.expectError(
        error.ChallengeMismatch,
        noztr.nip42_auth.auth_validate_event(
            &auth_event,
            "wss://relay.example.com/chat",
            "wrong-challenge",
            45,
            60,
        ),
    );
}
