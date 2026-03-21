const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const date_calendar_event_kind: u32 = 31922;
pub const time_calendar_event_kind: u32 = 31923;
pub const calendar_kind: u32 = 31924;
pub const calendar_rsvp_kind: u32 = 31925;

pub const Nip52Error = error{
    InvalidDateEventKind,
    InvalidTimeEventKind,
    InvalidCalendarKind,
    InvalidRsvpKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    MissingTitleTag,
    DuplicateTitleTag,
    InvalidTitleTag,
    DuplicateSummaryTag,
    InvalidSummaryTag,
    DuplicateImageTag,
    InvalidImageTag,
    DuplicateGeohashTag,
    InvalidGeohashTag,
    InvalidLocationTag,
    InvalidParticipantTag,
    InvalidHashtagTag,
    InvalidReferenceTag,
    InvalidCalendarTag,
    MissingStartTag,
    DuplicateStartTag,
    InvalidStartTag,
    DuplicateEndTag,
    InvalidEndTag,
    DuplicateStartTzidTag,
    InvalidStartTzidTag,
    DuplicateEndTzidTag,
    InvalidEndTzidTag,
    InvalidDayTag,
    MissingStatusTag,
    DuplicateStatusTag,
    InvalidStatusTag,
    DuplicateFreeBusyTag,
    InvalidFreeBusyTag,
    DuplicateAuthorTag,
    InvalidAuthorTag,
    DuplicateRevisionTag,
    InvalidRevisionTag,
    InvalidDateRange,
    InvalidTimeRange,
    BufferTooSmall,
};

pub const CalendarParticipant = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
    role: ?[]const u8 = null,
};

pub const CalendarCoordinate = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const EventRevision = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const AttendanceStatus = enum {
    accepted,
    declined,
    tentative,
};

pub const FreeBusyStatus = enum {
    free,
    busy,
};

pub const CalendarCommonInfo = struct {
    identifier: []const u8,
    title: []const u8,
    content: []const u8,
    summary: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    geohash: ?[]const u8 = null,
    location_count: u16 = 0,
    participant_count: u16 = 0,
    hashtag_count: u16 = 0,
    reference_count: u16 = 0,
    calendar_count: u16 = 0,
};

pub const DateCalendarEventInfo = struct {
    common: CalendarCommonInfo,
    start_date: []const u8,
    end_date: ?[]const u8 = null,
};

pub const TimeCalendarEventInfo = struct {
    common: CalendarCommonInfo,
    start_time: u64,
    end_time: ?u64 = null,
    start_tzid: ?[]const u8 = null,
    end_tzid: ?[]const u8 = null,
    day_count: u16 = 0,
};

pub const CalendarInfo = struct {
    identifier: []const u8,
    title: []const u8,
    content: []const u8,
    event_count: u16 = 0,
};

pub const CalendarRsvpInfo = struct {
    identifier: []const u8,
    calendar_event: CalendarCoordinate,
    revision: ?EventRevision = null,
    status: AttendanceStatus,
    free_busy: ?FreeBusyStatus = null,
    author_pubkey: ?[32]u8 = null,
    author_relay_hint: ?[]const u8 = null,
    content: []const u8,
};

pub const BuiltTag = struct {
    items: [4][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded metadata from a `kind:31922` date-based calendar event.
pub fn date_calendar_event_extract(
    event: *const nip01_event.Event,
    out_locations: [][]const u8,
    out_participants: []CalendarParticipant,
    out_hashtags: [][]const u8,
    out_references: [][]const u8,
    out_calendars: []CalendarCoordinate,
) Nip52Error!DateCalendarEventInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_locations.len <= limits.tags_max);

    if (event.kind != date_calendar_event_kind) return error.InvalidDateEventKind;

    const common = try extract_common_info(event, out_locations, out_participants, out_hashtags, out_references, out_calendars);
    var start: ?[]const u8 = null;
    var end: ?[]const u8 = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "start")) start = try parse_date_tag(tag, &start, error.DuplicateStartTag, error.InvalidStartTag);
        if (std.mem.eql(u8, tag.items[0], "end")) end = try parse_date_tag(tag, &end, error.DuplicateEndTag, error.InvalidEndTag);
    }
    const start_date = start orelse return error.MissingStartTag;
    if (end) |end_date| if (std.mem.order(u8, start_date, end_date) != .lt) return error.InvalidDateRange;
    return .{ .common = common, .start_date = start_date, .end_date = end };
}

