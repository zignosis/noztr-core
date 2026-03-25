const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_scheme = @import("internal/url_with_scheme.zig");

pub const live_stream_event_kind: u32 = 30311;
pub const live_chat_message_kind: u32 = 1311;

pub const LiveActivityError = error{
    InvalidLiveActivityKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicateTitleTag,
    InvalidTitleTag,
    DuplicateSummaryTag,
    InvalidSummaryTag,
    DuplicateImageTag,
    InvalidImageTag,
    DuplicateStreamingTag,
    InvalidStreamingTag,
    DuplicateRecordingTag,
    InvalidRecordingTag,
    DuplicateStartsTag,
    InvalidStartsTag,
    DuplicateEndsTag,
    InvalidEndsTag,
    DuplicateStatusTag,
    InvalidStatusTag,
    DuplicateCurrentParticipantsTag,
    InvalidCurrentParticipantsTag,
    DuplicateTotalParticipantsTag,
    InvalidTotalParticipantsTag,
    InvalidParticipantTag,
    InvalidRelayTag,
    InvalidPinnedTag,
    InvalidHashtagTag,
    InvalidChatKind,
    MissingActivityTag,
    DuplicateActivityTag,
    InvalidActivityTag,
    InvalidEventTag,
    InvalidContent,
    BufferTooSmall,
};

pub const LiveActivityStatus = enum {
    planned,
    live,
    ended,
};

pub const LiveActivityParticipant = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
    role: ?[]const u8 = null,
    proof: ?[]const u8 = null,
};

pub const Coordinate = struct {
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const Reply = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const Activity = struct {
    identifier: []const u8,
    title: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    streaming_url: ?[]const u8 = null,
    recording_url: ?[]const u8 = null,
    starts: ?u64 = null,
    ends: ?u64 = null,
    status: ?LiveActivityStatus = null,
    current_participants: ?u32 = null,
    total_participants: ?u32 = null,
    participant_count: u16 = 0,
    relay_count: u16 = 0,
    hashtag_count: u16 = 0,
    pinned_count: u16 = 0,
};

pub const Chat = struct {
    activity: Coordinate,
    reply: ?Reply = null,
    content: []const u8,
};

pub const TagBuilder = struct {
    items: [5][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const TagBuilder) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded live-stream metadata from a `kind:30311` event.
pub fn live_activity_extract(
    event: *const nip01_event.Event,
    out_participants: []LiveActivityParticipant,
    out_relays: [][]const u8,
    out_hashtags: [][]const u8,
    out_pinned: [][32]u8,
) LiveActivityError!Activity {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_participants.len <= limits.tags_max);

    if (event.kind != live_stream_event_kind) return error.InvalidLiveActivityKind;

    var identifier: ?[]const u8 = null;
    var info = Activity{ .identifier = undefined };
    for (event.tags) |tag| {
        try apply_live_tag(tag, &identifier, &info, out_participants, out_relays, out_hashtags, out_pinned);
    }
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    return info;
}

/// Extracts the activity reference and optional reply metadata from a live-chat message.
pub fn live_chat_extract(event: *const nip01_event.Event) LiveActivityError!Chat {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != live_chat_message_kind) return error.InvalidChatKind;
    if (!std.unicode.utf8ValidateSlice(event.content)) return error.InvalidContent;

    var activity: ?Coordinate = null;
    var reply: ?Reply = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "a")) {
            if (activity != null) return error.DuplicateActivityTag;
            activity = parse_activity_tag(tag) catch return error.InvalidActivityTag;
        }
        if (std.mem.eql(u8, tag.items[0], "e")) {
            reply = parse_event_tag(tag) catch return error.InvalidEventTag;
        }
    }
    return .{
        .activity = activity orelse return error.MissingActivityTag,
        .reply = reply,
        .content = event.content,
    };
}

