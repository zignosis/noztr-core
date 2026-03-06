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
    InvalidPrefix,
};

pub const MessageEncodeError = error{ BufferTooSmall, ValueOutOfRange };

pub const ClientMessage = union(enum) {
    req: struct { subscription_id: []const u8, filter: nip01_filter.Filter },
    close: struct { subscription_id: []const u8 },
    auth: struct { event: nip01_event.Event },
    count: struct { subscription_id: []const u8, filter: nip01_filter.Filter },
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
/// `EVENT* -> EOSE -> CLOSED`.
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
    std.debug.assert(input.len <= limits.relay_message_bytes_max + 1);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const root = try parse_message_array(input, scratch);
    const command = try parse_command(root.array.items[0]);

    if (std.mem.eql(u8, command, "REQ")) {
        return parse_client_req(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "CLOSE")) {
        return parse_client_close(root.array.items);
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
    std.debug.assert(input.len <= limits.relay_message_bytes_max + 1);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const root = try parse_message_array(input, scratch);
    const command = try parse_command(root.array.items[0]);

    if (std.mem.eql(u8, command, "EVENT")) {
        return parse_relay_event(root.array.items, scratch);
    }
    if (std.mem.eql(u8, command, "EOSE")) {
        return parse_relay_eose(root.array.items);
    }
    if (std.mem.eql(u8, command, "OK")) {
        return parse_relay_ok(root.array.items);
    }
    if (std.mem.eql(u8, command, "CLOSED")) {
        return parse_relay_closed(root.array.items);
    }
    if (std.mem.eql(u8, command, "NOTICE")) {
        return parse_relay_notice(root.array.items);
    }
    if (std.mem.eql(u8, command, "AUTH")) {
        return parse_relay_auth(root.array.items);
    }
    if (std.mem.eql(u8, command, "COUNT")) {
        return parse_relay_count(root.array.items);
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
            try write_output_bytes(output, &index, "[\"REQ\",");
            try write_output_string(output, &index, request.subscription_id);
            try write_output_bytes(output, &index, ",");
            try serialize_filter(output, &index, &request.filter);
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
            try write_output_bytes(output, &index, "[\"COUNT\",");
            try write_output_string(output, &index, count_message.subscription_id);
            try write_output_bytes(output, &index, ",");
            try serialize_filter(output, &index, &count_message.filter);
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
            try validate_prefixed_status_for_encode(ok_message.status);
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

pub fn transcript_apply(
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
        const id_hex = std.fmt.bytesToHex(filter.ids[item_index], .lower);
        try write_output_bytes(output, index, "\"");
        try write_output_bytes(output, index, id_hex[0..]);
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
        const author_hex = std.fmt.bytesToHex(filter.authors[item_index], .lower);
        try write_output_bytes(output, index, "\"");
        try write_output_bytes(output, index, author_hex[0..]);
        try write_output_bytes(output, index, "\"");
    }
    try write_output_bytes(output, index, "]");
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
    scratch: std.mem.Allocator,
) MessageParseError!std.json.Value {
    std.debug.assert(input.len <= limits.relay_message_bytes_max + 1);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len > limits.relay_message_bytes_max) {
        return error.InputTooLong;
    }
    if (input.len == 0) {
        return error.InvalidMessage;
    }

    const root = std.json.parseFromSliceLeaky(std.json.Value, scratch, input, .{}) catch {
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
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 3) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1]);
    const filter = try parse_filter(values[2], scratch);
    return .{ .req = .{ .subscription_id = subscription_id, .filter = filter } };
}

fn parse_client_close(values: []const std.json.Value) MessageParseError!ClientMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(limits.subscription_id_bytes_max == 64);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1]);
    return .{ .close = .{ .subscription_id = subscription_id } };
}

fn parse_client_auth(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!ClientMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

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
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 3) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1]);
    const filter = try parse_filter(values[2], scratch);
    return .{ .count = .{ .subscription_id = subscription_id, .filter = filter } };
}

fn parse_relay_event(
    values: []const std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError!RelayMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (values.len != 3) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1]);
    const event = try parse_event(values[2], scratch);
    return .{ .event = .{ .subscription_id = subscription_id, .event = event } };
}

