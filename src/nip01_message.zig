const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip01_filter = @import("nip01_filter.zig");

pub const MessageParseError = error{
    InputTooLong,
    InvalidMessage,
    InvalidCommand,
    InvalidArity,
    InvalidFieldType,
    InvalidFilter,
    InvalidEvent,
    InvalidPrefix,
};

pub const MessageEncodeError = error{ BufferTooSmall, ValueOutOfRange };

pub const ClientMessage = union(enum) {
    req: struct {
        subscription_id: []const u8,
        filters: [limits.message_filters_max]nip01_filter.Filter,
        filters_count: u8,
    },
    close: struct { subscription_id: []const u8 },
    auth: struct { event: nip01_event.Event },
    count: struct {
        subscription_id: []const u8,
        filters: [limits.message_filters_max]nip01_filter.Filter,
        filters_count: u8,
    },
};

pub const RelayMessage = union(enum) {
    event: struct { subscription_id: []const u8, event: nip01_event.Event },
    eose: struct { subscription_id: []const u8 },
    ok: struct {
        event_id: [32]u8,
        accepted: bool,
        status: []const u8,
    },
    closed: struct { subscription_id: []const u8, status: []const u8 },
    notice: struct { message: []const u8 },
    auth: struct { challenge: []const u8 },
    count: struct { subscription_id: []const u8, count: u64 },
};

/// Relay-side transcript tracks only post-REQ flow for one subscription:
/// `EVENT* -> EOSE? -> EVENT* -> CLOSED?`.
/// `idle` means no post-REQ relay message has been observed yet.
pub const TranscriptStage = enum {
    idle,
    req_sent,
    eose_received,
    closed,
};

pub const TranscriptState = struct {
    stage: TranscriptStage = .idle,
    subscription_id: [limits.subscription_id_bytes_max]u8 = [_]u8{0} **
        limits.subscription_id_bytes_max,
    subscription_id_len: u8 = 0,
};

pub fn client_message_parse_json(
    input: []const u8,
    scratch: std.mem.Allocator,
) MessageParseError!ClientMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.message_filters_max > 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = try parse_message_array(input, parse_arena.allocator());
    const command = try parse_command(root.array.items[0]);

    if (std.mem.eql(u8, command, "REQ")) {
        return parse_client_req(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "CLOSE")) {
        return parse_client_close(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "AUTH")) {
        return parse_client_auth(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "COUNT")) {
        return parse_client_count(root.array.items, scratch);
    }

    return error.InvalidCommand;
}

pub fn relay_message_parse_json(
    input: []const u8,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.message_filters_max > 0);

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = try parse_message_array(input, parse_arena.allocator());
    const command = try parse_command(root.array.items[0]);

    if (std.mem.eql(u8, command, "EVENT")) {
        return parse_relay_event(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "EOSE")) {
        return parse_relay_eose(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "OK")) {
        return parse_relay_ok(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "CLOSED")) {
        return parse_relay_closed(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "NOTICE")) {
        return parse_relay_notice(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "AUTH")) {
        return parse_relay_auth(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "COUNT")) {
        return parse_relay_count(root.array.items, scratch);
    }

    return error.InvalidCommand;
}

pub fn client_message_serialize_json(
    output: []u8,
    message: *const ClientMessage,
) MessageEncodeError![]const u8 {
    std.debug.assert(output.len <= limits.relay_message_bytes_max + 1);
    std.debug.assert(@intFromPtr(message) != 0);

    var index: u32 = 0;
    switch (message.*) {
        .req => |request| {
            try validate_subscription_id_for_encode(request.subscription_id);
            try validate_client_filter_count_for_encode(request.filters_count);
            try write_output_bytes(output, &index, "[\"REQ\",");
            try write_output_string(output, &index, request.subscription_id);
            try serialize_client_filters(
                output,
                &index,
                request.filters[0..request.filters_count],
            );
            try write_output_bytes(output, &index, "]");
        },
        .close => |close_message| {
            try validate_subscription_id_for_encode(close_message.subscription_id);
            try write_output_bytes(output, &index, "[\"CLOSE\",");
            try write_output_string(output, &index, close_message.subscription_id);
            try write_output_bytes(output, &index, "]");
        },
        .auth => |auth_message| {
            try write_output_bytes(output, &index, "[\"AUTH\",");
            try serialize_event(output, &index, &auth_message.event);
            try write_output_bytes(output, &index, "]");
        },
        .count => |count_message| {
            try validate_subscription_id_for_encode(count_message.subscription_id);
            try validate_client_filter_count_for_encode(count_message.filters_count);
            try write_output_bytes(output, &index, "[\"COUNT\",");
            try write_output_string(output, &index, count_message.subscription_id);
            try serialize_client_filters(
                output,
                &index,
                count_message.filters[0..count_message.filters_count],
            );
            try write_output_bytes(output, &index, "]");
        },
    }

    return output[0..index];
}

pub fn relay_message_serialize_json(
    output: []u8,
    message: *const RelayMessage,
) MessageEncodeError![]const u8 {
    std.debug.assert(output.len <= limits.relay_message_bytes_max + 1);
    std.debug.assert(@intFromPtr(message) != 0);

    var index: u32 = 0;
    switch (message.*) {
        .event => |event_message| {
            try validate_subscription_id_for_encode(event_message.subscription_id);
            try write_output_bytes(output, &index, "[\"EVENT\",");
            try write_output_string(output, &index, event_message.subscription_id);
            try write_output_bytes(output, &index, ",");
            try serialize_event(output, &index, &event_message.event);
            try write_output_bytes(output, &index, "]");
        },
        .eose => |eose_message| {
            try validate_subscription_id_for_encode(eose_message.subscription_id);
            try write_output_bytes(output, &index, "[\"EOSE\",");
            try write_output_string(output, &index, eose_message.subscription_id);
            try write_output_bytes(output, &index, "]");
        },
        .ok => |ok_message| {
            try validate_ok_status_for_encode(ok_message.accepted, ok_message.status);
            const event_id_hex = std.fmt.bytesToHex(ok_message.event_id, .lower);
            try write_output_bytes(output, &index, "[\"OK\",\"");
            try write_output_bytes(output, &index, event_id_hex[0..]);
            try write_output_bytes(output, &index, "\",");
            try write_output_bool(output, &index, ok_message.accepted);
            try write_output_bytes(output, &index, ",");
            try write_output_string(output, &index, ok_message.status);
            try write_output_bytes(output, &index, "]");
        },
        .closed => |closed_message| {
            try validate_subscription_id_for_encode(closed_message.subscription_id);
            try validate_prefixed_status_for_encode(closed_message.status);
            try write_output_bytes(output, &index, "[\"CLOSED\",");
            try write_output_string(output, &index, closed_message.subscription_id);
            try write_output_bytes(output, &index, ",");
            try write_output_string(output, &index, closed_message.status);
            try write_output_bytes(output, &index, "]");
        },
        .notice => |notice_message| {
            try write_output_bytes(output, &index, "[\"NOTICE\",");
            try write_output_string(output, &index, notice_message.message);
            try write_output_bytes(output, &index, "]");
        },
        .auth => |auth_message| {
            try write_output_bytes(output, &index, "[\"AUTH\",");
            try write_output_string(output, &index, auth_message.challenge);
            try write_output_bytes(output, &index, "]");
        },
        .count => |count_message| {
            try validate_subscription_id_for_encode(count_message.subscription_id);
            try write_output_bytes(output, &index, "[\"COUNT\",");
            try write_output_string(output, &index, count_message.subscription_id);
            try write_output_bytes(output, &index, ",{\"count\":");
            try write_output_u64(output, &index, count_message.count);
            try write_output_bytes(output, &index, "}]");
        },
    }

    return output[0..index];
}