/// Builds a canonical `d` identifier tag for a live activity.
pub fn live_activity_build_identifier_tag(
    output: *TagBuilder,
    identifier: []const u8,
) LiveActivityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `title` tag for a live activity.
pub fn live_activity_build_title_tag(
    output: *TagBuilder,
    title: []const u8,
) LiveActivityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(title.len <= limits.tag_item_bytes_max);

    output.items[0] = "title";
    output.items[1] = parse_nonempty_utf8(title) catch return error.InvalidTitleTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `streaming` tag for a live activity.
pub fn live_activity_build_streaming_tag(
    output: *TagBuilder,
    url: []const u8,
) LiveActivityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(url.len <= limits.tag_item_bytes_max);

    output.items[0] = "streaming";
    output.items[1] = parse_url(url) catch return error.InvalidStreamingTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `status` tag for a live activity.
pub fn live_activity_build_status_tag(
    output: *TagBuilder,
    status: LiveActivityStatus,
) LiveActivityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromEnum(status) <= @intFromEnum(LiveActivityStatus.ended));

    output.items[0] = "status";
    output.items[1] = switch (status) {
        .planned => "planned",
        .live => "live",
        .ended => "ended",
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical participant `p` tag for a live activity.
pub fn live_activity_build_participant_tag(
    output: *TagBuilder,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
    role: ?[]const u8,
    proof: ?[]const u8,
) LiveActivityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidParticipantTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidParticipantTag;
        output.item_count = 3;
    }
    if (role) |value| {
        output.items[output.item_count] = parse_nonempty_utf8(value) catch {
            return error.InvalidParticipantTag;
        };
        output.item_count += 1;
    }
    if (proof) |value| {
        output.items[output.item_count] = parse_nonempty_utf8(value) catch {
            return error.InvalidParticipantTag;
        };
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds the required activity `a` tag for a live-chat message.
pub fn live_chat_build_activity_tag(
    output: *TagBuilder,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) LiveActivityError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(coordinate_text.len <= limits.tag_item_bytes_max);

    _ = parse_activity_coordinate(coordinate_text) catch return error.InvalidActivityTag;
    output.items[0] = "a";
    output.items[1] = coordinate_text;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidActivityTag;
        output.item_count = 3;
    }
    output.items[output.item_count] = "root";
    output.item_count += 1;
    return output.as_event_tag();
}

fn apply_live_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    info: *Activity,
    out_participants: []LiveActivityParticipant,
    out_relays: [][]const u8,
    out_hashtags: [][]const u8,
    out_pinned: [][32]u8,
) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, name, "title")) return apply_text_tag(tag, &info.title, error.DuplicateTitleTag, error.InvalidTitleTag);
    if (std.mem.eql(u8, name, "summary")) return apply_text_tag(tag, &info.summary, error.DuplicateSummaryTag, error.InvalidSummaryTag);
    if (std.mem.eql(u8, name, "image")) return apply_url_tag(tag, &info.image_url, error.DuplicateImageTag, error.InvalidImageTag);
    if (std.mem.eql(u8, name, "streaming")) return apply_url_tag(tag, &info.streaming_url, error.DuplicateStreamingTag, error.InvalidStreamingTag);
    if (std.mem.eql(u8, name, "recording")) return apply_url_tag(tag, &info.recording_url, error.DuplicateRecordingTag, error.InvalidRecordingTag);
    if (std.mem.eql(u8, name, "starts")) return apply_timestamp_tag(tag, &info.starts, error.DuplicateStartsTag, error.InvalidStartsTag);
    if (std.mem.eql(u8, name, "ends")) return apply_timestamp_tag(tag, &info.ends, error.DuplicateEndsTag, error.InvalidEndsTag);
    if (std.mem.eql(u8, name, "status")) return apply_status_tag(tag, &info.status);
    if (std.mem.eql(u8, name, "current_participants")) return apply_u32_tag(tag, &info.current_participants, error.DuplicateCurrentParticipantsTag, error.InvalidCurrentParticipantsTag);
    if (std.mem.eql(u8, name, "total_participants")) return apply_u32_tag(tag, &info.total_participants, error.DuplicateTotalParticipantsTag, error.InvalidTotalParticipantsTag);
    if (std.mem.eql(u8, name, "p")) return append_participant(tag, info, out_participants);
    if (std.mem.eql(u8, name, "relays")) return append_relays(tag, info, out_relays);
    if (std.mem.eql(u8, name, "t")) return append_text_value(tag, &info.hashtag_count, out_hashtags, error.InvalidHashtagTag);
    if (std.mem.eql(u8, name, "pinned")) return append_pinned(tag, info, out_pinned);
}

