const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-38 example: extract and build user-status tags" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "music" } },
        .{ .items = &.{ "r", "https://nostr.world" } },
    };
    const event = common.simple_event(
        noztr.nip38_user_status.user_status_kind,
        [_]u8{0x38} ** 32,
        "Working",
        tags[0..],
    );
    var urls: [1][]const u8 = undefined;
    var empty_pubkeys: [0][32]u8 = .{};
    var empty_events: [0][32]u8 = .{};
    var empty_coords: [0][]const u8 = .{};
    var empty_emojis: [0]noztr.nip30_custom_emoji.EmojiTagInfo = .{};

    const info = try noztr.nip38_user_status.user_status_extract(
        &event,
        urls[0..],
        empty_pubkeys[0..],
        empty_events[0..],
        empty_coords[0..],
        empty_emojis[0..],
    );

    var built: noztr.nip38_user_status.BuiltTag = .{};
    const expiration = try noztr.nip38_user_status.user_status_build_expiration_tag(
        &built,
        1_700_000_000,
    );

    try std.testing.expectEqualStrings("music", info.identifier);
    try std.testing.expectEqualStrings("expiration", expiration.items[0]);
}
