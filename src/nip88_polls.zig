const std = @import("std");
const relay_origin = @import("internal/relay_origin.zig");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const poll_kind: u32 = 1068;
pub const poll_response_kind: u32 = 1018;

pub const PollError = error{
    UnsupportedKind,
    MissingOptionTag,
    DuplicateOptionId,
    InvalidOptionTag,
    InvalidRelayTag,
    DuplicatePollTypeTag,
    InvalidPollTypeTag,
    DuplicateEndsAtTag,
    InvalidEndsAtTag,
    InvalidContent,
    MissingPollEventTag,
    DuplicatePollEventTag,
    InvalidPollEventTag,
    MissingResponseTag,
    InvalidResponseTag,
    BufferTooSmall,
};

pub const PollType = enum {
    singlechoice,
    multiplechoice,

    pub fn as_text(self: PollType) []const u8 {
        std.debug.assert(@intFromEnum(self) <= std.math.maxInt(u8));
        std.debug.assert(@typeInfo(PollType).@"enum".fields.len == 2);

        return switch (self) {
            .singlechoice => "singlechoice",
            .multiplechoice => "multiplechoice",
        };
    }
};

pub const PollOption = struct {
    id: []const u8,
    label: []const u8,
};

pub const Poll = struct {
    content: []const u8,
    poll_type: PollType = .singlechoice,
    ends_at: ?u64 = null,
    option_count: u16 = 0,
    relay_count: u16 = 0,
};

pub const EventRef = struct {
    poll_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const Response = struct {
    poll_id: [32]u8,
    relay_hint: ?[]const u8 = null,
    response_count: u16 = 0,
};

pub const CountedResponse = struct {
    pubkey: [32]u8,
    event_id: [32]u8,
    created_at: u64,
    response_event: *const nip01_event.Event,
};

pub const OptionTally = struct {
    id: []const u8,
    label: []const u8,
    vote_count: u32 = 0,
};

pub const PollTally = struct {
    poll_type: PollType,
    option_count: u16,
    candidate_pubkey_count: u16 = 0,
    counted_pubkey_count: u16 = 0,
};

const poll_index_cache_capacity: usize = @as(usize, limits.tags_max) * 2;
const poll_index_cache_empty: u16 = std.math.maxInt(u16);

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded NIP-88 poll metadata, ordered options, and ordered relays.
pub fn poll_extract(
    event: *const nip01_event.Event,
    out_options: []PollOption,
    out_relays: [][]const u8,
) PollError!Poll {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_options.len <= limits.tags_max);
    std.debug.assert(out_relays.len <= limits.tags_max);

    if (event.kind != poll_kind) return error.UnsupportedKind;
    try validate_content(event.content, false);

    var info = Poll{ .content = event.content };
    var saw_poll_type = false;
    var saw_ends_at = false;
    for (event.tags) |tag| {
        try apply_poll_tag(
            tag,
            &info,
            out_options,
            out_relays,
            &saw_poll_type,
            &saw_ends_at,
        );
    }
    if (info.option_count == 0) return error.MissingOptionTag;
    return info;
}

/// Extracts bounded NIP-88 poll-response metadata plus ordered response option ids.
pub fn poll_response_extract(
    event: *const nip01_event.Event,
    out_responses: [][]const u8,
) PollError!Response {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_responses.len <= limits.tags_max);

    if (event.kind != poll_response_kind) return error.UnsupportedKind;
    try validate_content(event.content, true);

    var info = Response{
        .poll_id = undefined,
    };
    var saw_event_tag = false;
    for (event.tags) |tag| {
        try apply_response_tag(tag, &info, out_responses, &saw_event_tag);
    }
    if (!saw_event_tag) return error.MissingPollEventTag;
    if (info.response_count == 0) return error.MissingResponseTag;
    return info;
}

/// Builds a canonical poll `option` tag.
pub fn poll_build_option_tag(
    output: *BuiltTag,
    option: PollOption,
) PollError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len >= 3);

    output.items[0] = "option";
    output.items[1] = parse_option_id(option.id) catch return error.InvalidOptionTag;
    output.items[2] = parse_nonempty_utf8(option.label) catch return error.InvalidOptionTag;
    output.item_count = 3;
    return output.as_event_tag();
}

/// Builds a canonical poll `relay` tag.
pub fn poll_build_relay_tag(
    output: *BuiltTag,
    relay_url: []const u8,
) PollError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len >= 2);

    output.items[0] = "relay";
    output.items[1] = parse_relay_url(relay_url) catch return error.InvalidRelayTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical poll `polltype` tag.
pub fn poll_build_poll_type_tag(
    output: *BuiltTag,
    poll_type: PollType,
) PollError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@typeInfo(PollType).@"enum".fields.len == 2);

    output.items[0] = "polltype";
    output.items[1] = poll_type.as_text();
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical poll `endsAt` tag.
pub fn poll_build_ends_at_tag(
    output: *BuiltTag,
    ends_at: u64,
) PollError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.text_storage.len >= 20);

    output.items[0] = "endsAt";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{ends_at}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical poll-response `e` tag with an optional relay hint.
