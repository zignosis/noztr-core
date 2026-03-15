const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-18 example: parse a strict repost target from a kind-6 event" {
    const items = [_][]const u8{
        "e",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "wss://relay.one",
    };
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = items[0..] }};
    const event = common.simple_event(6, [_]u8{0x18} ** 32, "", tags[0..]);

    const target = try noztr.nip18_reposts.repost_parse(&event);

    try std.testing.expectEqualStrings("wss://relay.one", target.relay_hint.?);
    try std.testing.expect(target.embedded_event_json == null);
}
