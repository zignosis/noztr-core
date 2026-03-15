const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-17 example: parse recipients and relay list boundaries" {
    const message_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "p", "1111111111111111111111111111111111111111111111111111111111111111" } },
        .{ .items = &.{ "subject", "hello" } },
    };
    const message_event = common.simple_event(14, [_]u8{0x17} ** 32, "ciphertext", message_tags[0..]);
    var recipients: [1]noztr.nip17_private_messages.DmRecipient = undefined;
    const message = try noztr.nip17_private_messages.nip17_message_parse(
        &message_event,
        recipients[0..],
    );

    const relay_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "relay", "wss://relay.one" } },
    };
    const relay_event = common.simple_event(10050, [_]u8{0x17} ** 32, "", relay_tags[0..]);
    var relays: [1][]const u8 = undefined;
    const relay_count = try noztr.nip17_private_messages.nip17_relay_list_extract(
        &relay_event,
        relays[0..],
    );

    try std.testing.expectEqual(@as(usize, 1), message.recipients.len);
    try std.testing.expectEqual(@as(u16, 1), relay_count);
}