pub fn poll_response_build_event_tag(
    output: *BuiltTag,
    reference: EventRef,
) PollError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.text_storage.len >= limits.id_hex_length);

    output.items[0] = "e";
    output.items[1] = write_lower_hex_32(
        output.text_storage[0..limits.id_hex_length],
        reference.poll_id,
    );
    output.item_count = 2;
    if (reference.relay_hint) |relay_hint| {
        output.items[2] = parse_relay_url(relay_hint) catch return error.InvalidPollEventTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical poll-response `response` tag.
pub fn poll_response_build_response_tag(
    output: *BuiltTag,
    option_id: []const u8,
) PollError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len >= 2);

    output.items[0] = "response";
    output.items[1] = parse_option_id(option_id) catch return error.InvalidResponseTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Reduces fetched NIP-88 responses into one latest candidate per pubkey and option vote counts.
pub fn poll_tally_reduce(
    poll_event: *const nip01_event.Event,
    response_events: []const nip01_event.Event,
    out_latest_responses: []CountedResponse,
    out_option_tallies: []OptionTally,
) PollError!PollTally {
    std.debug.assert(@intFromPtr(poll_event) != 0);
    std.debug.assert(out_latest_responses.len <= limits.tags_max);
    std.debug.assert(out_option_tallies.len <= limits.tags_max);

    const poll = try poll_extract_tallies(poll_event, out_option_tallies);
    var option_index_cache = OptionIndexCache{};
    option_index_cache.load(out_option_tallies[0..poll.option_count]);
    var response_index_cache = ResponseIndexCache{};
    var tally = PollTally{
        .poll_type = poll.poll_type,
        .option_count = poll.option_count,
    };
    for (response_events) |*response_event| {
        const candidate = response_candidate_for_poll(poll_event, &poll, response_event) orelse {
            continue;
        };
        try response_index_cache.upsert(
            out_latest_responses,
            &tally.candidate_pubkey_count,
            candidate,
        );
    }
    for (out_latest_responses[0..tally.candidate_pubkey_count]) |counted| {
        const counted_vote = count_votes_for_response(
            poll.poll_type,
            counted.response_event,
            out_option_tallies[0..poll.option_count],
            &option_index_cache,
        );
        if (counted_vote) tally.counted_pubkey_count += 1;
    }
    return tally;
}

fn apply_poll_tag(
    tag: nip01_event.EventTag,
    info: *Poll,
    out_options: []PollOption,
    out_relays: [][]const u8,
    saw_poll_type: *bool,
    saw_ends_at: *bool,
) PollError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_poll_type) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "option")) return apply_option_tag(tag, info, out_options);
    if (std.mem.eql(u8, name, "relay")) return apply_relay_tag(tag, info, out_relays);
    if (std.mem.eql(u8, name, "polltype")) {
        if (saw_poll_type.*) return error.DuplicatePollTypeTag;
        info.poll_type = parse_poll_type_tag(tag) catch return error.InvalidPollTypeTag;
        saw_poll_type.* = true;
        return;
    }
    if (std.mem.eql(u8, name, "endsAt")) {
        if (saw_ends_at.*) return error.DuplicateEndsAtTag;
        info.ends_at = parse_ends_at_tag(tag) catch return error.InvalidEndsAtTag;
        saw_ends_at.* = true;
    }
}

fn apply_option_tag(
    tag: nip01_event.EventTag,
    info: *Poll,
    out_options: []PollOption,
) PollError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_options.len <= limits.tags_max);

    const option = parse_option_tag(tag) catch return error.InvalidOptionTag;
    if (find_duplicate_option(out_options[0..info.option_count], option.id)) {
        return error.DuplicateOptionId;
    }
    if (info.option_count == out_options.len) return error.BufferTooSmall;
    out_options[info.option_count] = option;
    info.option_count += 1;
}

fn apply_relay_tag(
    tag: nip01_event.EventTag,
    info: *Poll,
    out_relays: [][]const u8,
) PollError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_relays.len <= limits.tags_max);

    const relay_url = parse_relay_tag(tag) catch return error.InvalidRelayTag;
    if (info.relay_count == out_relays.len) return error.BufferTooSmall;
    out_relays[info.relay_count] = relay_url;
    info.relay_count += 1;
}

fn apply_response_tag(
    tag: nip01_event.EventTag,
    info: *Response,
    out_responses: [][]const u8,
    saw_event_tag: *bool,
) PollError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_event_tag) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "e")) {
        if (saw_event_tag.*) return error.DuplicatePollEventTag;
        const reference = parse_poll_event_tag(tag) catch return error.InvalidPollEventTag;
        info.poll_id = reference.poll_id;
        info.relay_hint = reference.relay_hint;
        saw_event_tag.* = true;
        return;
    }
    if (!std.mem.eql(u8, name, "response")) return;

    const response_id = parse_response_tag(tag) catch return error.InvalidResponseTag;
    if (info.response_count == out_responses.len) return error.BufferTooSmall;
    out_responses[info.response_count] = response_id;
    info.response_count += 1;
}