/// Non-canonical compatibility-only transcript helper.
///
/// This helper infers tracked subscription context from each relay message and then applies
/// `transcript_apply_relay`. For canonical strict integration, call
/// `transcript_mark_client_req` once and then `transcript_apply_relay` directly.
pub fn transcript_apply_compat(
    state: *TranscriptState,
    message: *const RelayMessage,
) error{InvalidTranscriptTransition}!void {
    std.debug.assert(state.subscription_id_len <= limits.subscription_id_bytes_max);
    std.debug.assert(@intFromPtr(state) != 0);

    const tracked_subscription_id =
        transcript_tracked_subscription_id(message.*) orelse
        return error.InvalidTranscriptTransition;
    if (tracked_subscription_id.len == 0) {
        return error.InvalidTranscriptTransition;
    }
    if (tracked_subscription_id.len > limits.subscription_id_bytes_max) {
        return error.InvalidTranscriptTransition;
    }

    try transcript_apply_relay(state, message.*);
}

/// Compatibility alias for `transcript_apply_compat`.
///
/// Kept for backward compatibility. Canonical strict integration remains
/// `transcript_mark_client_req` + `transcript_apply_relay`.
pub fn transcript_apply(
    state: *TranscriptState,
    message: *const RelayMessage,
) error{InvalidTranscriptTransition}!void {
    std.debug.assert(state.subscription_id_len <= limits.subscription_id_bytes_max);
    std.debug.assert(@intFromPtr(state) != 0);

    return transcript_apply_compat(state, message);
}

/// Marks that a client `REQ` was sent for `subscription_id`.
/// Must be called before relay transcript transitions are applied.
pub fn transcript_mark_client_req(
    state: *TranscriptState,
    subscription_id: []const u8,
) error{InvalidTranscriptTransition}!void {
    std.debug.assert(state.subscription_id_len <= limits.subscription_id_bytes_max);
    std.debug.assert(@intFromPtr(state) != 0);

    if (state.stage != .idle) {
        return error.InvalidTranscriptTransition;
    }

    try transcript_set_subscription_id(state, subscription_id);
    state.stage = .req_sent;
}

fn transcript_tracked_subscription_id(message: RelayMessage) ?[]const u8 {
    std.debug.assert(limits.subscription_id_bytes_max > 0);
    std.debug.assert(@sizeOf(RelayMessage) > 0);

    switch (message) {
        .event => |event_message| return event_message.subscription_id,
        .eose => |eose_message| return eose_message.subscription_id,
        .closed => |closed_message| return closed_message.subscription_id,
        else => return null,
    }
}

fn validate_subscription_id_for_encode(subscription_id: []const u8) MessageEncodeError!void {
    std.debug.assert(subscription_id.len <= limits.subscription_id_bytes_max + 1);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (subscription_id.len == 0) {
        return error.ValueOutOfRange;
    }
    if (subscription_id.len > limits.subscription_id_bytes_max) {
        return error.ValueOutOfRange;
    }
}

fn validate_client_filter_count_for_encode(filters_count: u8) MessageEncodeError!void {
    std.debug.assert(limits.message_filters_max > 0);
    std.debug.assert(filters_count <= limits.message_filters_max + 1);

    if (filters_count == 0) {
        return error.ValueOutOfRange;
    }
    if (filters_count > limits.message_filters_max) {
        return error.ValueOutOfRange;
    }
}

fn serialize_client_filters(
    output: []u8,
    index: *u32,
    filters: []const nip01_filter.Filter,
) MessageEncodeError!void {
    std.debug.assert(filters.len <= limits.message_filters_max + 1);
    std.debug.assert(index.* <= output.len);

    if (filters.len == 0) {
        return error.ValueOutOfRange;
    }
    if (filters.len > limits.message_filters_max) {
        return error.ValueOutOfRange;
    }

    var filter_index: u32 = 0;
    while (filter_index < filters.len) : (filter_index += 1) {
        const current_index: usize = @intCast(filter_index);
        try write_output_bytes(output, index, ",");
        try serialize_filter(output, index, &filters[current_index]);
    }
}

fn validate_prefixed_status_for_encode(status: []const u8) MessageEncodeError!void {
    std.debug.assert(status.len <= limits.relay_message_bytes_max);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    const separator = std.mem.indexOf(u8, status, ": ") orelse return error.ValueOutOfRange;
    if (separator == 0) {
        return error.ValueOutOfRange;
    }
    if (separator + 2 >= status.len) {
        return error.ValueOutOfRange;
    }
}

fn validate_ok_status_for_encode(accepted: bool, status: []const u8) MessageEncodeError!void {
    std.debug.assert(status.len <= limits.relay_message_bytes_max);
    std.debug.assert(@sizeOf(bool) == 1);

    if (accepted) {
        return;
    }
    try validate_prefixed_status_for_encode(status);
}

fn write_output_bytes(output: []u8, index: *u32, bytes: []const u8) MessageEncodeError!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(bytes.len <= limits.relay_message_bytes_max);

    const start: u32 = index.*;
    const end = std.math.add(u32, start, @intCast(bytes.len)) catch {
        return error.BufferTooSmall;
    };
    if (end > output.len) {
        return error.BufferTooSmall;
    }

    @memcpy(output[start..end], bytes);
    index.* = end;
}

fn write_output_u64(output: []u8, index: *u32, value: u64) MessageEncodeError!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(value <= std.math.maxInt(u64));

    var number_buffer: [20]u8 = undefined;
    const number_text = std.fmt.bufPrint(&number_buffer, "{d}", .{value}) catch {
        return error.ValueOutOfRange;
    };
    try write_output_bytes(output, index, number_text);
}

fn write_output_bool(output: []u8, index: *u32, value: bool) MessageEncodeError!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(@sizeOf(bool) == 1);

    if (value) {
        try write_output_bytes(output, index, "true");
        return;
    }

    try write_output_bytes(output, index, "false");
}

