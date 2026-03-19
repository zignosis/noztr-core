const std = @import("std");
const noztr = @import("noztr");

test "NIP-30 example: extract and build emoji tags" {
    const tag = noztr.nip01_event.EventTag{
        .items = &.{ "emoji", "soapbox", "https://cdn.example/soapbox.png" },
    };
    var built: noztr.nip30_custom_emoji.BuiltTag = .{};

    const info = try noztr.nip30_custom_emoji.emoji_tag_extract(tag);
    const built_tag = try noztr.nip30_custom_emoji.emoji_build_tag(
        &built,
        "soapbox",
        "https://cdn.example/soapbox.png",
        null,
    );

    try std.testing.expectEqualStrings("soapbox", info.shortcode);
    try std.testing.expectEqualStrings("emoji", built_tag.items[0]);
    try std.testing.expectEqualStrings("soapbox", built_tag.items[1]);
}