fn poll_extract_tallies(
    event: *const nip01_event.Event,
    out_option_tallies: []OptionTally,
) PollError!Poll {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_option_tallies.len <= limits.tags_max);

    if (event.kind != poll_kind) return error.UnsupportedKind;
    try validate_content(event.content, false);

    var info = Poll{ .content = event.content };
    var saw_poll_type = false;
    var saw_ends_at = false;
    for (event.tags) |tag| {
        try apply_poll_tally_tag(
            tag,
            &info,
            out_option_tallies,
            &saw_poll_type,
            &saw_ends_at,
        );
    }
    if (info.option_count == 0) return error.MissingOptionTag;
    return info;
}

fn apply_poll_tally_tag(
    tag: nip01_event.EventTag,
    info: *Poll,
    out_option_tallies: []OptionTally,
    saw_poll_type: *bool,
    saw_ends_at: *bool,
) PollError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_ends_at) != 0);

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "option")) {
        return apply_option_tally_tag(tag, info, out_option_tallies);
    }
    if (std.mem.eql(u8, name, "polltype")) {
        if (saw_poll_type.*) return error.DuplicatePollTypeTag;
        info.poll_type = parse_poll_type_tag(tag) catch return error.InvalidPollTypeTag;
        saw_poll_type.* = true;
        return;
    }
    if (std.mem.eql(u8, name, "endsAt")) {
        if (saw_ends_at.*) return error.DuplicateEndsAtTag;
        info.ends_at = parse_ends_at_tag(tag) catch return error.InvalidEndsAtTag;
        saw_ends_at.* = true;
        return;
    }
    if (std.mem.eql(u8, name, "relay")) {
        _ = parse_relay_tag(tag) catch return error.InvalidRelayTag;
        info.relay_count += 1;
    }
}

fn apply_option_tally_tag(
    tag: nip01_event.EventTag,
    info: *Poll,
    out_option_tallies: []OptionTally,
) PollError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_option_tallies.len <= limits.tags_max);

    const option = parse_option_tag(tag) catch return error.InvalidOptionTag;
    const used = out_option_tallies[0..info.option_count];
    if (find_duplicate_tally_option(used, option.id)) return error.DuplicateOptionId;
    if (info.option_count == out_option_tallies.len) return error.BufferTooSmall;
    out_option_tallies[info.option_count] = .{ .id = option.id, .label = option.label };
    info.option_count += 1;
}

fn response_candidate_for_poll(
    poll_event: *const nip01_event.Event,
    poll: *const Poll,
    response_event: *const nip01_event.Event,
) ?CountedResponse {
    std.debug.assert(@intFromPtr(poll_event) != 0);
    std.debug.assert(@intFromPtr(response_event) != 0);

    if (response_event.kind != poll_response_kind) return null;
    if (validate_content(response_event.content, true)) |_| {} else |_| return null;
    if (!event_references_poll(response_event, &poll_event.id)) return null;
    if (!response_within_poll_limits(poll.ends_at, response_event.created_at)) return null;
    return .{
        .pubkey = response_event.pubkey,
        .event_id = response_event.id,
        .created_at = response_event.created_at,
        .response_event = response_event,
    };
}

fn event_references_poll(event: *const nip01_event.Event, poll_id: *const [32]u8) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(poll_id) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    var saw_event_tag = false;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "e")) {
            if (saw_event_tag) return false;
            const reference = parse_poll_event_tag(tag) catch return false;
            if (!std.mem.eql(u8, &reference.poll_id, poll_id)) return false;
            saw_event_tag = true;
        }
    }
    return saw_event_tag;
}

fn response_within_poll_limits(ends_at: ?u64, created_at: u64) bool {
    std.debug.assert(created_at <= std.math.maxInt(u64));
    std.debug.assert(@sizeOf(u64) == 8);

    if (ends_at) |value| {
        if (created_at > value) return false;
    }
    return true;
}

fn counted_response_should_replace(existing: CountedResponse, candidate: CountedResponse) bool {
    std.debug.assert(existing.created_at <= std.math.maxInt(u64));
    std.debug.assert(candidate.created_at <= std.math.maxInt(u64));

    if (candidate.created_at > existing.created_at) return true;
    if (candidate.created_at < existing.created_at) return false;
    return std.mem.order(u8, &candidate.event_id, &existing.event_id) == .gt;
}