fn write_output_string(output: []u8, index: *u32, value: []const u8) MessageEncodeError!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(value.len <= limits.relay_message_bytes_max);

    if (!std.unicode.utf8ValidateSlice(value)) {
        return error.ValueOutOfRange;
    }

    try write_output_bytes(output, index, "\"");
    var cursor: u32 = 0;
    while (cursor < value.len) : (cursor += 1) {
        const byte = value[cursor];
        if (byte == '\\') {
            try write_output_bytes(output, index, "\\\\");
        } else if (byte == '"') {
            try write_output_bytes(output, index, "\\\"");
        } else if (byte < 0x20) {
            var control_text: [6]u8 = .{ '\\', 'u', '0', '0', '0', '0' };
            control_text[4] = hex_lower_nibble(@intCast(byte >> 4));
            control_text[5] = hex_lower_nibble(@intCast(byte & 0x0f));
            try write_output_bytes(output, index, control_text[0..]);
        } else {
            try write_output_bytes(output, index, value[cursor .. cursor + 1]);
        }
    }
    try write_output_bytes(output, index, "\"");
}

fn hex_lower_nibble(value: u8) u8 {
    std.debug.assert(value <= 15);
    std.debug.assert(limits.id_hex_length == 64);

    if (value < 10) {
        return '0' + value;
    }

    return 'a' + (value - 10);
}

fn serialize_filter(
    output: []u8,
    index: *u32,
    filter: *const nip01_filter.Filter,
) MessageEncodeError!void {
    std.debug.assert(filter.ids_count <= limits.filter_ids_max);
    std.debug.assert(filter.authors_count <= limits.filter_authors_max);

    var has_field = false;
    try write_output_bytes(output, index, "{");
    try serialize_filter_ids(output, index, filter, &has_field);
    try serialize_filter_authors(output, index, filter, &has_field);
    try serialize_filter_kinds(output, index, filter, &has_field);
    try serialize_filter_optional_u64(output, index, "since", filter.since, &has_field);
    try serialize_filter_optional_u64(output, index, "until", filter.until, &has_field);
    try serialize_filter_optional_u16(output, index, "limit", filter.limit, &has_field);
    try serialize_filter_tag_conditions(output, index, filter, &has_field);
    try write_output_bytes(output, index, "}");
}

fn serialize_filter_ids(
    output: []u8,
    index: *u32,
    filter: *const nip01_filter.Filter,
    has_field: *bool,
) MessageEncodeError!void {
    std.debug.assert(filter.ids_count <= limits.filter_ids_max);
    std.debug.assert(filter.ids_prefix_nibbles[0] <= limits.id_hex_length);
    std.debug.assert(@intFromPtr(has_field) != 0);

    if (filter.ids_count == 0) {
        return;
    }

    try write_object_key(output, index, "ids", has_field);
    try write_output_bytes(output, index, "[");
    var item_index: u16 = 0;
    while (item_index < filter.ids_count) : (item_index += 1) {
        if (item_index != 0) {
            try write_output_bytes(output, index, ",");
        }
        const prefix_nibbles = filter.ids_prefix_nibbles[item_index];
        if (prefix_nibbles == 0) {
            return error.ValueOutOfRange;
        }
        if (prefix_nibbles > limits.id_hex_length) {
            return error.ValueOutOfRange;
        }
        try write_output_bytes(output, index, "\"");
        try write_hex_prefix_32_lower(output, index, &filter.ids[item_index], prefix_nibbles);
        try write_output_bytes(output, index, "\"");
    }
    try write_output_bytes(output, index, "]");
}

fn serialize_filter_authors(
    output: []u8,
    index: *u32,
    filter: *const nip01_filter.Filter,
    has_field: *bool,
) MessageEncodeError!void {
    std.debug.assert(filter.authors_count <= limits.filter_authors_max);
    std.debug.assert(filter.authors_prefix_nibbles[0] <= limits.pubkey_hex_length);
    std.debug.assert(@intFromPtr(has_field) != 0);

    if (filter.authors_count == 0) {
        return;
    }

    try write_object_key(output, index, "authors", has_field);
    try write_output_bytes(output, index, "[");
    var item_index: u16 = 0;
    while (item_index < filter.authors_count) : (item_index += 1) {
        if (item_index != 0) {
            try write_output_bytes(output, index, ",");
        }
        const prefix_nibbles = filter.authors_prefix_nibbles[item_index];
        if (prefix_nibbles == 0) {
            return error.ValueOutOfRange;
        }
        if (prefix_nibbles > limits.pubkey_hex_length) {
            return error.ValueOutOfRange;
        }
        try write_output_bytes(output, index, "\"");
        try write_hex_prefix_32_lower(output, index, &filter.authors[item_index], prefix_nibbles);
        try write_output_bytes(output, index, "\"");
    }
    try write_output_bytes(output, index, "]");
}

fn write_hex_prefix_32_lower(
    output: []u8,
    index: *u32,
    value: *const [32]u8,
    prefix_nibbles: u8,
) MessageEncodeError!void {
    std.debug.assert(prefix_nibbles <= limits.id_hex_length);
    std.debug.assert(@intFromPtr(value) != 0);

    if (prefix_nibbles == 0) {
        return error.ValueOutOfRange;
    }
    if (prefix_nibbles > limits.id_hex_length) {
        return error.ValueOutOfRange;
    }

    var text_buffer: [64]u8 = undefined;
    var text_index: u8 = 0;
    const full_bytes: u8 = prefix_nibbles / 2;

    var byte_index: u8 = 0;
    while (byte_index < full_bytes) : (byte_index += 1) {
        const byte = value[byte_index];
        text_buffer[text_index] = hex_lower_nibble(@intCast(byte >> 4));
        text_index += 1;
        text_buffer[text_index] = hex_lower_nibble(@intCast(byte & 0x0f));
        text_index += 1;
    }

    if ((prefix_nibbles % 2) == 1) {
        const byte = value[full_bytes];
        text_buffer[text_index] = hex_lower_nibble(@intCast(byte >> 4));
        text_index += 1;
    }

    try write_output_bytes(output, index, text_buffer[0..text_index]);
}

fn serialize_filter_kinds(
    output: []u8,
    index: *u32,
    filter: *const nip01_filter.Filter,
    has_field: *bool,
) MessageEncodeError!void {
    std.debug.assert(filter.kinds_count <= limits.filter_kinds_max);
    std.debug.assert(@intFromPtr(has_field) != 0);

    if (filter.kinds_count == 0) {
        return;
    }

    try write_object_key(output, index, "kinds", has_field);
    try write_output_bytes(output, index, "[");
    var item_index: u16 = 0;
    while (item_index < filter.kinds_count) : (item_index += 1) {
        if (item_index != 0) {
            try write_output_bytes(output, index, ",");
        }
        try write_output_u64(output, index, filter.kinds[item_index]);
    }
    try write_output_bytes(output, index, "]");
}

fn serialize_filter_optional_u64(
    output: []u8,
    index: *u32,
    key: []const u8,
    value: ?u64,
    has_field: *bool,
) MessageEncodeError!void {
    std.debug.assert(key.len > 0);
    std.debug.assert(@intFromPtr(has_field) != 0);

    if (value == null) {
        return;
    }

    try write_object_key(output, index, key, has_field);
    try write_output_u64(output, index, value.?);
}

