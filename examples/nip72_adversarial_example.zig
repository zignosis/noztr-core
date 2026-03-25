const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-72 adversarial example: reject top-level lowercase community mismatch" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{
            "A",
            "34550:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:zig",
            "wss://relay.example.com",
        } },
        .{ .items = &.{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
        } },
        .{ .items = &.{ "K", "34550" } },
        .{ .items = &.{
            "a",
            "34550:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:rust",
            "wss://relay.example.com",
        } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
        } },
        .{ .items = &.{ "k", "34550" } },
    };
    const event = common.simple_event(
        noztr.nip72_moderated_communities.community_post_kind,
        [_]u8{0x74} ** 32,
        "mismatch",
        tags[0..],
    );

    try std.testing.expectError(
        error.TopLevelCommunityMismatch,
        noztr.nip72_moderated_communities.post_extract(&event),
    );
}