fn count_votes_for_response(
    poll_type: PollType,
    response_event: *const nip01_event.Event,
    option_tallies: []OptionTally,
    option_index_cache: *const OptionIndexCache,
) bool {
    std.debug.assert(@intFromPtr(response_event) != 0);
    std.debug.assert(option_tallies.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(option_index_cache) != 0);

    return switch (poll_type) {
        .singlechoice => count_singlechoice_vote(
            response_event,
            option_tallies,
            option_index_cache,
        ),
        .multiplechoice => count_multiplechoice_votes(
            response_event,
            option_tallies,
            option_index_cache,
        ),
    };
}

fn count_singlechoice_vote(
    response_event: *const nip01_event.Event,
    option_tallies: []OptionTally,
    option_index_cache: *const OptionIndexCache,
) bool {
    std.debug.assert(@intFromPtr(response_event) != 0);
    std.debug.assert(option_tallies.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(option_index_cache) != 0);

    for (response_event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "response")) continue;
        const option_id = parse_response_tag(tag) catch return false;
        const index = option_index_cache.find(option_tallies, option_id) orelse return false;
        option_tallies[index].vote_count += 1;
        return true;
    }
    return false;
}

fn count_multiplechoice_votes(
    response_event: *const nip01_event.Event,
    option_tallies: []OptionTally,
    option_index_cache: *const OptionIndexCache,
) bool {
    std.debug.assert(@intFromPtr(response_event) != 0);
    std.debug.assert(option_tallies.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(option_index_cache) != 0);

    var seen: [limits.tags_max]bool = [_]bool{false} ** limits.tags_max;
    var counted = false;
    for (response_event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "response")) continue;
        const option_id = parse_response_tag(tag) catch return false;
        const index = option_index_cache.find(option_tallies, option_id) orelse continue;
        if (seen[index]) continue;
        option_tallies[index].vote_count += 1;
        seen[index] = true;
        counted = true;
    }
    return counted;
}

fn find_duplicate_option(options: []const PollOption, option_id: []const u8) bool {
    std.debug.assert(options.len <= limits.tags_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    for (options) |option| {
        if (std.mem.eql(u8, option.id, option_id)) return true;
    }
    return false;
}

fn find_duplicate_tally_option(option_tallies: []const OptionTally, option_id: []const u8) bool {
    std.debug.assert(option_tallies.len <= limits.tags_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    for (option_tallies) |option_tally| {
        if (std.mem.eql(u8, option_tally.id, option_id)) return true;
    }
    return false;
}

fn find_counted_response(counted_responses: []const CountedResponse, pubkey: *const [32]u8) ?u16 {
    std.debug.assert(counted_responses.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(pubkey) != 0);

    for (counted_responses, 0..) |counted_response, index| {
        if (std.mem.eql(u8, &counted_response.pubkey, pubkey)) return @intCast(index);
    }
    return null;
}

fn find_option_tally(option_tallies: []const OptionTally, option_id: []const u8) ?u16 {
    std.debug.assert(option_tallies.len <= limits.tags_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    for (option_tallies, 0..) |option_tally, index| {
        if (std.mem.eql(u8, option_tally.id, option_id)) return @intCast(index);
    }
    return null;
}

const ResponseIndexCache = struct {
    slots: [poll_index_cache_capacity]u16 = [_]u16{poll_index_cache_empty} **
        poll_index_cache_capacity,

    fn upsert(
        self: *ResponseIndexCache,
        counted_responses: []CountedResponse,
        counted_response_count: *u16,
        candidate: CountedResponse,
    ) PollError!void {
        std.debug.assert(@intFromPtr(counted_response_count) != 0);
        std.debug.assert(@intFromPtr(self) != 0);

        if (self.find(counted_responses, &candidate.pubkey)) |index| {
            if (counted_response_should_replace(counted_responses[index], candidate)) {
                counted_responses[index] = candidate;
            }
            return;
        }
        if (counted_response_count.* == counted_responses.len) return error.BufferTooSmall;
        const new_index = counted_response_count.*;
        counted_responses[new_index] = candidate;
        counted_response_count.* += 1;
        self.insert_known(counted_responses, new_index);
    }

    fn find(
        self: *const ResponseIndexCache,
        counted_responses: []const CountedResponse,
        pubkey: *const [32]u8,
    ) ?u16 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(@intFromPtr(pubkey) != 0);

        var slot = cache_slot_for_bytes(pubkey[0..]);
        var probe_count: usize = 0;
        while (probe_count < self.slots.len) : (probe_count += 1) {
            const index = self.slots[slot];
            if (index == poll_index_cache_empty) return null;
            if (std.mem.eql(u8, &counted_responses[index].pubkey, pubkey)) return index;
            slot = cache_slot_advance(slot);
        }
        return null;
    }

    fn insert_known(self: *ResponseIndexCache, counted_responses: []const CountedResponse, index: u16) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(index < counted_responses.len);

        var slot = cache_slot_for_bytes(counted_responses[index].pubkey[0..]);
        while (self.slots[slot] != poll_index_cache_empty) {
            slot = cache_slot_advance(slot);
        }
        self.slots[slot] = index;
    }
};

const OptionIndexCache = struct {
    slots: [poll_index_cache_capacity]u16 = [_]u16{poll_index_cache_empty} **
        poll_index_cache_capacity,

    fn load(self: *OptionIndexCache, option_tallies: []const OptionTally) void {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(option_tallies.len <= limits.tags_max);

        for (option_tallies, 0..) |option_tally, index| {
            var slot = cache_slot_for_bytes(option_tally.id);
            while (self.slots[slot] != poll_index_cache_empty) {
                slot = cache_slot_advance(slot);
            }
            self.slots[slot] = @intCast(index);
        }
    }

    fn find(self: *const OptionIndexCache, option_tallies: []const OptionTally, option_id: []const u8) ?u16 {
        std.debug.assert(@intFromPtr(self) != 0);
        std.debug.assert(option_tallies.len <= limits.tags_max);

        var slot = cache_slot_for_bytes(option_id);
        var probe_count: usize = 0;
        while (probe_count < self.slots.len) : (probe_count += 1) {
            const index = self.slots[slot];
            if (index == poll_index_cache_empty) return null;
            if (std.mem.eql(u8, option_tallies[index].id, option_id)) return index;
            slot = cache_slot_advance(slot);
        }
        return null;
    }
};

fn cache_slot_for_bytes(bytes: []const u8) usize {
    std.debug.assert(poll_index_cache_capacity > 0);
    std.debug.assert(std.math.isPowerOfTwo(poll_index_cache_capacity));

    const hash = std.hash.Wyhash.hash(0, bytes);
    return @intCast(hash & (poll_index_cache_capacity - 1));
}

fn cache_slot_advance(slot: usize) usize {
    std.debug.assert(slot < poll_index_cache_capacity);
    std.debug.assert(std.math.isPowerOfTwo(poll_index_cache_capacity));

    return (slot + 1) & (poll_index_cache_capacity - 1);
}

fn parse_option_tag(tag: nip01_event.EventTag) error{InvalidValue}!PollOption {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 3);

    if (tag.items.len != 3) return error.InvalidValue;
    return .{
        .id = parse_option_id(tag.items[1]) catch return error.InvalidValue,
        .label = parse_nonempty_utf8(tag.items[2]) catch return error.InvalidValue,
    };
}

