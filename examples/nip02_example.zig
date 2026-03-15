const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-02 example: extract contact entries from a kind-3 event" {
    const items = [_][]const u8{
        "p",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "wss://relay.one",
        "alice",
    };
    const tags = [_]noztr.nip01_event.EventTag{.{ .items = items[0..] }};
    const event = common.simple_event(3, [_]u8{0x22} ** 32, "", tags[0..]);
    var contacts: [1]noztr.nip02_contacts.ContactEntry = undefined;

    const count = try noztr.nip02_contacts.contacts_extract(&event, contacts[0..]);

    try std.testing.expectEqual(@as(u16, 1), count);
    try std.testing.expectEqualStrings("wss://relay.one", contacts[0].relay.?);
}