/// Extracts bounded metadata from a `kind:31923` time-based calendar event.
pub fn time_calendar_event_extract(
    event: *const nip01_event.Event,
    out_locations: [][]const u8,
    out_participants: []CalendarParticipant,
    out_hashtags: [][]const u8,
    out_references: [][]const u8,
    out_calendars: []CalendarCoordinate,
    out_days: []u64,
) Nip52Error!TimeCalendarEventInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_days.len <= limits.tags_max);

    if (event.kind != time_calendar_event_kind) return error.InvalidTimeEventKind;

    const common = try extract_common_info(event, out_locations, out_participants, out_hashtags, out_references, out_calendars);
    var info = TimeCalendarEventInfo{
        .common = common,
        .start_time = undefined,
    };
    var has_start = false;
    for (event.tags) |tag| {
        try apply_time_tag(tag, &info, &has_start, out_days);
    }
    if (!has_start) return error.MissingStartTag;
    if (info.end_time) |end_time| if (info.start_time >= end_time) return error.InvalidTimeRange;
    return info;
}

/// Extracts bounded metadata from a `kind:31924` calendar collection event.
pub fn calendar_extract(
    event: *const nip01_event.Event,
    out_events: []CalendarCoordinate,
) Nip52Error!CalendarInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_events.len <= limits.tags_max);

    if (event.kind != calendar_kind) return error.InvalidCalendarKind;

    var identifier: ?[]const u8 = null;
    var title: ?[]const u8 = null;
    var info = CalendarInfo{ .identifier = undefined, .title = undefined, .content = event.content };
    for (event.tags) |tag| {
        try apply_calendar_tag(tag, &identifier, &title, &info, out_events);
    }
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    info.title = title orelse return error.MissingTitleTag;
    return info;
}

/// Extracts bounded metadata from a `kind:31925` calendar RSVP event.
pub fn calendar_rsvp_extract(event: *const nip01_event.Event) Nip52Error!CalendarRsvpInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != calendar_rsvp_kind) return error.InvalidRsvpKind;

    var identifier: ?[]const u8 = null;
    var activity: ?CalendarCoordinate = null;
    var revision: ?EventRevision = null;
    var status: ?AttendanceStatus = null;
    var free_busy: ?FreeBusyStatus = null;
    var author_pubkey: ?[32]u8 = null;
    var author_relay_hint: ?[]const u8 = null;
    for (event.tags) |tag| {
        try apply_rsvp_tag(tag, &identifier, &activity, &revision, &status, &free_busy, &author_pubkey, &author_relay_hint);
    }
    if (status == .declined) free_busy = null;
    return .{
        .identifier = identifier orelse return error.MissingIdentifierTag,
        .calendar_event = activity orelse return error.InvalidCalendarTag,
        .revision = revision,
        .status = status orelse return error.MissingStatusTag,
        .free_busy = free_busy,
        .author_pubkey = author_pubkey,
        .author_relay_hint = author_relay_hint,
        .content = event.content,
    };
}

/// Builds a canonical calendar `d` tag.
pub fn calendar_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) Nip52Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical calendar `title` tag.
pub fn calendar_build_title_tag(
    output: *BuiltTag,
    title: []const u8,
) Nip52Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(title.len <= limits.tag_item_bytes_max);

    output.items[0] = "title";
    output.items[1] = parse_nonempty_utf8(title) catch return error.InvalidTitleTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical location tag.
pub fn calendar_build_location_tag(
    output: *BuiltTag,
    location: []const u8,
) Nip52Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(location.len <= limits.tag_item_bytes_max);

    output.items[0] = "location";
    output.items[1] = parse_nonempty_utf8(location) catch return error.InvalidLocationTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical participant `p` tag.
pub fn calendar_build_participant_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
    role: ?[]const u8,
) Nip52Error!nip01_event.EventTag {
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
    return output.as_event_tag();
}