fn parse_relay_eose(values: []const std.json.Value) MessageParseError!RelayMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(limits.subscription_id_bytes_max == 64);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1]);
    return .{ .eose = .{ .subscription_id = subscription_id } };
}

fn parse_relay_ok(values: []const std.json.Value) MessageParseError!RelayMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(limits.id_hex_length == 64);

    if (values.len != 4) {
        return error.InvalidArity;
    }
    const event_id = try parse_hex_32(values[1]);
    const accepted = try parse_bool(values[2]);
    const status = try parse_prefixed_status(values[3]);
    return .{ .ok = .{ .event_id = event_id, .accepted = accepted, .status = status } };
}

fn parse_relay_closed(values: []const std.json.Value) MessageParseError!RelayMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(limits.subscription_id_bytes_max == 64);

    if (values.len != 3) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1]);
    const status = try parse_prefixed_status(values[2]);
    return .{ .closed = .{ .subscription_id = subscription_id, .status = status } };
}

fn parse_relay_notice(values: []const std.json.Value) MessageParseError!RelayMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const message = try parse_string(values[1]);
    return .{ .notice = .{ .message = message } };
}

fn parse_relay_auth(values: []const std.json.Value) MessageParseError!RelayMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    if (values.len != 2) {
        return error.InvalidArity;
    }
    const challenge = try parse_string(values[1]);
    return .{ .auth = .{ .challenge = challenge } };
}

fn parse_relay_count(values: []const std.json.Value) MessageParseError!RelayMessage {
    std.debug.assert(values.len <= std.math.maxInt(u16));
    std.debug.assert(limits.subscription_id_bytes_max == 64);

    if (values.len != 3) {
        return error.InvalidArity;
    }
    const subscription_id = try parse_subscription_id(values[1]);
    const count = try parse_count_object(values[2]);
    return .{ .count = .{ .subscription_id = subscription_id, .count = count } };
}

fn parse_subscription_id(value: std.json.Value) MessageParseError![]const u8 {
    std.debug.assert(limits.subscription_id_bytes_max == 64);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    const text = try parse_string(value);
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

    var output: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&output, source) catch return error.InvalidFieldType;
    return output;
}

fn parse_prefixed_status(value: std.json.Value) MessageParseError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.subscription_id_bytes_max > 0);

    const status = try parse_string(value);
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
    const json_text = try json_value_to_text(value, scratch);
    return nip01_filter.filter_parse_json(json_text, scratch) catch return error.InvalidFieldType;
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
    const json_text = try json_value_to_text(value, scratch);
    return nip01_event.event_parse_json(json_text, scratch) catch return error.InvalidFieldType;
}

fn json_value_to_text(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) MessageParseError![]const u8 {
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);
    std.debug.assert(limits.relay_message_bytes_max > 0);

    const output = std.json.Stringify.valueAlloc(scratch, value, .{}) catch {
        return error.InvalidMessage;
    };
    if (output.len > limits.relay_message_bytes_max) {
        return error.InputTooLong;
    }
    return output;
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