fn serialize_filter_optional_u16(
    output: []u8,
    index: *u32,
    key: []const u8,
    value: ?u16,
    has_field: *bool,
) MessageEncodeError!void {
    std.debug.assert(key.len > 0);
    std.debug.assert(@intFromPtr(has_field) != 0);

    if (value == null) {
        return;
    }

    try write_object_key(output, index, key, has_field);
    try write_output_u64(output, index, value.?);
}

fn serialize_filter_tag_conditions(
    output: []u8,
    index: *u32,
    filter: *const nip01_filter.Filter,
    has_field: *bool,
) MessageEncodeError!void {
    std.debug.assert(filter.tag_conditions.len <= 256);
    std.debug.assert(@intFromPtr(has_field) != 0);

    var condition_index: u32 = 0;
    while (condition_index < filter.tag_conditions.len) : (condition_index += 1) {
        const condition = filter.tag_conditions[condition_index];
        var key: [2]u8 = .{ '#', condition.key };
        try write_object_key(output, index, key[0..], has_field);
        try write_output_bytes(output, index, "[");
        var value_index: u32 = 0;
        while (value_index < condition.values.len) : (value_index += 1) {
            if (value_index != 0) {
                try write_output_bytes(output, index, ",");
            }
            try write_output_string(output, index, condition.values[value_index]);
        }
        try write_output_bytes(output, index, "]");
    }
}

fn write_object_key(
    output: []u8,
    index: *u32,
    key: []const u8,
    has_field: *bool,
) MessageEncodeError!void {
    std.debug.assert(key.len > 0);
    std.debug.assert(@intFromPtr(has_field) != 0);

    if (has_field.*) {
        try write_output_bytes(output, index, ",");
    }
    has_field.* = true;
    try write_output_string(output, index, key);
    try write_output_bytes(output, index, ":");
}

fn serialize_event(
    output: []u8,
    index: *u32,
    event: *const nip01_event.Event,
) MessageEncodeError!void {
    std.debug.assert(event.tags.len <= limits.tags_max + 1);
    std.debug.assert(event.content.len <= limits.content_bytes_max + 1);

    if (event.tags.len > limits.tags_max) {
        return error.ValueOutOfRange;
    }
    if (event.content.len > limits.content_bytes_max) {
        return error.ValueOutOfRange;
    }

    const id_hex = std.fmt.bytesToHex(event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    const sig_hex = std.fmt.bytesToHex(event.sig, .lower);

    try write_output_bytes(output, index, "{\"id\":\"");
    try write_output_bytes(output, index, id_hex[0..]);
    try write_output_bytes(output, index, "\",\"pubkey\":\"");
    try write_output_bytes(output, index, pubkey_hex[0..]);
    try write_output_bytes(output, index, "\",\"created_at\":");
    try write_output_u64(output, index, event.created_at);
    try write_output_bytes(output, index, ",\"kind\":");
    try write_output_u64(output, index, event.kind);
    try write_output_bytes(output, index, ",\"tags\":");
    try serialize_event_tags(output, index, event.tags);
    try write_output_bytes(output, index, ",\"content\":");
    try write_output_string(output, index, event.content);
    try write_output_bytes(output, index, ",\"sig\":\"");
    try write_output_bytes(output, index, sig_hex[0..]);
    try write_output_bytes(output, index, "\"}");
}

fn serialize_event_tags(
    output: []u8,
    index: *u32,
    tags: []const nip01_event.EventTag,
) MessageEncodeError!void {
    std.debug.assert(tags.len <= limits.tags_max + 1);
    std.debug.assert(limits.tag_items_max > 0);

    if (tags.len > limits.tags_max) {
        return error.ValueOutOfRange;
    }

    try write_output_bytes(output, index, "[");
    var tag_index: u32 = 0;
    while (tag_index < tags.len) : (tag_index += 1) {
        if (tag_index != 0) {
            try write_output_bytes(output, index, ",");
        }
        try serialize_event_tag_items(output, index, tags[tag_index].items);
    }
    try write_output_bytes(output, index, "]");
}

fn serialize_event_tag_items(
    output: []u8,
    index: *u32,
    items: []const []const u8,
) MessageEncodeError!void {
    std.debug.assert(items.len <= limits.tag_items_max + 1);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (items.len > limits.tag_items_max) {
        return error.ValueOutOfRange;
    }

    try write_output_bytes(output, index, "[");
    var item_index: u32 = 0;
    while (item_index < items.len) : (item_index += 1) {
        if (item_index != 0) {
            try write_output_bytes(output, index, ",");
        }

        const item = items[item_index];
        if (item.len > limits.tag_item_bytes_max) {
            return error.ValueOutOfRange;
        }
        try write_output_string(output, index, item);
    }
    try write_output_bytes(output, index, "]");
}

fn parse_message_array(
    input: []const u8,
    parse_allocator: std.mem.Allocator,
) MessageParseError!std.json.Value {
    std.debug.assert(@intFromPtr(parse_allocator.ptr) != 0);
    std.debug.assert(limits.relay_message_bytes_max >= limits.event_json_max);

    if (input.len > limits.relay_message_bytes_max) {
        return error.InputTooLong;
    }
    if (input.len == 0) {
        return error.InvalidMessage;
    }

    const root = std.json.parseFromSliceLeaky(std.json.Value, parse_allocator, input, .{}) catch {
        return error.InvalidMessage;
    };
    if (root != .array) {
        return error.InvalidMessage;
    }
    if (root.array.items.len == 0) {
        return error.InvalidArity;
    }

    return root;
}

fn parse_command(value: std.json.Value) MessageParseError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (value != .string) {
        return error.InvalidFieldType;
    }
    if (value.string.len == 0) {
        return error.InvalidCommand;
    }
    return value.string;
}

fn parse_client_req(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!ClientMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.message_filters_max > 0);

    if (values.len < 3) {
        return error.InvalidArity;
    }

    var filters: [limits.message_filters_max]nip01_filter.Filter = undefined;
    const subscription_id = try parse_subscription_id(values[1], scratch);
    const filters_count = try parse_client_filters(values, scratch, &filters);
    return .{ .req = .{
        .subscription_id = subscription_id,
        .filters = filters,
        .filters_count = filters_count,
    } };
}

fn parse_client_close(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!ClientMessage {
    std.debug.assert(limits.subscription_id_bytes_max == 64);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1], scratch);
    return .{ .close = .{ .subscription_id = subscription_id } };
}

fn parse_client_auth(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!ClientMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.event_json_max > 0);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const event = try parse_event(values[1], scratch);
    return .{ .auth = .{ .event = event } };
}