/// Builds a canonical event-reference `a` tag for a calendar or RSVP.
pub fn calendar_build_coordinate_tag(
    output: *BuiltTag,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) Nip52Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(coordinate_text.len <= limits.tag_item_bytes_max);

    _ = parse_calendar_coordinate_text(coordinate_text) catch return error.InvalidCalendarTag;
    output.items[0] = "a";
    output.items[1] = coordinate_text;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidCalendarTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical `start` tag for a date-based event.
pub fn calendar_build_date_start_tag(
    output: *BuiltTag,
    date_text: []const u8,
) Nip52Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(date_text.len <= limits.tag_item_bytes_max);

    output.items[0] = "start";
    output.items[1] = parse_iso_date(date_text) catch return error.InvalidStartTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `D` day tag for a time-based event.
pub fn calendar_build_day_tag(
    output: *BuiltTag,
    day_index: u64,
) Nip52Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(day_index <= std.math.maxInt(u64));

    output.items[0] = "D";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{day_index}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical RSVP `status` tag.
pub fn calendar_build_status_tag(
    output: *BuiltTag,
    status: AttendanceStatus,
) Nip52Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromEnum(status) <= @intFromEnum(AttendanceStatus.tentative));

    output.items[0] = "status";
    output.items[1] = switch (status) {
        .accepted => "accepted",
        .declined => "declined",
        .tentative => "tentative",
    };
    output.item_count = 2;
    return output.as_event_tag();
}

fn extract_common_info(
    event: *const nip01_event.Event,
    out_locations: [][]const u8,
    out_participants: []CalendarParticipant,
    out_hashtags: [][]const u8,
    out_references: [][]const u8,
    out_calendars: []CalendarCoordinate,
) Nip52Error!CalendarCommonInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_locations.len <= limits.tags_max);

    var identifier: ?[]const u8 = null;
    var title: ?[]const u8 = null;
    var info = CalendarCommonInfo{
        .identifier = undefined,
        .title = undefined,
        .content = event.content,
    };
    for (event.tags) |tag| {
        try apply_common_tag(tag, &identifier, &title, &info, out_locations, out_participants, out_hashtags, out_references, out_calendars);
    }
    info.identifier = identifier orelse return error.MissingIdentifierTag;
    info.title = title orelse return error.MissingTitleTag;
    return info;
}

fn apply_common_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    title: *?[]const u8,
    info: *CalendarCommonInfo,
    out_locations: [][]const u8,
    out_participants: []CalendarParticipant,
    out_hashtags: [][]const u8,
    out_references: [][]const u8,
    out_calendars: []CalendarCoordinate,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, name, "title")) return apply_title_tag(tag, title);
    if (std.mem.eql(u8, name, "summary")) return apply_text_tag(tag, &info.summary, error.DuplicateSummaryTag, error.InvalidSummaryTag);
    if (std.mem.eql(u8, name, "image")) return apply_url_tag(tag, &info.image_url, error.DuplicateImageTag, error.InvalidImageTag);
    if (std.mem.eql(u8, name, "g")) return apply_text_tag(tag, &info.geohash, error.DuplicateGeohashTag, error.InvalidGeohashTag);
    if (std.mem.eql(u8, name, "location")) return append_text_value(tag, &info.location_count, out_locations, error.InvalidLocationTag);
    if (std.mem.eql(u8, name, "p")) return append_participant(tag, info, out_participants);
    if (std.mem.eql(u8, name, "t")) return append_text_value(tag, &info.hashtag_count, out_hashtags, error.InvalidHashtagTag);
    if (std.mem.eql(u8, name, "r")) return append_url_value(tag, &info.reference_count, out_references, error.InvalidReferenceTag);
    if (std.mem.eql(u8, name, "a")) return append_calendar(tag, info, out_calendars);
}

