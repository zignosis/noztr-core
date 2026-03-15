const std = @import("std");
const noztr = @import("noztr");

test "NIP-26 example: parse delegation tags and build the signed message string" {
    const tag = noztr.nip01_event.EventTag{
        .items = &.{
            "delegation",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "kind=1&created_at>1",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ++
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        },
    };
    const parsed = try noztr.nip26_delegation.delegation_tag_parse(tag);
    var message_output: [256]u8 = undefined;
    const message = try noztr.nip26_delegation.delegation_message_build(
        message_output[0..],
        &([_]u8{0x26} ** 32),
        parsed.conditions_text,
    );

    try std.testing.expect(std.mem.startsWith(u8, message, "nostr:delegation:"));
    try std.testing.expectEqualStrings("kind=1&created_at>1", parsed.conditions_text);
}