fn parse_client_count(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!ClientMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.message_filters_max > 0);

    if (values.len < 3) {
        return error.InvalidArity;
    }

    var filters: [limits.message_filters_max]nip01_filter.Filter = undefined;
    const subscription_id = try parse_subscription_id(values[1], scratch);
    const filters_count = try parse_client_filters(values, scratch, &filters);
    return .{ .count = .{
        .subscription_id = subscription_id,
        .filters = filters,
        .filters_count = filters_count,
    } };
}

fn parse_client_filters(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
    filters: *[limits.message_filters_max]nip01_filter.Filter,
) MessageParseError!u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@intFromPtr(filters) != 0);

    const values_count: u32 = @intCast(values.len);
    if (values_count < 3) {
        return error.InvalidArity;
    }
    const filters_count: u32 = values_count - 2;
    if (filters_count > limits.message_filters_max) {
        return error.InvalidArity;
    }

    var filter_index: u32 = 0;
    while (filter_index < filters_count) : (filter_index += 1) {
        const value_index: usize = @intCast(filter_index + 2);
        const current_index: usize = @intCast(filter_index);
        filters[current_index] = try parse_filter(values[value_index], scratch);
    }

    return @intCast(filters_count);
}

fn parse_relay_event(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (values.len != 3) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1], scratch);
    const event = try parse_event(values[2], scratch);
    return .{ .event = .{ .subscription_id = subscription_id, .event = event } };
}

fn parse_relay_eose(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(limits.subscription_id_bytes_max == 64);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1], scratch);
    return .{ .eose = .{ .subscription_id = subscription_id } };
}

fn parse_relay_ok(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 4) {
        return error.InvalidArity;
    }
    const event_id = try parse_hex_32(values[1]);
    const accepted = try parse_bool(values[2]);
    const status = try parse_ok_status(values[3], accepted, scratch);
    return .{ .ok = .{ .event_id = event_id, .accepted = accepted, .status = status } };
}

fn parse_ok_status(
    value: std.json.Value,
    accepted: bool,
    scratch: std.mem.Allocator,
) MessageParseError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(bool) == 1);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (accepted) {
        return parse_string_owned(value, scratch);
    }
    return parse_prefixed_status(value, scratch);
}

fn parse_relay_closed(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(limits.subscription_id_bytes_max == 64);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 3) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1], scratch);
    const status = try parse_prefixed_status(values[2], scratch);
    return .{ .closed = .{ .subscription_id = subscription_id, .status = status } };
}

fn parse_relay_notice(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(limits.subscription_id_bytes_max > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const message = try parse_string_owned(values[1], scratch);
    return .{ .notice = .{ .message = message } };
}

fn parse_relay_auth(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(limits.subscription_id_bytes_max > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const challenge = try parse_string_owned(values[1], scratch);
    return .{ .auth = .{ .challenge = challenge } };
}

fn parse_relay_count(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(limits.subscription_id_bytes_max == 64);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 3) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1], scratch);
    const count = try parse_count_object(values[2]);
    return .{ .count = .{ .subscription_id = subscription_id, .count = count } };
}

fn parse_subscription_id(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError![]const u8 {
    std.debug.assert(limits.subscription_id_bytes_max == 64);
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const text = try parse_string_owned(value, scratch);
    if (text.len == 0) {
        return error.InvalidFieldType;
    }
    if (text.len > limits.subscription_id_bytes_max) {
        return error.InvalidFieldType;
    }
    return text;
}

fn parse_string(value: std.json.Value) MessageParseError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (value != .string) {
        return error.InvalidFieldType;
    }
    return value.string;
}

fn parse_string_owned(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const source = try parse_string(value);
    return scratch.dupe(u8, source) catch return error.InvalidMessage;
}

fn parse_bool(value: std.json.Value) MessageParseError!bool {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(bool) == 1);

    if (value != .bool) {
        return error.InvalidFieldType;
    }
    return value.bool;
}

fn parse_hex_32(value: std.json.Value) MessageParseError![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(@sizeOf([32]u8) == 32);

    const source = try parse_string(value);
    if (source.len != limits.id_hex_length) {
        return error.InvalidFieldType;
    }

    var source_index: u32 = 0;
    while (source_index < source.len) : (source_index += 1) {
        const source_byte = source[source_index];
        if (!is_lower_hex_byte(source_byte)) {
            return error.InvalidFieldType;
        }
    }

    var output: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&output, source) catch return error.InvalidFieldType;
    return output;
}

fn is_lower_hex_byte(value: u8) bool {
    std.debug.assert(value <= 0x7f);
    std.debug.assert(limits.id_hex_length == 64);

    if (value >= '0') {
        if (value <= '9') {
            return true;
        }
    }

    if (value >= 'a') {
        if (value <= 'f') {
            return true;
        }
    }

    return false;
}

fn parse_prefixed_status(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const status = try parse_string_owned(value, scratch);
    const separator = std.mem.indexOf(u8, status, ": ") orelse return error.InvalidPrefix;
    if (separator == 0) {
        return error.InvalidPrefix;
    }
    if (separator + 2 >= status.len) {
        return error.InvalidPrefix;
    }
    return status;
}

fn parse_filter(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!nip01_filter.Filter {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .object) {
        return error.InvalidFieldType;
    }
    return nip01_filter.filter_parse_value(value, scratch) catch return error.InvalidFilter;
}

fn parse_event(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!nip01_event.Event {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .object) {
        return error.InvalidFieldType;
    }
    return nip01_event.event_parse_value(value, scratch) catch return error.InvalidEvent;
}

fn parse_count_object(value: std.json.Value) MessageParseError!u64 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@sizeOf(u64) == 8);

    if (value != .object) {
        return error.InvalidFieldType;
    }
    const count_value = value.object.get("count") orelse return error.InvalidFieldType;
    if (count_value != .integer) {
        return error.InvalidFieldType;
    }
    if (count_value.integer < 0) {
        return error.InvalidFieldType;
    }

    return std.math.cast(u64, count_value.integer) orelse error.InvalidFieldType;
}

/// Applies relay-only transcript transitions after client REQ mark:
/// `EVENT* -> EOSE? -> EVENT* -> CLOSED?`.
pub fn transcript_apply_relay(
    state: *TranscriptState,
    message: RelayMessage,
) error{InvalidTranscriptTransition}!void {
    std.debug.assert(state.subscription_id_len <= limits.subscription_id_bytes_max);
    std.debug.assert(@intFromPtr(state) != 0);

    switch (message) {
        .event => |event_message| {
            if (state.stage == .req_sent) {
                if (!transcript_subscription_matches(state, event_message.subscription_id)) {
                    return error.InvalidTranscriptTransition;
                }
                return;
            }
            if (state.stage == .eose_received) {
                if (!transcript_subscription_matches(state, event_message.subscription_id)) {
                    return error.InvalidTranscriptTransition;
                }
                return;
            }

            return error.InvalidTranscriptTransition;
        },
        .eose => |eose_message| {
            if (state.stage != .req_sent) {
                return error.InvalidTranscriptTransition;
            }
            if (!transcript_subscription_matches(state, eose_message.subscription_id)) {
                return error.InvalidTranscriptTransition;
            }
            state.stage = .eose_received;
        },
        .closed => |closed_message| {
            if (state.stage == .req_sent) {
                if (!transcript_subscription_matches(state, closed_message.subscription_id)) {
                    return error.InvalidTranscriptTransition;
                }
                state.stage = .closed;
                return;
            }
            if (state.stage == .eose_received) {
                if (!transcript_subscription_matches(state, closed_message.subscription_id)) {
                    return error.InvalidTranscriptTransition;
                }
                state.stage = .closed;
                return;
            }

            return error.InvalidTranscriptTransition;
        },
        else => return error.InvalidTranscriptTransition,
    }
}

