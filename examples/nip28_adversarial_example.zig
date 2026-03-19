const std = @import("std");
const noztr = @import("noztr");

test "adversarial NIP-28 example: overlong channel event tag input stays typed" {
    var built: noztr.nip28_public_chat.BuiltTag = .{};
    const overlong = [_]u8{'a'} ** (noztr.limits.tag_item_bytes_max + 1);

    try std.testing.expectError(
        error.InvalidChannelTag,
        noztr.nip28_public_chat.channel_build_event_tag(&built, overlong[0..], null, .root),
    );
}