fn apply_identifier_tag(tag: nip01_event.EventTag, identifier: *?[]const u8) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    identifier.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn apply_text_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: LiveActivityError,
    invalid_error: LiveActivityError,
) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
}

fn apply_url_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: LiveActivityError,
    invalid_error: LiveActivityError,
) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_url(tag.items[1]) catch return invalid_error;
}

fn apply_timestamp_tag(
    tag: nip01_event.EventTag,
    field: *?u64,
    duplicate_error: LiveActivityError,
    invalid_error: LiveActivityError,
) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch return invalid_error;
}

fn apply_status_tag(tag: nip01_event.EventTag, field: *?LiveActivityStatus) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return error.DuplicateStatusTag;
    if (tag.items.len != 2) return error.InvalidStatusTag;
    field.* = parse_status(tag.items[1]) catch return error.InvalidStatusTag;
}

fn apply_u32_tag(
    tag: nip01_event.EventTag,
    field: *?u32,
    duplicate_error: LiveActivityError,
    invalid_error: LiveActivityError,
) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = std.fmt.parseUnsigned(u32, tag.items[1], 10) catch return invalid_error;
}

fn append_participant(
    tag: nip01_event.EventTag,
    info: *Activity,
    out: []LiveActivityParticipant,
) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out.len <= limits.tags_max);

    if (tag.items.len < 2 or tag.items.len > 5) return error.InvalidParticipantTag;
    if (info.participant_count == out.len) return error.BufferTooSmall;
    out[info.participant_count] = .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidParticipantTag,
        .relay_hint = parse_optional_url_item(tag, 2, error.InvalidParticipantTag) catch {
            return error.InvalidParticipantTag;
        },
        .role = parse_optional_text_item(tag, 3, error.InvalidParticipantTag) catch {
            return error.InvalidParticipantTag;
        },
        .proof = parse_optional_text_item(tag, 4, error.InvalidParticipantTag) catch {
            return error.InvalidParticipantTag;
        },
    };
    info.participant_count += 1;
}

fn append_relays(tag: nip01_event.EventTag, info: *Activity, out: [][]const u8) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out.len <= limits.tags_max);

    if (tag.items.len < 2) return error.InvalidRelayTag;
    for (tag.items[1..]) |relay| {
        if (info.relay_count == out.len) return error.BufferTooSmall;
        out[info.relay_count] = parse_url(relay) catch return error.InvalidRelayTag;
        info.relay_count += 1;
    }
}

fn append_text_value(
    tag: nip01_event.EventTag,
    count: *u16,
    out: [][]const u8,
    invalid_error: LiveActivityError,
) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(count) != 0);

    if (tag.items.len != 2) return invalid_error;
    if (count.* == out.len) return error.BufferTooSmall;
    out[count.*] = parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
    count.* += 1;
}

fn append_pinned(tag: nip01_event.EventTag, info: *Activity, out: [][32]u8) LiveActivityError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out.len <= limits.tags_max);

    if (tag.items.len != 2) return error.InvalidPinnedTag;
    if (info.pinned_count == out.len) return error.BufferTooSmall;
    out[info.pinned_count] = parse_lower_hex_32(tag.items[1]) catch return error.InvalidPinnedTag;
    info.pinned_count += 1;
}

fn parse_activity_tag(tag: nip01_event.EventTag) error{InvalidTag}!Coordinate {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len < 2) return error.InvalidTag;
    var parsed = parse_activity_coordinate(tag.items[1]) catch return error.InvalidTag;
    parsed.relay_hint = parse_optional_url_item(tag, 2, error.InvalidTag) catch return error.InvalidTag;
    return parsed;
}