fn transcript_set_subscription_id(
    state: *TranscriptState,
    subscription_id: []const u8,
) error{InvalidTranscriptTransition}!void {
    std.debug.assert(state.subscription_id_len <= limits.subscription_id_bytes_max);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (subscription_id.len == 0) {
        return error.InvalidTranscriptTransition;
    }
    if (subscription_id.len > limits.subscription_id_bytes_max) {
        return error.InvalidTranscriptTransition;
    }
    state.subscription_id_len = @intCast(subscription_id.len);
    @memset(state.subscription_id[0..], 0);
    @memcpy(state.subscription_id[0..subscription_id.len], subscription_id);
}

fn transcript_subscription_matches(
    state: *const TranscriptState,
    subscription_id: []const u8,
) bool {
    std.debug.assert(state.subscription_id_len <= limits.subscription_id_bytes_max);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (subscription_id.len > limits.subscription_id_bytes_max) {
        return false;
    }
    if (subscription_id.len != state.subscription_id_len) {
        return false;
    }
    return std.mem.eql(u8, state.subscription_id[0..state.subscription_id_len], subscription_id);
}

test "client parser accepts strict valid vectors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const req = try client_message_parse_json(
        "[\"REQ\",\"sub-1\",{\"kinds\":[1]}]",
        arena.allocator(),
    );
    const close = try client_message_parse_json("[\"CLOSE\",\"sub-1\"]", arena.allocator());
    const auth = try client_message_parse_json(
        "[\"AUTH\"," ++ sample_event_json_text ++ "]",
        arena.allocator(),
    );
    const count = try client_message_parse_json(
        "[\"COUNT\",\"sub-1\",{\"kinds\":[1]}]",
        arena.allocator(),
    );

    try std.testing.expect(req == .req);
    try std.testing.expect(close == .close);
    try std.testing.expect(auth == .auth);
    try std.testing.expect(count == .count);
}

test "relay parser accepts strict valid vectors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const event = try relay_message_parse_json(
        "[\"EVENT\",\"sub-1\"," ++ sample_event_json_text ++ "]",
        arena.allocator(),
    );
    const eose = try relay_message_parse_json("[\"EOSE\",\"sub-1\"]", arena.allocator());
    const ok = try relay_message_parse_json(
        "[\"OK\",\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
            "true,\"pow: difficulty too low\"]",
        arena.allocator(),
    );
    const closed = try relay_message_parse_json(
        "[\"CLOSED\",\"sub-1\",\"error: denied\"]",
        arena.allocator(),
    );
    const count = try relay_message_parse_json(
        "[\"COUNT\",\"sub-1\",{\"count\":42}]",
        arena.allocator(),
    );

    try std.testing.expect(event == .event);
    try std.testing.expect(eose == .eose);
    try std.testing.expect(ok == .ok);
    try std.testing.expect(closed == .closed);
    try std.testing.expect(count == .count);
}

test "client parser accepts multi-filter req and count" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const req = try client_message_parse_json(
        "[\"REQ\",\"sub-1\",{\"kinds\":[1]},{\"kinds\":[2]}]",
        arena.allocator(),
    );
    try std.testing.expect(req == .req);
    try std.testing.expect(req.req.filters_count == 2);
    try std.testing.expect(req.req.filters[0].kinds_count == 1);
    try std.testing.expect(req.req.filters[1].kinds_count == 1);
    try std.testing.expect(req.req.filters[0].kinds[0] == 1);
    try std.testing.expect(req.req.filters[1].kinds[0] == 2);

    const count = try client_message_parse_json(
        "[\"COUNT\",\"sub-1\",{\"kinds\":[3]},{\"kinds\":[4]}]",
        arena.allocator(),
    );
    try std.testing.expect(count == .count);
    try std.testing.expect(count.count.filters_count == 2);
    try std.testing.expect(count.count.filters[0].kinds_count == 1);
    try std.testing.expect(count.count.filters[1].kinds_count == 1);
    try std.testing.expect(count.count.filters[0].kinds[0] == 3);
    try std.testing.expect(count.count.filters[1].kinds[0] == 4);
}

test "client parser rejects req or count with missing filters" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidArity,
        client_message_parse_json("[\"REQ\",\"sub-1\"]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidArity,
        client_message_parse_json("[\"COUNT\",\"sub-1\"]", arena.allocator()),
    );
}

test "client parser rejects over-capacity filter lists" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const req_over_limit = "[\"REQ\",\"sub-1\",{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}" ++
        ",{}]";
    const count_over_limit =
        "[\"COUNT\",\"sub-1\",{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}" ++
        ",{}]";

    try std.testing.expectError(
        error.InvalidArity,
        client_message_parse_json(req_over_limit, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidArity,
        client_message_parse_json(count_over_limit, arena.allocator()),
    );
}