fn parse_relay_tag(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_relay_url(tag.items[1]) catch return error.InvalidValue;
}

fn parse_poll_type_tag(tag: nip01_event.EventTag) error{InvalidValue}!PollType {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@typeInfo(PollType).@"enum".fields.len == 2);

    if (tag.items.len != 2) return error.InvalidValue;
    if (std.mem.eql(u8, tag.items[1], "singlechoice")) return .singlechoice;
    if (std.mem.eql(u8, tag.items[1], "multiplechoice")) return .multiplechoice;
    return error.InvalidValue;
}

fn parse_ends_at_tag(tag: nip01_event.EventTag) error{InvalidValue}!u64 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@sizeOf(u64) == 8);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_timestamp(tag.items[1]) catch return error.InvalidValue;
}

fn parse_poll_event_tag(tag: nip01_event.EventTag) error{InvalidValue}!EventRef {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.id_hex_length == 64);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidValue;
    var reference = EventRef{
        .poll_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidValue,
    };
    if (tag.items.len == 3) {
        reference.relay_hint = parse_relay_url(tag.items[2]) catch return error.InvalidValue;
    }
    return reference;
}

fn parse_response_tag(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_option_id(tag.items[1]) catch return error.InvalidValue;
}

fn parse_option_id(text: []const u8) error{InvalidValue}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidValue;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidValue;
    for (text) |byte| {
        if (std.ascii.isAlphanumeric(byte)) continue;
        return error.InvalidValue;
    }
    return text;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (text.len == 0) return error.InvalidUtf8;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_relay_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUrl;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUrl;
    if (relay_origin.parse_websocket_origin(text) == null) return error.InvalidUrl;
    return text;
}

fn parse_timestamp(text: []const u8) error{InvalidValue}!u64 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);
    std.debug.assert(@sizeOf(u64) == 8);

    if (text.len == 0) return error.InvalidValue;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidValue;
    return std.fmt.parseUnsigned(u64, text, 10) catch return error.InvalidValue;
}