fn transcript_apply_relay(
    state: *TranscriptState,
    message: RelayMessage,
) error{InvalidTranscriptTransition}!void {
    std.debug.assert(state.subscription_id_len <= limits.subscription_id_bytes_max);
    std.debug.assert(@intFromPtr(state) != 0);

    switch (message) {
        .event => |event_message| {
            if (state.stage == .idle) {
                try transcript_set_subscription_id(state, event_message.subscription_id);
                state.stage = .req_sent;
                return;
            }
            if (state.stage != .req_sent) return error.InvalidTranscriptTransition;
            if (!transcript_subscription_matches(state, event_message.subscription_id)) {
                return error.InvalidTranscriptTransition;
            }
        },
        .eose => |eose_message| {
            if (state.stage == .idle) {
                try transcript_set_subscription_id(state, eose_message.subscription_id);
                state.stage = .eose_received;
                return;
            }
            if (state.stage != .req_sent) return error.InvalidTranscriptTransition;
            if (!transcript_subscription_matches(state, eose_message.subscription_id)) {
                return error.InvalidTranscriptTransition;
            }
            state.stage = .eose_received;
        },
        .closed => |closed_message| {
            if (state.stage != .eose_received) {
                return error.InvalidTranscriptTransition;
            }
            if (!transcript_subscription_matches(state, closed_message.subscription_id)) {
                return error.InvalidTranscriptTransition;
            }
            state.stage = .closed;
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
        error.InvalidPrefix,
        relay_message_parse_json("[\"CLOSED\",\"sub-1\",\"missing\"]", arena.allocator()),
    );
}

test "client serialization is deterministic" {
    var buffer: [1024]u8 = undefined;
    var filter = nip01_filter.Filter{};
    filter.kinds[0] = 1;
    filter.kinds_count = 1;

    const req = ClientMessage{ .req = .{ .subscription_id = "sub-1", .filter = filter } };
    const req_json = try client_message_serialize_json(buffer[0..], &req);
    try std.testing.expectEqualStrings("[\"REQ\",\"sub-1\",{\"kinds\":[1]}]", req_json);

    const close = ClientMessage{ .close = .{ .subscription_id = "sub-1" } };
    const close_json = try client_message_serialize_json(buffer[0..], &close);
    try std.testing.expectEqualStrings("[\"CLOSE\",\"sub-1\"]", close_json);
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

test "transcript_apply accepts post-REQ EVENT* -> EOSE -> CLOSED" {
    var state = TranscriptState{};
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-1", .event = sample_event() } };
    const eose = RelayMessage{ .eose = .{ .subscription_id = "sub-1" } };
    const closed = RelayMessage{ .closed = .{
        .subscription_id = "sub-1",
        .status = "closed: done",
    } };

    try transcript_apply(&state, &event);
    try transcript_apply(&state, &event);
    try transcript_apply(&state, &eose);
    try transcript_apply(&state, &closed);
    try std.testing.expect(state.stage == .closed);
}

test "transcript_apply accepts post-REQ EOSE -> CLOSED" {
    var state = TranscriptState{};
    const eose = RelayMessage{ .eose = .{ .subscription_id = "sub-1" } };
    const closed = RelayMessage{ .closed = .{
        .subscription_id = "sub-1",
        .status = "closed: done",
    } };

    try transcript_apply(&state, &eose);
    try std.testing.expect(state.stage == .eose_received);
    try transcript_apply(&state, &closed);
    try std.testing.expect(state.stage == .closed);
}

test "transcript_apply rejects idle -> CLOSED" {
    var state = TranscriptState{};
    const closed = RelayMessage{ .closed = .{
        .subscription_id = "sub-1",
        .status = "closed: done",
    } };

    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &closed),
    );
}

test "transcript_apply rejects idle -> EVENT -> CLOSED without EOSE" {
    var state = TranscriptState{};
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-1", .event = sample_event() } };
    const closed = RelayMessage{ .closed = .{
        .subscription_id = "sub-1",
        .status = "closed: done",
    } };

    try transcript_apply(&state, &event);
    try std.testing.expect(state.stage == .req_sent);
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &closed),
    );
}

test "transcript_apply rejects subscription mismatch" {
    var state = TranscriptState{};
    const event = RelayMessage{ .event = .{ .subscription_id = "sub-1", .event = sample_event() } };
    const eose = RelayMessage{ .eose = .{ .subscription_id = "sub-2" } };

    try transcript_apply(&state, &event);
    try std.testing.expect(state.stage == .req_sent);
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &eose),
    );
}

test "transcript_apply rejects non-transcript relay variants" {
    var state = TranscriptState{};
    const notice = RelayMessage{ .notice = .{ .message = "heads up" } };
    const auth = RelayMessage{ .auth = .{ .challenge = "challenge" } };

    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &notice),
    );
    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &auth),
    );
}

test "transcript_apply rejects oversized relay subscription_id" {
    var state = TranscriptState{};
    var oversized_subscription_id: [limits.subscription_id_bytes_max + 1]u8 =
        [_]u8{'a'} ** (limits.subscription_id_bytes_max + 1);
    const eose = RelayMessage{ .eose = .{
        .subscription_id = oversized_subscription_id[0..],
    } };

    try std.testing.expectError(
        error.InvalidTranscriptTransition,
        transcript_apply(&state, &eose),
    );
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
    var event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{1} ** 32,
        .sig = [_]u8{2} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "sample",
        .tags = &.{},
    };
    event.id = nip01_event.event_compute_id(&event);
    return event;
}