fn apply_time_tag(
    tag: nip01_event.EventTag,
    info: *TimeCalendarEventInfo,
    has_start: *bool,
    out_days: []u64,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "start")) return apply_time_start(tag, info, has_start);
    if (std.mem.eql(u8, name, "end")) return apply_time_end(tag, info);
    if (std.mem.eql(u8, name, "start_tzid")) return apply_text_tag(tag, &info.start_tzid, error.DuplicateStartTzidTag, error.InvalidStartTzidTag);
    if (std.mem.eql(u8, name, "end_tzid")) return apply_text_tag(tag, &info.end_tzid, error.DuplicateEndTzidTag, error.InvalidEndTzidTag);
    if (!std.mem.eql(u8, name, "D")) return;
    if (tag.items.len != 2) return error.InvalidDayTag;
    if (info.day_count == out_days.len) return error.BufferTooSmall;
    out_days[info.day_count] = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch {
        return error.InvalidDayTag;
    };
    info.day_count += 1;
}

fn apply_calendar_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    title: *?[]const u8,
    info: *CalendarInfo,
    out_events: []CalendarCoordinate,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, tag.items[0], "title")) return apply_title_tag(tag, title);
    if (!std.mem.eql(u8, tag.items[0], "a")) return;
    if (tag.items.len < 2) return error.InvalidCalendarTag;
    if (info.event_count == out_events.len) return error.BufferTooSmall;
    var parsed = parse_calendar_coordinate_text(tag.items[1]) catch return error.InvalidCalendarTag;
    parsed.relay_hint = parse_optional_url_item(tag, 2, error.InvalidCalendarTag) catch {
        return error.InvalidCalendarTag;
    };
    out_events[info.event_count] = parsed;
    info.event_count += 1;
}

fn apply_rsvp_tag(
    tag: nip01_event.EventTag,
    identifier: *?[]const u8,
    activity: *?CalendarCoordinate,
    revision: *?EventRevision,
    status: *?AttendanceStatus,
    free_busy: *?FreeBusyStatus,
    author_pubkey: *?[32]u8,
    author_relay_hint: *?[]const u8,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, name, "a")) return apply_rsvp_activity(tag, activity);
    if (std.mem.eql(u8, name, "e")) return apply_rsvp_revision(tag, revision);
    if (std.mem.eql(u8, name, "status")) return apply_rsvp_status(tag, status);
    if (std.mem.eql(u8, name, "fb")) return apply_free_busy(tag, free_busy);
    if (std.mem.eql(u8, name, "p")) return apply_rsvp_author(tag, author_pubkey, author_relay_hint);
}

fn apply_identifier_tag(tag: nip01_event.EventTag, identifier: *?[]const u8) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(identifier) != 0);

    if (identifier.* != null) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    identifier.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn apply_title_tag(tag: nip01_event.EventTag, title: *?[]const u8) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(title) != 0);

    if (title.* != null) return error.DuplicateTitleTag;
    if (tag.items.len != 2) return error.InvalidTitleTag;
    title.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTitleTag;
}

fn apply_text_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: Nip52Error,
    invalid_error: Nip52Error,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
}

fn apply_url_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: Nip52Error,
    invalid_error: Nip52Error,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_url(tag.items[1]) catch return invalid_error;
}

fn parse_date_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: Nip52Error,
    invalid_error: Nip52Error,
) Nip52Error![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    const parsed = parse_iso_date(tag.items[1]) catch return invalid_error;
    field.* = parsed;
    return parsed;
}

fn append_text_value(
    tag: nip01_event.EventTag,
    count: *u16,
    out: [][]const u8,
    invalid_error: Nip52Error,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(count) != 0);

    if (tag.items.len != 2) return invalid_error;
    if (count.* == out.len) return error.BufferTooSmall;
    out[count.*] = parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
    count.* += 1;
}

fn append_url_value(
    tag: nip01_event.EventTag,
    count: *u16,
    out: [][]const u8,
    invalid_error: Nip52Error,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(count) != 0);

    if (tag.items.len != 2) return invalid_error;
    if (count.* == out.len) return error.BufferTooSmall;
    out[count.*] = parse_url(tag.items[1]) catch return invalid_error;
    count.* += 1;
}

fn append_participant(
    tag: nip01_event.EventTag,
    info: *CalendarCommonInfo,
    out: []CalendarParticipant,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out.len <= limits.tags_max);

    if (tag.items.len < 2 or tag.items.len > 4) return error.InvalidParticipantTag;
    if (info.participant_count == out.len) return error.BufferTooSmall;
    out[info.participant_count] = .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidParticipantTag,
        .relay_hint = parse_optional_url_item(tag, 2, error.InvalidParticipantTag) catch {
            return error.InvalidParticipantTag;
        },
        .role = parse_optional_text_item(tag, 3, error.InvalidParticipantTag) catch {
            return error.InvalidParticipantTag;
        },
    };
    info.participant_count += 1;
}