fn validate_content(content: []const u8, allow_empty: bool) PollError!void {
    std.debug.assert(limits.content_bytes_max > 0);
    std.debug.assert(@sizeOf(bool) == 1);

    if (content.len > limits.content_bytes_max) return error.InvalidContent;
    if (!allow_empty and content.len == 0) return error.InvalidContent;
    if (!std.unicode.utf8ValidateSlice(content)) return error.InvalidContent;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn write_lower_hex_32(output: []u8, bytes: [32]u8) []const u8 {
    std.debug.assert(output.len >= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    const encoded = std.fmt.bytesToHex(bytes, .lower);
    @memcpy(output[0..limits.id_hex_length], encoded[0..limits.id_hex_length]);
    return output[0..limits.id_hex_length];
}

fn test_event(
    kind: u32,
    id_byte: u8,
    pubkey_byte: u8,
    created_at: u64,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{id_byte} ** 32,
        .pubkey = [_]u8{pubkey_byte} ** 32,
        .sig = [_]u8{0xaa} ** 64,
        .kind = kind,
        .created_at = created_at,
        .content = content,
        .tags = tags,
    };
}

test "poll extract parses options relays defaults and endsAt" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
        .{ .items = &.{ "option", "opt2", "Blue" } },
        .{ .items = &.{ "relay", "wss://relay.one" } },
        .{ .items = &.{ "polltype", "multiplechoice" } },
        .{ .items = &.{ "endsAt", "1719889000" } },
        .{ .items = &.{ "t", "ignored" } },
    };
    const event = test_event(poll_kind, 0x10, 0x20, 1_719_888_000, "Favorite color?", tags[0..]);
    var options: [4]PollOption = undefined;
    var relays: [2][]const u8 = undefined;

    const poll = try poll_extract(&event, options[0..], relays[0..]);

    try std.testing.expectEqualStrings("Favorite color?", poll.content);
    try std.testing.expectEqual(PollType.multiplechoice, poll.poll_type);
    try std.testing.expectEqual(@as(?u64, 1_719_889_000), poll.ends_at);
    try std.testing.expectEqual(@as(u16, 2), poll.option_count);
    try std.testing.expectEqual(@as(u16, 1), poll.relay_count);
    try std.testing.expectEqualStrings("opt1", options[0].id);
    try std.testing.expectEqualStrings("Red", options[0].label);
    try std.testing.expectEqualStrings("wss://relay.one", relays[0]);
}

