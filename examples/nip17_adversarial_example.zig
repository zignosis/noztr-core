const std = @import("std");
const noztr = @import("noztr");

test "NIP-17 adversarial example: overlong builder input stays typed" {
    var recipient_tag: noztr.nip17_private_messages.BuiltTag = .{};
    var relay_tag: noztr.nip17_private_messages.BuiltTag = .{};
    const overlong_pubkey =
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdefx";
    const overlong_relay = "wss://" ++ ("a" ** 9000) ++ ".example";

    try std.testing.expectError(
        error.InvalidRecipientTag,
        noztr.nip17_private_messages.nip17_build_recipient_tag(
            &recipient_tag,
            overlong_pubkey,
            null,
        ),
    );
    try std.testing.expectError(
        error.InvalidRelayUrl,
        noztr.nip17_private_messages.nip17_build_relay_tag(&relay_tag, overlong_relay),
    );
}