fn append_calendar(tag: nip01_event.EventTag, info: *CalendarCommonInfo, out: []CalendarCoordinate) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(out.len <= limits.tags_max);

    if (tag.items.len < 2) return error.InvalidCalendarTag;
    if (info.calendar_count == out.len) return error.BufferTooSmall;
    var parsed = parse_calendar_coordinate_text(tag.items[1]) catch return error.InvalidCalendarTag;
    parsed.relay_hint = parse_optional_url_item(tag, 2, error.InvalidCalendarTag) catch {
        return error.InvalidCalendarTag;
    };
    out[info.calendar_count] = parsed;
    info.calendar_count += 1;
}

fn apply_time_start(tag: nip01_event.EventTag, info: *TimeCalendarEventInfo, has_start: *bool) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (has_start.*) return error.DuplicateStartTag;
    if (tag.items.len != 2) return error.InvalidStartTag;
    info.start_time = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch return error.InvalidStartTag;
    has_start.* = true;
}

fn apply_time_end(tag: nip01_event.EventTag, info: *TimeCalendarEventInfo) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.end_time != null) return error.DuplicateEndTag;
    if (tag.items.len != 2) return error.InvalidEndTag;
    info.end_time = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch return error.InvalidEndTag;
}

fn apply_rsvp_activity(tag: nip01_event.EventTag, activity: *?CalendarCoordinate) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(activity) != 0);

    if (activity.* != null) return error.InvalidCalendarTag;
    if (tag.items.len < 2) return error.InvalidCalendarTag;
    var parsed = parse_calendar_coordinate_text(tag.items[1]) catch return error.InvalidCalendarTag;
    parsed.relay_hint = parse_optional_url_item(tag, 2, error.InvalidCalendarTag) catch {
        return error.InvalidCalendarTag;
    };
    activity.* = parsed;
}

fn apply_rsvp_revision(tag: nip01_event.EventTag, revision: *?EventRevision) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(revision) != 0);

    if (revision.* != null) return error.DuplicateRevisionTag;
    if (tag.items.len < 2) return error.InvalidRevisionTag;
    revision.* = .{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidRevisionTag,
        .relay_hint = parse_optional_url_item(tag, 2, error.InvalidRevisionTag) catch {
            return error.InvalidRevisionTag;
        },
    };
}

fn apply_rsvp_status(tag: nip01_event.EventTag, status: *?AttendanceStatus) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(status) != 0);

    if (status.* != null) return error.DuplicateStatusTag;
    if (tag.items.len != 2) return error.InvalidStatusTag;
    status.* = parse_attendance_status(tag.items[1]) catch return error.InvalidStatusTag;
}

fn apply_free_busy(tag: nip01_event.EventTag, free_busy: *?FreeBusyStatus) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(free_busy) != 0);

    if (free_busy.* != null) return error.DuplicateFreeBusyTag;
    if (tag.items.len != 2) return error.InvalidFreeBusyTag;
    free_busy.* = parse_free_busy_status(tag.items[1]) catch return error.InvalidFreeBusyTag;
}

fn apply_rsvp_author(
    tag: nip01_event.EventTag,
    pubkey: *?[32]u8,
    relay_hint: *?[]const u8,
) Nip52Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(pubkey) != 0);

    if (pubkey.* != null) return error.DuplicateAuthorTag;
    if (tag.items.len < 2) return error.InvalidAuthorTag;
    pubkey.* = parse_lower_hex_32(tag.items[1]) catch return error.InvalidAuthorTag;
    relay_hint.* = parse_optional_url_item(tag, 2, error.InvalidAuthorTag) catch {
        return error.InvalidAuthorTag;
    };
}

