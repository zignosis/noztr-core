const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-53 example: extract live activity metadata and build chat activity tags" {
    const live_tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "zig-weekly" } },
        .{ .items = &.{ "title", "Zig Weekly" } },
        .{ .items = &.{ "streaming", "https://stream.example.com/live" } },
        .{ .items = &.{ "status", "live" } },
        .{ .items = &.{ "p",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "wss://relay.example.com",
            "host",
            "https://example.com/proof",
        } },
    };
    const live_event = common.simple_event(
        noztr.nip53_live_activities.live_stream_event_kind,
        [_]u8{0x53} ** 32,
        "",
        live_tags[0..],
    );
    var participants: [1]noztr.nip53_live_activities.LiveActivityParticipant = undefined;
    var relays: [0][]const u8 = .{};
    var hashtags: [0][]const u8 = .{};
    var pinned: [0][32]u8 = .{};
    var built: noztr.nip53_live_activities.BuiltTag = .{};

    const info = try noztr.nip53_live_activities.live_activity_extract(
        &live_event,
        participants[0..],
        relays[0..],
        hashtags[0..],
        pinned[0..],
    );
    const activity_tag = try noztr.nip53_live_activities.live_chat_build_activity_tag(
        &built,
        "30311:1111111111111111111111111111111111111111111111111111111111111111:zig-weekly",
        "wss://relay.example.com",
    );

    try std.testing.expectEqualStrings("zig-weekly", info.identifier);
    try std.testing.expectEqual(noztr.nip53_live_activities.LiveActivityStatus.live, info.status.?);
    try std.testing.expectEqual(@as(u16, 1), info.participant_count);
    try std.testing.expectEqualStrings("a", activity_tag.items[0]);
    try std.testing.expectEqualStrings("root", activity_tag.items[3]);
}