test "parser forces every MessageParseError variant" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const too_long_len: u32 = limits.relay_message_bytes_max + 1;
    const too_long = try std.testing.allocator.alloc(u8, too_long_len);
    defer std.testing.allocator.free(too_long);
    @memset(too_long, 'x');

    try std.testing.expectError(
        error.InputTooLong,
        client_message_parse_json(too_long, arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidMessage,
        client_message_parse_json("{}", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidCommand,
        client_message_parse_json("[\"BOOM\",\"x\"]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidArity,
        relay_message_parse_json("[\"EOSE\",\"a\",\"b\"]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidFieldType,
        client_message_parse_json("[\"CLOSE\",1]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidFilter,
        client_message_parse_json("[\"REQ\",\"sub-1\",{\"#e\":[]}]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidEvent,
        relay_message_parse_json("[\"EVENT\",\"sub-1\",{}]", arena.allocator()),
    );
    try std.testing.expectError(
        error.InvalidPrefix,
        relay_message_parse_json("[\"CLOSED\",\"sub-1\",\"missing\"]", arena.allocator()),
    );
}

test "relay parser rejects uppercase event id in OK message" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidFieldType,
        relay_message_parse_json(
            "[\"OK\",\"0123456789ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
                "true,\"pow: difficulty too low\"]",
            arena.allocator(),
        ),
    );
}

test "relay parser accepts OK success with empty status" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const ok = try relay_message_parse_json(
        "[\"OK\",\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
            "true,\"\"]",
        arena.allocator(),
    );

    try std.testing.expect(ok == .ok);
    try std.testing.expect(ok.ok.accepted);
    try std.testing.expect(ok.ok.status.len == 0);
}

test "relay parser rejects OK rejection with unprefixed status" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(
        error.InvalidPrefix,
        relay_message_parse_json(
            "[\"OK\",\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
                "false,\"denied\"]",
            arena.allocator(),
        ),
    );
}

test "client parser keeps owned strings after input mutation" {
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();

    const input_owned = try std.testing.allocator.dupe(u8, "[\"CLOSE\",\"sub-1\"]");
    defer std.testing.allocator.free(input_owned);

    const parsed = try client_message_parse_json(input_owned, scratch_arena.allocator());
    try std.testing.expect(parsed == .close);
    @memset(input_owned, 'x');

    try std.testing.expectEqualStrings("sub-1", parsed.close.subscription_id);
}

test "relay parser keeps owned strings after input mutation" {
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();

    const closed_input = try std.testing.allocator.dupe(
        u8,
        "[\"CLOSED\",\"sub-1\",\"error: denied\"]",
    );
    defer std.testing.allocator.free(closed_input);
    const closed = try relay_message_parse_json(closed_input, scratch_arena.allocator());
    try std.testing.expect(closed == .closed);
    @memset(closed_input, 'x');
    try std.testing.expectEqualStrings("sub-1", closed.closed.subscription_id);
    try std.testing.expectEqualStrings("error: denied", closed.closed.status);

    const notice_input = try std.testing.allocator.dupe(u8, "[\"NOTICE\",\"heads up\"]");
    defer std.testing.allocator.free(notice_input);
    const notice = try relay_message_parse_json(notice_input, scratch_arena.allocator());
    try std.testing.expect(notice == .notice);
    @memset(notice_input, 'x');
    try std.testing.expectEqualStrings("heads up", notice.notice.message);
}

test "client serialization is deterministic" {
    var buffer: [1024]u8 = undefined;
    var first_filter = nip01_filter.Filter{};
    first_filter.kinds[0] = 1;
    first_filter.kinds_count = 1;
    var second_filter = nip01_filter.Filter{};
    second_filter.kinds[0] = 2;
    second_filter.kinds_count = 1;

    var req_filters: [limits.message_filters_max]nip01_filter.Filter = undefined;
    req_filters[0] = first_filter;
    req_filters[1] = second_filter;
    const req = ClientMessage{ .req = .{
        .subscription_id = "sub-1",
        .filters = req_filters,
        .filters_count = 2,
    } };
    const req_json = try client_message_serialize_json(buffer[0..], &req);
    try std.testing.expectEqualStrings(
        "[\"REQ\",\"sub-1\",{\"kinds\":[1]},{\"kinds\":[2]}]",
        req_json,
    );

    var count_filters: [limits.message_filters_max]nip01_filter.Filter = undefined;
    count_filters[0] = first_filter;
    count_filters[1] = second_filter;
    const count = ClientMessage{ .count = .{
        .subscription_id = "sub-1",
        .filters = count_filters,
        .filters_count = 2,
    } };
    const count_json = try client_message_serialize_json(buffer[0..], &count);
    try std.testing.expectEqualStrings(
        "[\"COUNT\",\"sub-1\",{\"kinds\":[1]},{\"kinds\":[2]}]",
        count_json,
    );

    const close = ClientMessage{ .close = .{ .subscription_id = "sub-1" } };
    const close_json = try client_message_serialize_json(buffer[0..], &close);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"sub-1\"]", close_json);
}

test "filter prefix roundtrip preserves short even-length ids/authors" {
    var parse_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer parse_arena.deinit();

    const parsed = try client_message_parse_json(
        "[\"REQ\",\"sub-1\",{\"ids\":[\"aa\"],\"authors\":[\"bbbb\"]}]",
        parse_arena.allocator(),
    );
    try std.testing.expect(parsed == .req);
    try std.testing.expect(parsed.req.filters_count == 1);

    var buffer: [512]u8 = undefined;
    const serialized = try client_message_serialize_json(buffer[0..], &parsed);
    try std.testing.expectEqualStrings(
        "[\"REQ\",\"sub-1\",{\"ids\":[\"aa\"],\"authors\":[\"bbbb\"]}]",
        serialized,
    );

    var reparsed_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer reparsed_arena.deinit();

    const reparsed = try client_message_parse_json(serialized, reparsed_arena.allocator());
    try std.testing.expect(reparsed == .req);
    try std.testing.expect(reparsed.req.filters_count == 1);
    try std.testing.expect(reparsed.req.filters[0].ids_prefix_nibbles[0] == 2);
    try std.testing.expect(reparsed.req.filters[0].authors_prefix_nibbles[0] == 4);
}

test "filter prefix roundtrip preserves odd-length ids/authors" {
    var parse_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer parse_arena.deinit();

    const parsed = try client_message_parse_json(
        "[\"COUNT\",\"sub-1\",{\"ids\":[\"abc\"],\"authors\":[\"d\"]}]",
        parse_arena.allocator(),
    );
    try std.testing.expect(parsed == .count);
    try std.testing.expect(parsed.count.filters_count == 1);

    var buffer: [512]u8 = undefined;
    const serialized = try client_message_serialize_json(buffer[0..], &parsed);
    try std.testing.expectEqualStrings(
        "[\"COUNT\",\"sub-1\",{\"ids\":[\"abc\"],\"authors\":[\"d\"]}]",
        serialized,
    );

    var reparsed_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer reparsed_arena.deinit();

    const reparsed = try client_message_parse_json(serialized, reparsed_arena.allocator());
    try std.testing.expect(reparsed == .count);
    try std.testing.expect(reparsed.count.filters_count == 1);
    try std.testing.expect(reparsed.count.filters[0].ids_prefix_nibbles[0] == 3);
    try std.testing.expect(reparsed.count.filters[0].authors_prefix_nibbles[0] == 1);
}

test "relay serialization is deterministic" {
    var buffer: [4096]u8 = undefined;
    var event_id = [_]u8{0xaa} ** 32;
    event_id[0] = 0x10;

    const ok = RelayMessage{ .ok = .{
        .event_id = event_id,
        .accepted = true,
        .status = "pow: low",
    } };
    const ok_json = try relay_message_serialize_json(buffer[0..], &ok);
    try std.testing.expectEqualStrings(
        "[\"OK\",\"10aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",true," ++
            "\"pow: low\"]",
        ok_json,
    );

    const count = RelayMessage{ .count = .{ .subscription_id = "sub-1", .count = 42 } };
    const count_json = try relay_message_serialize_json(buffer[0..], &count);
    try std.testing.expectEqualStrings("[\"COUNT\",\"sub-1\",{\"count\":42}]", count_json);
}

