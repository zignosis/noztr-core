const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-72 example: extract community definition and top-level post linkage" {
    const community_coordinate =
        "34550:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:zig";
    const community_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "zig" } },
        .{ .items = &.{ "name", "Zig Community" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
            "moderator",
        } },
    };
    const post_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "A", community_coordinate, "wss://relay.example.com" } },
        .{ .items = &.{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
        } },
        .{ .items = &.{ "K", "34550" } },
        .{ .items = &.{ "a", community_coordinate, "wss://relay.example.com" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
        } },
        .{ .items = &.{ "k", "34550" } },
    };
    const community_event = common.simple_event(
        noztr.nip72_moderated_communities.community_definition_kind,
        [_]u8{0x72} ** 32,
        "",
        community_tags[0..],
    );
    const post_event = common.simple_event(
        noztr.nip72_moderated_communities.community_post_kind,
        [_]u8{0x73} ** 32,
        "hello zig",
        post_tags[0..],
    );
    var moderators: [1]noztr.nip72_moderated_communities.Moderator = undefined;
    var relays: [0]noztr.nip72_moderated_communities.Relay = .{};

    const community = try noztr.nip72_moderated_communities.community_extract(
        &community_event,
        moderators[0..],
        relays[0..],
    );
    const post = try noztr.nip72_moderated_communities.community_post_extract(&post_event);

    try std.testing.expectEqualStrings("zig", community.identifier);
    try std.testing.expect(post.top_level);
    try std.testing.expectEqualStrings("zig", post.community.identifier);
}