test "poll extract rejects duplicate option ids and malformed singleton tags" {
    const duplicate_options = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
        .{ .items = &.{ "option", "opt1", "Blue" } },
    };
    const duplicate_poll_type = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
        .{ .items = &.{ "polltype", "singlechoice" } },
        .{ .items = &.{ "polltype", "multiplechoice" } },
    };
    const bad_relay = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
        .{ .items = &.{ "relay", "https://relay.one" } },
    };
    var options: [2]PollOption = undefined;
    var relays: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.DuplicateOptionId,
        poll_extract(
            &test_event(poll_kind, 0x11, 0x22, 10, "Duplicate?", duplicate_options[0..]),
            options[0..],
            relays[0..],
        ),
    );
    try std.testing.expectError(
        error.DuplicatePollTypeTag,
        poll_extract(
            &test_event(poll_kind, 0x12, 0x22, 10, "Duplicate?", duplicate_poll_type[0..]),
            options[0..],
            relays[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidRelayTag,
        poll_extract(
            &test_event(poll_kind, 0x13, 0x22, 10, "Duplicate?", bad_relay[0..]),
            options[0..],
            relays[0..],
        ),
    );
}

test "poll response extract parses poll reference and ordered responses" {
    const poll_id_hex = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", poll_id_hex, "wss://relay.one" } },
        .{ .items = &.{ "response", "opt2" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const event = test_event(poll_response_kind, 0x21, 0x31, 20, "", tags[0..]);
    var responses: [2][]const u8 = undefined;

    const parsed = try poll_response_extract(&event, responses[0..]);

    try std.testing.expect(parsed.poll_id[0] == 0xaa);
    try std.testing.expectEqualStrings("wss://relay.one", parsed.relay_hint.?);
    try std.testing.expectEqual(@as(u16, 2), parsed.response_count);
    try std.testing.expectEqualStrings("opt2", responses[0]);
    try std.testing.expectEqualStrings("opt1", responses[1]);
}

test "poll response extract rejects malformed e and response tags" {
    const duplicate_event_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "e", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const bad_response = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "response", "not-valid!" } },
    };
    var responses: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.DuplicatePollEventTag,
        poll_response_extract(
            &test_event(poll_response_kind, 0x22, 0x32, 10, "", duplicate_event_tags[0..]),
            responses[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidResponseTag,
        poll_response_extract(
            &test_event(poll_response_kind, 0x23, 0x33, 10, "", bad_response[0..]),
            responses[0..],
        ),
    );
}

test "poll builders round-trip through extractors" {
    var option_tag: BuiltTag = .{};
    var relay_tag: BuiltTag = .{};
    var poll_type_tag: BuiltTag = .{};
    var ends_at_tag: BuiltTag = .{};
    var event_tag: BuiltTag = .{};
    var response_tag: BuiltTag = .{};

    const built_option = try poll_build_option_tag(
        &option_tag,
        .{ .id = "opt1", .label = "Red" },
    );
    const built_relay = try poll_build_relay_tag(&relay_tag, "wss://relay.one");
    const built_type = try poll_build_poll_type_tag(&poll_type_tag, .multiplechoice);
    const built_ends_at = try poll_build_ends_at_tag(&ends_at_tag, 1_719_889_000);
    const poll_tags = [_]nip01_event.EventTag{
        built_option,
        built_relay,
        built_type,
        built_ends_at,
    };
    const poll_event = test_event(poll_kind, 0x30, 0x40, 10, "Question", poll_tags[0..]);
    var options: [2]PollOption = undefined;
    var relays: [1][]const u8 = undefined;

    const poll = try poll_extract(&poll_event, options[0..], relays[0..]);
    const built_event = try poll_response_build_event_tag(&event_tag, .{
        .poll_id = poll_event.id,
        .relay_hint = "wss://relay.one",
    });
    const built_response = try poll_response_build_response_tag(&response_tag, "opt1");
    const response_tags = [_]nip01_event.EventTag{ built_event, built_response };
    var responses: [1][]const u8 = undefined;
    const response = try poll_response_extract(
        &test_event(poll_response_kind, 0x31, 0x41, 15, "", response_tags[0..]),
        responses[0..],
    );

    try std.testing.expectEqual(PollType.multiplechoice, poll.poll_type);
    try std.testing.expectEqualStrings("opt1", options[0].id);
    try std.testing.expectEqualStrings("wss://relay.one", relays[0]);
    try std.testing.expect(std.mem.eql(u8, &poll_event.id, &response.poll_id));
    try std.testing.expectEqualStrings("opt1", responses[0]);
}

test "poll builders map invalid inputs to typed invalid errors" {
    var option_tag: BuiltTag = .{};
    var response_tag: BuiltTag = .{};
    var relay_tag: BuiltTag = .{};
    var long_storage: [limits.tag_item_bytes_max + 1]u8 = [_]u8{'a'} **
        (limits.tag_item_bytes_max + 1);

    try std.testing.expectError(
        error.InvalidOptionTag,
        poll_build_option_tag(&option_tag, .{ .id = long_storage[0..], .label = "Red" }),
    );
    try std.testing.expectError(
        error.InvalidResponseTag,
        poll_response_build_response_tag(&response_tag, "not-valid!"),
    );
    try std.testing.expectError(
        error.InvalidRelayTag,
        poll_build_relay_tag(&relay_tag, "https://relay.one"),
    );
}

test "poll tally reduces latest response per pubkey for singlechoice polls" {
    const poll_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
        .{ .items = &.{ "option", "opt2", "Blue" } },
        .{ .items = &.{ "endsAt", "100" } },
    };
    const poll_event = test_event(poll_kind, 0x40, 0x50, 10, "Color?", poll_tags[0..]);
    const valid_first = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "4040404040404040404040404040404040404040404040404040404040404040" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const changed_vote = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "4040404040404040404040404040404040404040404040404040404040404040" } },
        .{ .items = &.{ "response", "opt2" } },
    };
    const invalid_latest = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "4040404040404040404040404040404040404040404040404040404040404040" } },
        .{ .items = &.{ "response", "unknown" } },
    };
    const late_vote = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "4040404040404040404040404040404040404040404040404040404040404040" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const responses = [_]nip01_event.Event{
        test_event(poll_response_kind, 0x41, 0x61, 20, "", valid_first[0..]),
        test_event(poll_response_kind, 0x42, 0x61, 30, "", changed_vote[0..]),
        test_event(poll_response_kind, 0x43, 0x62, 40, "", invalid_latest[0..]),
        test_event(poll_response_kind, 0x44, 0x63, 101, "", late_vote[0..]),
    };
    var latest: [4]CountedResponse = undefined;
    var tallies: [2]OptionTally = undefined;

    const tally = try poll_tally_reduce(&poll_event, responses[0..], latest[0..], tallies[0..]);

    try std.testing.expectEqual(PollType.singlechoice, tally.poll_type);
    try std.testing.expectEqual(@as(u16, 2), tally.candidate_pubkey_count);
    try std.testing.expectEqual(@as(u16, 1), tally.counted_pubkey_count);
    try std.testing.expectEqualStrings("opt1", tallies[0].id);
    try std.testing.expectEqual(@as(u32, 0), tallies[0].vote_count);
    try std.testing.expectEqual(@as(u32, 1), tallies[1].vote_count);
}