test "relay serializer accepts OK success with empty status" {
    var buffer: [4096]u8 = undefined;
    const event_id = [_]u8{0} ** 32;
    const ok = RelayMessage{ .ok = .{
        .event_id = event_id,
        .accepted = true,
        .status = "",
    } };

    const ok_json = try relay_message_serialize_json(buffer[0..], &ok);
    try std.testing.expectEqualStrings(
        "[\"OK\",\"0000000000000000000000000000000000000000000000000000000000000000\",true,\"\"]",
        ok_json,
    );
}

test "relay serializer rejects OK rejection with unprefixed status" {
    var buffer: [4096]u8 = undefined;
    const event_id = [_]u8{0} ** 32;
    const ok = RelayMessage{ .ok = .{
        .event_id = event_id,
        .accepted = false,
        .status = "denied",
    } };

    try std.testing.expectError(
        error.ValueOutOfRange,
        relay_message_serialize_json(buffer[0..], &ok),
    );
}

test "serializer forces MessageEncodeError variants" {
    var short_buffer: [8]u8 = undefined;
    var buffer: [128]u8 = undefined;
    var long_subscription: [65]u8 = [_]u8{'a'} ** 65;

    const close = ClientMessage{ .close = .{ .subscription_id = "sub-1" } };
    try std.testing.expectError(
        error.BufferTooSmall,
        client_message_serialize_json(short_buffer[0..], &close),
    );

    const invalid_subscription = ClientMessage{ .close = .{
        .subscription_id = long_subscription[0..],
    } };
    try std.testing.expectError(
        error.ValueOutOfRange,
        client_message_serialize_json(buffer[0..], &invalid_subscription),
    );
}

test "transcript_apply_relay rejects relay before mark" {
    var state = TranscriptState{};
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-1", .event = sample_event() } };

    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply_relay(&state, event),
    );
}

test "transcript_apply accepts mark and valid sequence" {
    var state = TranscriptState{};
    const first_event = RelayMessage{ .event = .{
        .subscription_id = "sub-1",
        .event = sample_event(),
    } };
    const second_event = RelayMessage{ .event = .{
        .subscription_id = "sub-1",
        .event = sample_event(),
    } };
    const eose = RelayMessage{ .eose = .{ .subscription_id = "sub-1" } };
    const closed = RelayMessage{ .closed = .{
        .subscription_id = "sub-1",
        .status = "closed: done",
    } };

    try transcript_mark_client_req(&state, "sub-1");
    try std.testing.expect(state.stage == .req_sent);
    try transcript_apply(&state, &first_event);
    try transcript_apply(&state, &second_event);
    try transcript_apply(&state, &eose);
    try transcript_apply(&state, &first_event);
    try transcript_apply(&state, &closed);
    try std.testing.expect(state.stage == .closed);
}

test "transcript_apply accepts post-EOSE event for same subscription" {
    var state = TranscriptState{};
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-1", .event = sample_event() } };
    const eose = RelayMessage{ .eose = .{ .subscription_id = "sub-1" } };

    try transcript_mark_client_req(&state, "sub-1");
    try transcript_apply(&state, &eose);
    try std.testing.expect(state.stage == .eose_received);
    try transcript_apply(&state, &event);
    try std.testing.expect(state.stage == .eose_received);
}

test "transcript_apply rejects mismatched subscription" {
    var state = TranscriptState{};
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-2", .event = sample_event() } };

    try transcript_mark_client_req(&state, "sub-1");
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &event),
    );
}

test "transcript_apply rejects invalid ordering" {
    var state = TranscriptState{};
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-1", .event = sample_event() } };
    const eose = RelayMessage{ .eose = .{ .subscription_id = "sub-1" } };
    const closed = RelayMessage{ .closed = .{
        .subscription_id = "sub-1",
        .status = "closed: done",
    } };

    try transcript_mark_client_req(&state, "sub-1");
    try transcript_apply(&state, &closed);
    try std.testing.expect(state.stage == .closed);
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &event),
    );
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &eose),
    );
}

test "transcript_apply keeps CLOSED terminal after EOSE path" {
    var state = TranscriptState{};
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-1", .event = sample_event() } };
    const eose = RelayMessage{ .eose = .{ .subscription_id = "sub-1" } };
    const closed = RelayMessage{ .closed = .{
        .subscription_id = "sub-1",
        .status = "closed: done",
    } };

    try transcript_mark_client_req(&state, "sub-1");
    try transcript_apply(&state, &eose);
    try transcript_apply(&state, &event);
    try transcript_apply(&state, &closed);
    try std.testing.expect(state.stage == .closed);
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &event),
    );
}

test "transcript_apply accepts req to closed transition" {
    var state = TranscriptState{};
    const closed = RelayMessage{ .closed = .{
        .subscription_id = "sub-1",
        .status = "closed: done",
    } };

    try transcript_mark_client_req(&state, "sub-1");
    try transcript_apply(&state, &closed);
    try std.testing.expect(state.stage == .closed);
}

test "transcript_apply rejects non-transcript relay variants" {
    var state = TranscriptState{};
    const notice = RelayMessage{ .notice = .{ .message = "heads up" } };
    const auth = RelayMessage{ .auth = .{ .challenge = "challenge" } };

    try transcript_mark_client_req(&state, "sub-1");
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &notice),
    );
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &auth),
    );
}

test "transcript_apply alias behavior matches transcript_apply_compat" {
    var alias_state = TranscriptState{};
    var compat_state = TranscriptState{};
    const eose = RelayMessage{ .eose = .{ .subscription_id = "sub-1" } };
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-1", .event = sample_event() } };

    try transcript_mark_client_req(&alias_state, "sub-1");
    try transcript_mark_client_req(&compat_state, "sub-1");

    try transcript_apply(&alias_state, &eose);
    try transcript_apply_compat(&compat_state, &eose);
    try std.testing.expect(alias_state.stage == compat_state.stage);

    try transcript_apply(&alias_state, &event);
    try transcript_apply_compat(&compat_state, &event);
    try std.testing.expect(alias_state.stage == compat_state.stage);
}

const sample_event_json_text = "{" ++
    "\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
    "\"pubkey\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
    "\"created_at\":1," ++
    "\"kind\":1," ++
    "\"tags\":[]," ++
    "\"content\":\"sample\"," ++
    "\"sig\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" ++
    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"" ++
    "}";

fn sample_event() nip01_event.Event {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(@sizeOf(nip01_event.Event) > 0);

    var event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{1} ** 32,
        .sig = [_]u8{2} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "sample",
        .tags = &.{},
    };
    std.debug.assert(event.kind == 1);
    std.debug.assert(event.kind != 0);
    std.debug.assert(event.created_at == 1);
    std.debug.assert(event.tags.len == 0);

    event.id = nip01_event.event_compute_id(&event) catch unreachable;

    const recomputed_id = nip01_event.event_compute_id(&event) catch unreachable;
    std.debug.assert(std.mem.eql(u8, event.id[0..], recomputed_id[0..]));
    const zero_id = [_]u8{0} ** 32;
    std.debug.assert(!std.mem.eql(u8, event.id[0..], zero_id[0..]));

    return event;
}