fn parse_calendar_coordinate_text(text: []const u8) error{InvalidCoordinate}!CalendarCoordinate {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidCoordinate;
    const second_colon = std.mem.indexOfScalarPos(u8, text, first_colon + 1, ':') orelse {
        return error.InvalidCoordinate;
    };
    const kind = std.fmt.parseUnsigned(u32, text[0..first_colon], 10) catch {
        return error.InvalidCoordinate;
    };
    if (kind != date_calendar_event_kind and kind != time_calendar_event_kind) {
        return error.InvalidCoordinate;
    }
    return .{
        .kind = kind,
        .pubkey = parse_lower_hex_32(text[first_colon + 1 .. second_colon]) catch {
            return error.InvalidCoordinate;
        },
        .identifier = parse_nonempty_utf8(text[second_colon + 1 ..]) catch {
            return error.InvalidCoordinate;
        },
    };
}

fn parse_attendance_status(text: []const u8) error{InvalidStatus}!AttendanceStatus {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (std.mem.eql(u8, text, "accepted")) return .accepted;
    if (std.mem.eql(u8, text, "declined")) return .declined;
    if (std.mem.eql(u8, text, "tentative")) return .tentative;
    return error.InvalidStatus;
}

fn parse_free_busy_status(text: []const u8) error{InvalidStatus}!FreeBusyStatus {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (std.mem.eql(u8, text, "free")) return .free;
    if (std.mem.eql(u8, text, "busy")) return .busy;
    return error.InvalidStatus;
}

fn parse_iso_date(text: []const u8) error{InvalidDate}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len != 10) return error.InvalidDate;
    if (text[4] != '-' or text[7] != '-') return error.InvalidDate;
    for ([_]usize{ 0, 1, 2, 3, 5, 6, 8, 9 }) |index| {
        if (!std.ascii.isDigit(text[index])) return error.InvalidDate;
    }
    return text;
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

    _ = parse_nonempty_utf8(text) catch return error.InvalidUrl;
    const uri = std.Uri.parse(text) catch return error.InvalidUrl;
    if (uri.scheme.len == 0) return error.InvalidUrl;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return lower_hex_32.parse(text);
}

test "NIP-52 extracts date-based calendar metadata" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "event-1" } },
        .{ .items = &.{ "title", "Conference" } },
        .{ .items = &.{ "start", "2026-03-18" } },
        .{ .items = &.{ "end", "2026-03-20" } },
        .{ .items = &.{ "location", "Lisbon" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x52} ** 32,
        .pubkey = [_]u8{0x31} ** 32,
        .created_at = 1,
        .kind = date_calendar_event_kind,
        .tags = tags[0..],
        .content = "desc",
        .sig = [_]u8{0x41} ** 64,
    };
    var locations: [1][]const u8 = undefined;
    var participants: [1]CalendarParticipant = undefined;
    var hashtags: [1][]const u8 = undefined;
    var refs: [1][]const u8 = undefined;
    var calendars: [1]CalendarCoordinate = undefined;

    const info = try date_calendar_event_extract(
        &event,
        locations[0..],
        participants[0..],
        hashtags[0..],
        refs[0..],
        calendars[0..],
    );

    try std.testing.expectEqualStrings("event-1", info.common.identifier);
    try std.testing.expectEqualStrings("2026-03-18", info.start_date);
    try std.testing.expectEqual(@as(u16, 1), info.common.location_count);
}

test "NIP-52 extracts calendar RSVP metadata" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "rsvp-1" } },
        .{ .items = &.{ "a", "31923:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:event-1" } },
        .{ .items = &.{ "status", "accepted" } },
        .{ .items = &.{ "fb", "busy" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x53} ** 32,
        .pubkey = [_]u8{0x32} ** 32,
        .created_at = 2,
        .kind = calendar_rsvp_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x42} ** 64,
    };

    const info = try calendar_rsvp_extract(&event);

    try std.testing.expectEqual(.accepted, info.status);
    try std.testing.expectEqual(.busy, info.free_busy.?);
    try std.testing.expectEqualStrings("rsvp-1", info.identifier);
}

test "NIP-52 builds participant tag" {
    var built: BuiltTag = .{};

    const tag = try calendar_build_participant_tag(
        &built,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "wss://relay.example",
        "speaker",
    );

    try std.testing.expectEqualStrings("p", tag.items[0]);
    try std.testing.expectEqualStrings("speaker", tag.items[3]);
}