test "poll tally dedupes multiplechoice responses and ties by event id" {
    const poll_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
        .{ .items = &.{ "option", "opt2", "Blue" } },
        .{ .items = &.{ "option", "opt3", "Green" } },
        .{ .items = &.{ "polltype", "multiplechoice" } },
    };
    const poll_event = test_event(poll_kind, 0x50, 0x70, 10, "Colors?", poll_tags[0..]);
    const response_tags_a = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "5050505050505050505050505050505050505050505050505050505050505050" } },
        .{ .items = &.{ "response", "opt1" } },
        .{ .items = &.{ "response", "opt2" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const response_tags_b = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "5050505050505050505050505050505050505050505050505050505050505050" } },
        .{ .items = &.{ "response", "opt3" } },
    };
    const response_tags_c = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "5050505050505050505050505050505050505050505050505050505050505050" } },
        .{ .items = &.{ "response", "opt2" } },
    };
    const responses = [_]nip01_event.Event{
        test_event(poll_response_kind, 0x51, 0x81, 20, "", response_tags_a[0..]),
        test_event(poll_response_kind, 0x52, 0x82, 25, "", response_tags_b[0..]),
        test_event(poll_response_kind, 0x53, 0x82, 25, "", response_tags_c[0..]),
    };
    var latest: [3]CountedResponse = undefined;
    var tallies: [3]OptionTally = undefined;

    const tally = try poll_tally_reduce(&poll_event, responses[0..], latest[0..], tallies[0..]);

    try std.testing.expectEqual(@as(u16, 2), tally.candidate_pubkey_count);
    try std.testing.expectEqual(@as(u16, 2), tally.counted_pubkey_count);
    try std.testing.expectEqual(@as(u32, 1), tallies[0].vote_count);
    try std.testing.expectEqual(@as(u32, 2), tallies[1].vote_count);
    try std.testing.expectEqual(@as(u32, 0), tallies[2].vote_count);
}

test "poll tally ignores malformed foreign and unsupported response events" {
    const poll_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
    };
    const poll_event = test_event(poll_kind, 0x60, 0x71, 10, "Color?", poll_tags[0..]);
    const valid_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "6060606060606060606060606060606060606060606060606060606060606060" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const foreign_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "6161616161616161616161616161616161616161616161616161616161616161" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const malformed_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "6060606060606060606060606060606060606060606060606060606060606060" } },
        .{ .items = &.{ "response", "not-valid!" } },
    };
    const responses = [_]nip01_event.Event{
        test_event(poll_response_kind, 0x61, 0x91, 20, "", valid_tags[0..]),
        test_event(poll_response_kind, 0x62, 0x92, 20, "", foreign_tags[0..]),
        test_event(poll_response_kind, 0x63, 0x93, 20, "", malformed_tags[0..]),
        test_event(1, 0x64, 0x94, 20, "", &.{}),
    };
    var latest: [2]CountedResponse = undefined;
    var tallies: [1]OptionTally = undefined;

    const tally = try poll_tally_reduce(&poll_event, responses[0..], latest[0..], tallies[0..]);

    try std.testing.expectEqual(@as(u16, 2), tally.candidate_pubkey_count);
    try std.testing.expectEqual(@as(u16, 1), tally.counted_pubkey_count);
    try std.testing.expectEqual(@as(u32, 1), tallies[0].vote_count);
}

test "poll tally latest malformed same-poll response suppresses older valid vote" {
    const poll_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
    };
    const poll_event = test_event(poll_kind, 0x65, 0x71, 10, "Color?", poll_tags[0..]);
    const valid_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "6565656565656565656565656565656565656565656565656565656565656565" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const malformed_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "6565656565656565656565656565656565656565656565656565656565656565" } },
        .{ .items = &.{ "response", "not-valid!" } },
    };
    const responses = [_]nip01_event.Event{
        test_event(poll_response_kind, 0x66, 0x95, 20, "", valid_tags[0..]),
        test_event(poll_response_kind, 0x67, 0x95, 30, "", malformed_tags[0..]),
    };
    var latest: [2]CountedResponse = undefined;
    var tallies: [1]OptionTally = undefined;

    const tally = try poll_tally_reduce(&poll_event, responses[0..], latest[0..], tallies[0..]);

    try std.testing.expectEqual(@as(u16, 1), tally.candidate_pubkey_count);
    try std.testing.expectEqual(@as(u16, 0), tally.counted_pubkey_count);
    try std.testing.expectEqual(@as(u32, 0), tallies[0].vote_count);
}

test "poll tally and extract return BufferTooSmall only for real capacity failures" {
    const poll_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "option", "opt1", "Red" } },
        .{ .items = &.{ "option", "opt2", "Blue" } },
    };
    const poll_event = test_event(poll_kind, 0x70, 0xa1, 10, "Color?", poll_tags[0..]);
    const response_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "7070707070707070707070707070707070707070707070707070707070707070" } },
        .{ .items = &.{ "response", "opt1" } },
    };
    const responses = [_]nip01_event.Event{
        test_event(poll_response_kind, 0x71, 0xb1, 20, "", response_tags[0..]),
        test_event(poll_response_kind, 0x72, 0xb2, 30, "", response_tags[0..]),
    };
    var options: [1]PollOption = undefined;
    var relays: [0][]const u8 = .{};
    var latest: [1]CountedResponse = undefined;
    var tallies: [1]OptionTally = undefined;

    try std.testing.expectError(
        error.BufferTooSmall,
        poll_extract(&poll_event, options[0..], relays[0..]),
    );
    try std.testing.expectError(
        error.BufferTooSmall,
        poll_tally_reduce(&poll_event, responses[0..], latest[0..], tallies[0..]),
    );
}