fn parse_event_tag(tag: nip01_event.EventTag) error{InvalidTag}!Reply {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len < 2) return error.InvalidTag;
    return .{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidTag,
        .relay_hint = parse_optional_url_item(tag, 2, error.InvalidTag) catch return error.InvalidTag,
    };
}

fn parse_activity_coordinate(text: []const u8) error{InvalidCoordinate}!Coordinate {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidCoordinate;
    const second_colon = std.mem.indexOfScalarPos(u8, text, first_colon + 1, ':') orelse {
        return error.InvalidCoordinate;
    };
    const kind = std.fmt.parseUnsigned(u32, text[0..first_colon], 10) catch {
        return error.InvalidCoordinate;
    };
    if (kind != live_stream_event_kind) return error.InvalidCoordinate;
    return .{
        .pubkey = parse_lower_hex_32(text[first_colon + 1 .. second_colon]) catch {
            return error.InvalidCoordinate;
        },
        .identifier = parse_nonempty_utf8(text[second_colon + 1 ..]) catch {
            return error.InvalidCoordinate;
        },
    };
}

fn parse_status(text: []const u8) error{InvalidStatus}!LiveActivityStatus {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (std.mem.eql(u8, text, "planned")) return .planned;
    if (std.mem.eql(u8, text, "live")) return .live;
    if (std.mem.eql(u8, text, "ended")) return .ended;
    return error.InvalidStatus;
}

fn parse_optional_url_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: anyerror,
) anyerror!?[]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len <= index) return null;
    if (tag.items[index].len == 0) return null;
    return parse_url(tag.items[index]) catch return invalid_error;
}

fn parse_optional_text_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid_error: anyerror,
) anyerror!?[]const u8 {
    std.debug.assert(index < limits.tag_items_max);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len <= index) return null;
    if (tag.items[index].len == 0) return null;
    return parse_nonempty_utf8(tag.items[index]) catch return invalid_error;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    return url_with_scheme.parse_utf8(text, limits.tag_item_bytes_max);
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.id_hex_length == 64);

    return lower_hex_32.parse(text);
}

test "NIP-53 extracts live-stream metadata and participants" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "stream-1" } },
        .{ .items = &.{ "title", "Demo Stream" } },
        .{ .items = &.{ "status", "live" } },
        .{ .items = &.{ "streaming", "https://example.com/live.m3u8" } },
        .{ .items = &.{ "p", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "wss://relay.example", "Host" } },
        .{ .items = &.{ "relays", "wss://relay.example" } },
        .{ .items = &.{ "t", "music" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x53} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = live_stream_event_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x22} ** 64,
    };
    var participants: [1]LiveActivityParticipant = undefined;
    var relays: [1][]const u8 = undefined;
    var hashtags: [1][]const u8 = undefined;
    var pinned: [1][32]u8 = undefined;

    const info = try live_activity_extract(
        &event,
        participants[0..],
        relays[0..],
        hashtags[0..],
        pinned[0..],
    );

    try std.testing.expectEqualStrings("stream-1", info.identifier);
    try std.testing.expectEqual(.live, info.status.?);
    try std.testing.expectEqual(@as(u16, 1), info.participant_count);
}

test "NIP-53 extracts live-chat activity reference" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "a", "30311:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:stream-1", "", "root" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x54} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = live_chat_message_kind,
        .tags = tags[0..],
        .content = "hello",
        .sig = [_]u8{0x23} ** 64,
    };

    const info = try live_chat_extract(&event);

    try std.testing.expectEqualStrings("stream-1", info.activity.identifier);
    try std.testing.expectEqualStrings("hello", info.content);
}

test "NIP-53 builds canonical live-activity participant tag" {
    var built: TagBuilder = .{};

    const tag = try live_activity_build_participant_tag(
        &built,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "wss://relay.example",
        "Host",
        null,
    );

    try std.testing.expectEqualStrings("p", tag.items[0]);
    try std.testing.expectEqualStrings("Host", tag.items[3]);
}
