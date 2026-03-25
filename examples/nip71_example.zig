const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-71 example: extract video metadata and build variant fields" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "title", "Nostube clip" } },
        .{ .items = &.{ "published_at", "1700000000" } },
        .{ .items = &.{
            "imeta",
            "url https://cdn.example/video.mp4",
            "m video/mp4",
            "dim 1280x720",
            "image https://cdn.example/thumb.jpg",
            "duration 18.25",
        } },
    };
    const event = common.simple_event(
        noztr.nip71_video_events.short_video_kind,
        [_]u8{0x71} ** 32,
        "A short clip",
        tags[0..],
    );
    var variants: [1]noztr.nip71_video_events.VideoVariant = undefined;
    var images: [1][]const u8 = undefined;
    var fallbacks: [0][]const u8 = .{};
    var tracks: [0]noztr.nip71_video_events.TextTrack = .{};
    var segments: [0]noztr.nip71_video_events.VideoSegment = .{};
    var participants: [0]noztr.nip71_video_events.VideoParticipant = .{};
    var hashtags: [0][]const u8 = .{};
    var references: [0][]const u8 = .{};
    var origins: [0]noztr.nip71_video_events.Origin = .{};
    var duration_field: [64]u8 = undefined;

    const info = try noztr.nip71_video_events.video_extract(
        &event,
        variants[0..],
        images[0..],
        fallbacks[0..],
        tracks[0..],
        segments[0..],
        participants[0..],
        hashtags[0..],
        references[0..],
        origins[0..],
    );
    const duration = try noztr.nip71_video_events.video_build_duration_field(duration_field[0..], 18.25);

    try std.testing.expectEqual(noztr.nip71_video_events.VideoKind.short, info.kind);
    try std.testing.expectEqual(@as(u16, 1), info.variant_count);
    try std.testing.expectEqualStrings("Nostube clip", info.title);
    try std.testing.expectEqualStrings("duration 18.25", duration);
}
