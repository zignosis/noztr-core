const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-52 example: extract date calendar metadata and build participant tags" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "nostr-zig-meetup" } },
        .{ .items = &.{ "title", "Nostr Zig Meetup" } },
        .{ .items = &.{ "location", "Lisbon" } },
        .{ .items = &.{ "start", "2026-04-12" } },
        .{ .items = &.{ "p",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "wss://relay.example.com",
            "speaker",
        } },
    };
    const event = common.simple_event(
        noztr.nip52_calendar_events.date_calendar_event_kind,
        [_]u8{0x52} ** 32,
        "meetup agenda",
        tags[0..],
    );
    var locations: [1][]const u8 = undefined;
    var participants: [1]noztr.nip52_calendar_events.CalendarParticipant = undefined;
    var hashtags: [0][]const u8 = .{};
    var references: [0][]const u8 = .{};
    var calendars: [0]noztr.nip52_calendar_events.CalendarCoordinate = .{};
    var built: noztr.nip52_calendar_events.BuiltTag = .{};

    const info = try noztr.nip52_calendar_events.date_calendar_event_extract(
        &event,
        locations[0..],
        participants[0..],
        hashtags[0..],
        references[0..],
        calendars[0..],
    );
    const participant_tag = try noztr.nip52_calendar_events.calendar_build_participant_tag(
        &built,
        "1111111111111111111111111111111111111111111111111111111111111111",
        "wss://relay.example.com",
        "speaker",
    );

    try std.testing.expectEqualStrings("nostr-zig-meetup", info.common.identifier);
    try std.testing.expectEqualStrings("Nostr Zig Meetup", info.common.title);
    try std.testing.expectEqualStrings("2026-04-12", info.start_date);
    try std.testing.expectEqual(@as(u16, 1), info.common.participant_count);
    try std.testing.expectEqualStrings("p", participant_tag.items[0]);
}
