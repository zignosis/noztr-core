const std = @import("std");
const limits = @import("limits.zig");
const shared_errors = @import("errors.zig");
const secp256k1_backend = @import("crypto/secp256k1_backend.zig");

pub const EventParseError = shared_errors.EventParseError;
pub const EventVerifyError = shared_errors.EventVerifyError;
pub const EventShapeError = error{
    InvalidUtf8,
    ContentTooLong,
    TooManyTags,
    TooManyTagItems,
    TagItemTooLong,
};
pub const EventSerializeError = EventShapeError || error{BufferTooSmall};
pub const EventVerifyIdError = EventVerifyError || EventShapeError;

pub const ReplaceDecision = enum {
    keep_current,
    replace_with_candidate,
};

pub const EventTag = struct {
    items: []const []const u8 = &.{},
};

pub const Event = struct {
    id: [32]u8,
    pubkey: [32]u8,
    sig: [64]u8,
    kind: u32,
    created_at: u64,
    content: []const u8,
    tags: []const EventTag = &.{},
};

/// Parse an event from a JSON value tree and copy owned fields into `scratch`.
pub fn event_parse_value(value: std.json.Value, scratch: std.mem.Allocator) EventParseError!Event {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .object) {
        return error.InvalidJson;
    }

    return parse_event_object(value.object, scratch);
}

pub fn event_parse_json(input: []const u8, scratch: std.mem.Allocator) EventParseError!Event {
    std.debug.assert(limits.event_json_max > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len == 0) {
        return error.InputTooShort;
    }

    if (input.len > limits.event_json_max) {
        return error.InputTooLong;
    }

    if (!std.unicode.utf8ValidateSlice(input)) {
        return error.InvalidUtf8;
    }

    var parse_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch |parse_error| {
        return map_event_json_parse_error(parse_error);
    };

    return event_parse_value(root, scratch);
}

fn parse_event_object(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) EventParseError!Event {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(limits.id_hex_length == 64);

    var parsed = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 0,
        .created_at = 0,
        .content = "",
        .tags = &.{},
    };
    var has_id = false;
    var has_pubkey = false;
    var has_sig = false;
    var has_kind = false;
    var has_created_at = false;
    var has_content = false;
    var has_tags = false;

    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;

        if (std.mem.eql(u8, key, "id")) {
            if (has_id) return error.DuplicateField;
            parsed.id = try parse_hex_32(value);
            has_id = true;
        } else if (std.mem.eql(u8, key, "pubkey")) {
            if (has_pubkey) return error.DuplicateField;
            parsed.pubkey = try parse_hex_32(value);
            has_pubkey = true;
        } else if (std.mem.eql(u8, key, "sig")) {
            if (has_sig) return error.DuplicateField;
            parsed.sig = try parse_hex_64(value);
            has_sig = true;
        } else if (std.mem.eql(u8, key, "kind")) {
            if (has_kind) return error.DuplicateField;
            parsed.kind = try parse_json_u32(value);
            has_kind = true;
        } else if (std.mem.eql(u8, key, "created_at")) {
            if (has_created_at) return error.DuplicateField;
            parsed.created_at = try parse_json_u64(value);
            has_created_at = true;
        } else if (std.mem.eql(u8, key, "content")) {
            if (has_content) return error.DuplicateField;
            parsed.content = try parse_content_field_owned(value, scratch);
            has_content = true;
        } else if (std.mem.eql(u8, key, "tags")) {
            if (has_tags) return error.DuplicateField;
            parsed.tags = try parse_tags_field(value, scratch);
            has_tags = true;
        }
    }

    if (!has_id) return error.InvalidField;
    if (!has_pubkey) return error.InvalidField;
    if (!has_sig) return error.InvalidField;
    if (!has_kind) return error.InvalidField;
    if (!has_created_at) return error.InvalidField;
    if (!has_content) return error.InvalidField;
    if (!has_tags) return error.InvalidField;

    return parsed;
}

pub fn event_serialize_canonical(
    output: []u8,
    event: *const Event,
) EventSerializeError![]const u8 {
    std.debug.assert(@sizeOf(EventTag) > 0);
    std.debug.assert(@sizeOf(Event) > 0);

    return event_serialize_canonical_json(output, event);
}

pub fn event_serialize_canonical_json(
    output: []u8,
    event: *const Event,
) EventSerializeError![]const u8 {
    std.debug.assert(@sizeOf(EventTag) > 0);
    std.debug.assert(@sizeOf(Event) > 0);

    try event_validate_shape(event);
    return event_serialize_canonical_json_unchecked(output, event);
}

fn event_serialize_canonical_json_unchecked(
    output: []u8,
    event: *const Event,
) error{BufferTooSmall}![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(event.tags.len <= limits.tags_max);

    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    var index: u32 = 0;

    try write_buffer_bytes(output, &index, "[0,\"");
    try write_buffer_bytes(output, &index, pubkey_hex[0..]);
    try write_buffer_bytes(output, &index, "\",");
    try write_buffer_u64(output, &index, event.created_at);
    try write_buffer_bytes(output, &index, ",");
    try write_buffer_u64(output, &index, event.kind);
    try write_buffer_bytes(output, &index, ",");
    try write_buffer_tags(output, &index, event.tags);
    try write_buffer_bytes(output, &index, ",");
    try write_buffer_json_string(output, &index, event.content);
    try write_buffer_bytes(output, &index, "]");

    return output[0..@intCast(index)];
}

pub fn event_compute_id(event: *const Event) [32]u8 {
    std.debug.assert(@sizeOf(EventTag) > 0);
    std.debug.assert(@sizeOf(Event) > 0);

    return event_compute_id_checked(event) catch [_]u8{0} ** 32;
}

pub fn event_compute_id_checked(event: *const Event) EventShapeError![32]u8 {
    std.debug.assert(@sizeOf(EventTag) > 0);
    std.debug.assert(@sizeOf(Event) > 0);

    try event_validate_shape(event);
    return event_compute_id_unchecked(event);
}

fn event_compute_id_unchecked(event: *const Event) [32]u8 {
    std.debug.assert(event.tags.len <= limits.tags_max);
    std.debug.assert(event.content.len <= limits.content_bytes_max);

    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});

    hash.update("[0,\"");
    hash.update(pubkey_hex[0..]);
    hash.update("\",");
    hash_update_u64(&hash, event.created_at);
    hash.update(",");
    hash_update_u64(&hash, event.kind);
    hash.update(",");
    hash_update_tags(&hash, event.tags);
    hash.update(",");
    hash_update_json_string(&hash, event.content);
    hash.update("]");

    var computed_id: [32]u8 = undefined;
    hash.final(&computed_id);
    return computed_id;
}

pub fn event_verify_id(event: *const Event) EventVerifyError!void {
    std.debug.assert(@sizeOf(EventTag) > 0);
    std.debug.assert(@sizeOf(Event) > 0);

    event_verify_id_checked(event) catch |verify_id_error| {
        return map_verify_id_error(verify_id_error);
    };
}

pub fn event_verify_id_checked(event: *const Event) EventVerifyIdError!void {
    std.debug.assert(@sizeOf(EventTag) > 0);
    std.debug.assert(@sizeOf(Event) > 0);

    const computed_id = try event_compute_id_checked(event);
    if (std.mem.eql(u8, &computed_id, &event.id)) {
        return;
    }

    return error.InvalidId;
}

pub fn event_verify_signature(event: *const Event) EventVerifyError!void {
    std.debug.assert(event.sig[0] <= 255);
    std.debug.assert(event.pubkey[0] <= 255);

    secp256k1_backend.verify_schnorr_signature(
        &event.pubkey,
        &event.id,
        &event.sig,
    ) catch |verify_error| {
        return map_backend_verify_error(verify_error);
    };
}

pub fn event_verify(event: *const Event) EventVerifyError!void {
    std.debug.assert(event.created_at <= std.math.maxInt(u64));
    std.debug.assert(event.kind <= std.math.maxInt(u32));

    event_verify_id_checked(event) catch |verify_id_error| {
        return map_verify_id_error(verify_id_error);
    };
    try event_verify_signature(event);
}

fn map_verify_id_error(verify_id_error: EventVerifyIdError) EventVerifyError {
    std.debug.assert(@intFromError(verify_id_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (verify_id_error) {
        error.InvalidId => error.InvalidId,
        error.InvalidUtf8 => error.InvalidId,
        error.ContentTooLong => error.InvalidId,
        error.TooManyTags => error.InvalidId,
        error.TooManyTagItems => error.InvalidId,
        error.TagItemTooLong => error.InvalidId,
        error.InvalidSignature => error.InvalidId,
        error.InvalidPubkey => error.InvalidId,
        error.BackendUnavailable => error.InvalidId,
    };
}

fn event_validate_shape(event: *const Event) EventShapeError!void {
    std.debug.assert(@sizeOf(EventTag) > 0);
    std.debug.assert(@sizeOf(Event) > 0);

    if (event.content.len > limits.content_bytes_max) {
        return error.ContentTooLong;
    }

    if (!std.unicode.utf8ValidateSlice(event.content)) {
        return error.InvalidUtf8;
    }

    if (event.tags.len > limits.tags_max) {
        return error.TooManyTags;
    }

    var tag_index: u32 = 0;
    while (tag_index < event.tags.len) : (tag_index += 1) {
        const tag = event.tags[tag_index];
        if (tag.items.len > limits.tag_items_max) {
            return error.TooManyTagItems;
        }

        var item_index: u32 = 0;
        while (item_index < tag.items.len) : (item_index += 1) {
            const item = tag.items[item_index];
            if (item.len > limits.tag_item_bytes_max) {
                return error.TagItemTooLong;
            }
            if (!std.unicode.utf8ValidateSlice(item)) {
                return error.InvalidUtf8;
            }
        }
    }
}

pub fn event_replace_decision(current: *const Event, candidate: *const Event) ReplaceDecision {
    std.debug.assert(current.created_at <= std.math.maxInt(u64));
    std.debug.assert(candidate.created_at <= std.math.maxInt(u64));

    if (candidate.created_at > current.created_at) {
        return .replace_with_candidate;
    }

    if (candidate.created_at < current.created_at) {
        return .keep_current;
    }

    const lexical_order = std.mem.order(u8, &candidate.id, &current.id);
    if (lexical_order == .gt) {
        return .replace_with_candidate;
    }

    return .keep_current;
}

fn map_backend_verify_error(verify_error: secp256k1_backend.BackendVerifyError) EventVerifyError {
    std.debug.assert(@intFromError(verify_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (verify_error) {
        error.InvalidPublicKey => error.InvalidPubkey,
        error.InvalidSignature => error.InvalidSignature,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

fn map_event_json_parse_error(parse_error: anyerror) EventParseError {
    std.debug.assert(@intFromError(parse_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (parse_error) {
        error.DuplicateField => error.DuplicateField,
        error.ValueTooLong => error.InputTooLong,
        error.OutOfMemory => error.InvalidJson,
        error.UnexpectedToken => error.InvalidJson,
        error.UnexpectedEndOfInput => error.InvalidJson,
        error.BufferUnderrun => error.InvalidJson,
        error.SyntaxError => error.InvalidJson,
        error.InvalidNumber => error.InvalidJson,
        error.Overflow => error.InvalidJson,
        error.InvalidCharacter => error.InvalidJson,
        error.InvalidEnumTag => error.InvalidJson,
        error.UnknownField => error.InvalidJson,
        error.MissingField => error.InvalidJson,
        error.LengthMismatch => error.InvalidJson,
        else => error.InvalidJson,
    };
}

fn parse_content_field(value: std.json.Value) EventParseError![]const u8 {
    std.debug.assert(limits.content_bytes_max > 0);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .string) {
        return error.InvalidField;
    }

    const content = value.string;
    if (!std.unicode.utf8ValidateSlice(content)) {
        return error.InvalidUtf8;
    }

    if (content.len > limits.content_bytes_max) {
        return error.InvalidField;
    }

    return content;
}

fn parse_content_field_owned(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) EventParseError![]const u8 {
    std.debug.assert(limits.content_bytes_max > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const content = try parse_content_field(value);
    const owned = scratch.alloc(u8, content.len) catch return error.InvalidJson;
    if (content.len > 0) {
        @memcpy(owned, content);
    }
    return owned;
}

fn parse_tags_field(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) EventParseError![]const EventTag {
    std.debug.assert(limits.tags_max > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) {
        return error.InvalidField;
    }

    if (value.array.items.len > limits.tags_max) {
        return error.TooManyTags;
    }

    const tags = scratch.alloc(EventTag, value.array.items.len) catch return error.InvalidJson;
    var tag_index: u32 = 0;
    while (tag_index < value.array.items.len) : (tag_index += 1) {
        const tag_value = value.array.items[tag_index];
        if (tag_value != .array) {
            return error.InvalidField;
        }

        if (tag_value.array.items.len > limits.tag_items_max) {
            return error.TooManyTagItems;
        }

        const items = scratch.alloc([]const u8, tag_value.array.items.len) catch {
            return error.InvalidJson;
        };
        var item_index: u32 = 0;
        while (item_index < tag_value.array.items.len) : (item_index += 1) {
            const item = tag_value.array.items[item_index];
            items[item_index] = try parse_tag_item_owned(item, scratch);
        }

        tags[tag_index] = .{ .items = items };
    }

    return tags;
}

fn parse_tag_item(value: std.json.Value) EventParseError![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .string) {
        return error.InvalidField;
    }

    const item = value.string;
    if (!std.unicode.utf8ValidateSlice(item)) {
        return error.InvalidUtf8;
    }

    if (item.len > limits.tag_item_bytes_max) {
        return error.TagItemTooLong;
    }

    return item;
}

fn parse_tag_item_owned(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) EventParseError![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const item = try parse_tag_item(value);
    const owned = scratch.alloc(u8, item.len) catch return error.InvalidJson;
    if (item.len > 0) {
        @memcpy(owned, item);
    }
    return owned;
}

fn parse_json_u32(value: std.json.Value) EventParseError!u32 {
    std.debug.assert(@sizeOf(u32) == 4);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .integer) {
        return error.InvalidField;
    }

    if (value.integer < 0) {
        return error.InvalidField;
    }

    const converted = std.math.cast(u32, value.integer) orelse return error.InvalidField;
    return converted;
}

fn parse_json_u64(value: std.json.Value) EventParseError!u64 {
    std.debug.assert(@sizeOf(u64) == 8);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .integer) {
        return error.InvalidField;
    }

    if (value.integer < 0) {
        return error.InvalidField;
    }

    const converted = std.math.cast(u64, value.integer) orelse return error.InvalidField;
    return converted;
}

fn parse_hex_32(value: std.json.Value) EventParseError![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    var output: [32]u8 = undefined;
    const source = if (value == .string) value.string else return error.InvalidField;
    try validate_lower_hex(source, limits.id_hex_length);
    _ = std.fmt.hexToBytes(&output, source) catch return error.InvalidHex;
    return output;
}

fn parse_hex_64(value: std.json.Value) EventParseError![64]u8 {
    std.debug.assert(limits.sig_hex_length == 128);
    std.debug.assert(limits.sig_hex_length > limits.id_hex_length);

    var output: [64]u8 = undefined;
    const source = if (value == .string) value.string else return error.InvalidField;
    try validate_lower_hex(source, limits.sig_hex_length);
    _ = std.fmt.hexToBytes(&output, source) catch return error.InvalidHex;
    return output;
}

fn validate_lower_hex(source: []const u8, expected_length: u8) EventParseError!void {
    std.debug.assert(expected_length > 0);
    std.debug.assert(expected_length <= 128);

    if (source.len != expected_length) {
        return error.InvalidHex;
    }

    var index: u32 = 0;
    while (index < source.len) : (index += 1) {
        const byte = source[index];
        const is_digit = byte >= '0' and byte <= '9';
        if (is_digit) {
            continue;
        }

        const is_lower_hex = byte >= 'a' and byte <= 'f';
        if (!is_lower_hex) {
            return error.InvalidHex;
        }
    }
}

fn write_buffer_bytes(output: []u8, index: *u32, text: []const u8) error{BufferTooSmall}!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(text.len <= std.math.maxInt(u32));

    const start: usize = index.*;
    const end = start + text.len;
    if (end > output.len) {
        return error.BufferTooSmall;
    }

    @memcpy(output[start..end], text);
    index.* += @intCast(text.len);
}

fn write_buffer_u64(output: []u8, index: *u32, value: u64) error{BufferTooSmall}!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(value <= std.math.maxInt(u64));

    var decimal_buffer: [20]u8 = undefined;
    const decimal_text = std.fmt.bufPrint(&decimal_buffer, "{d}", .{value}) catch unreachable;
    try write_buffer_bytes(output, index, decimal_text);
}

fn write_buffer_json_string(
    output: []u8,
    index: *u32,
    text: []const u8,
) error{BufferTooSmall}!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(text.len <= limits.content_bytes_max);

    try write_buffer_bytes(output, index, "\"");
    var text_index: u32 = 0;
    while (text_index < text.len) : (text_index += 1) {
        const byte = text[text_index];
        try write_json_escaped_byte(output, index, byte);
    }
    try write_buffer_bytes(output, index, "\"");
}

fn write_buffer_tags(
    output: []u8,
    index: *u32,
    tags: []const EventTag,
) error{BufferTooSmall}!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(tags.len <= limits.tags_max);

    try write_buffer_bytes(output, index, "[");
    var tag_index: u32 = 0;
    while (tag_index < tags.len) : (tag_index += 1) {
        if (tag_index > 0) {
            try write_buffer_bytes(output, index, ",");
        }

        const tag = tags[tag_index];
        try write_buffer_bytes(output, index, "[");
        var item_index: u32 = 0;
        while (item_index < tag.items.len) : (item_index += 1) {
            if (item_index > 0) {
                try write_buffer_bytes(output, index, ",");
            }
            try write_buffer_json_string(output, index, tag.items[item_index]);
        }
        try write_buffer_bytes(output, index, "]");
    }
    try write_buffer_bytes(output, index, "]");
}

fn write_json_escaped_byte(
    output: []u8,
    index: *u32,
    byte: u8,
) error{BufferTooSmall}!void {
    std.debug.assert(index.* <= output.len);
    std.debug.assert(byte <= 255);

    switch (byte) {
        '"' => try write_buffer_bytes(output, index, "\\\""),
        '\\' => try write_buffer_bytes(output, index, "\\\\"),
        '\n' => try write_buffer_bytes(output, index, "\\n"),
        '\r' => try write_buffer_bytes(output, index, "\\r"),
        '\t' => try write_buffer_bytes(output, index, "\\t"),
        0x08 => try write_buffer_bytes(output, index, "\\b"),
        0x0c => try write_buffer_bytes(output, index, "\\f"),
        else => {
            if (byte < 0x20) {
                try write_buffer_bytes(output, index, "\\u00");
                var hex_pair: [2]u8 = undefined;
                _ = std.fmt.bufPrint(&hex_pair, "{x:0>2}", .{byte}) catch unreachable;
                try write_buffer_bytes(output, index, hex_pair[0..]);
            } else {
                if (index.* + 1 > output.len) {
                    return error.BufferTooSmall;
                }

                output[index.*] = byte;
                index.* += 1;
            }
        },
    }
}

fn hash_update_u64(hash: *std.crypto.hash.sha2.Sha256, value: u64) void {
    std.debug.assert(value <= std.math.maxInt(u64));
    std.debug.assert(@sizeOf(u64) == 8);

    var decimal_buffer: [20]u8 = undefined;
    const decimal_text = std.fmt.bufPrint(&decimal_buffer, "{d}", .{value}) catch unreachable;
    hash.update(decimal_text);
}

fn hash_update_json_string(hash: *std.crypto.hash.sha2.Sha256, text: []const u8) void {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(@sizeOf(std.crypto.hash.sha2.Sha256) > 0);

    hash.update("\"");
    var index: u32 = 0;
    while (index < text.len) : (index += 1) {
        hash_update_escaped_byte(hash, text[index]);
    }
    hash.update("\"");
}

fn hash_update_tags(hash: *std.crypto.hash.sha2.Sha256, tags: []const EventTag) void {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(@sizeOf(std.crypto.hash.sha2.Sha256) > 0);

    hash.update("[");
    var tag_index: u32 = 0;
    while (tag_index < tags.len) : (tag_index += 1) {
        if (tag_index > 0) {
            hash.update(",");
        }

        const tag = tags[tag_index];
        hash.update("[");
        var item_index: u32 = 0;
        while (item_index < tag.items.len) : (item_index += 1) {
            if (item_index > 0) {
                hash.update(",");
            }
            hash_update_json_string(hash, tag.items[item_index]);
        }
        hash.update("]");
    }
    hash.update("]");
}

fn hash_update_escaped_byte(hash: *std.crypto.hash.sha2.Sha256, byte: u8) void {
    std.debug.assert(byte <= 255);
    std.debug.assert(@sizeOf(std.crypto.hash.sha2.Sha256) > 0);

    switch (byte) {
        '"' => hash.update("\\\""),
        '\\' => hash.update("\\\\"),
        '\n' => hash.update("\\n"),
        '\r' => hash.update("\\r"),
        '\t' => hash.update("\\t"),
        0x08 => hash.update("\\b"),
        0x0c => hash.update("\\f"),
        else => {
            if (byte < 0x20) {
                hash.update("\\u00");
                var hex_pair: [2]u8 = undefined;
                _ = std.fmt.bufPrint(&hex_pair, "{x:0>2}", .{byte}) catch unreachable;
                hash.update(hex_pair[0..]);
            } else {
                const one = [1]u8{byte};
                hash.update(one[0..]);
            }
        },
    }
}

test "event replace tie break is deterministic by lexical id" {
    var current = Event{
        .id = [_]u8{1} ** 32,
        .pubkey = [_]u8{3} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 100,
        .content = "a",
    };
    var candidate = current;
    candidate.id = [_]u8{2} ** 32;

    const decision_a = event_replace_decision(&current, &candidate);
    const decision_b = event_replace_decision(&current, &candidate);

    try std.testing.expect(decision_a == .replace_with_candidate);
    try std.testing.expect(decision_b == .replace_with_candidate);
}

test "event canonical serialization is deterministic" {
    const tag_alpha = [_][]const u8{ "p", "aaaaaaaa" };
    const tag_beta = [_][]const u8{ "e", "bbbbbbbb", "relay" };
    const tags = [_]EventTag{
        .{ .items = tag_alpha[0..] },
        .{ .items = tag_beta[0..] },
    };
    const event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .sig = [_]u8{0x22} ** 64,
        .kind = 1,
        .created_at = 123,
        .content = "line\n\"quoted\"",
        .tags = tags[0..],
    };

    var buffer_a: [256]u8 = undefined;
    var buffer_b: [256]u8 = undefined;
    const serialized_a = try event_serialize_canonical(&buffer_a, &event);
    const serialized_b = try event_serialize_canonical(&buffer_b, &event);

    try std.testing.expectEqualStrings(
        "[0,\"1111111111111111111111111111111111111111111111111111111111111111\",123,1," ++
            "[[\"p\",\"aaaaaaaa\"],[\"e\",\"bbbbbbbb\",\"relay\"]]," ++
            "\"line\\n\\\"quoted\\\"\"]",
        serialized_a,
    );
    try std.testing.expectEqualStrings(serialized_a, serialized_b);
}

test "event verify id follows canonical hash compute" {
    var event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x44} ** 32,
        .sig = [_]u8{0x55} ** 64,
        .kind = 9734,
        .created_at = 1_700_000_000,
        .content = "hello",
    };

    event.id = event_compute_id(&event);
    try event_verify_id(&event);

    event.id[0] ^= 1;
    try std.testing.expectError(error.InvalidId, event_verify_id(&event));
}

test "event compute id checked rejects non-utf8 content" {
    const invalid_content = [_]u8{ 0xC3, 0x28 };
    const event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x44} ** 32,
        .sig = [_]u8{0x55} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = invalid_content[0..],
    };

    const computed_id = event_compute_id(&event);
    const zero_id = [_]u8{0} ** 32;

    try std.testing.expectError(error.InvalidUtf8, event_compute_id_checked(&event));
    try std.testing.expect(std.mem.eql(u8, &computed_id, &zero_id));
}

test "event serialize canonical json rejects oversized content" {
    var large_content: [limits.content_bytes_max + 1]u8 = undefined;
    @memset(large_content[0..], 'x');
    const event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .sig = [_]u8{0x22} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = large_content[0..],
    };
    var output: [128]u8 = undefined;

    try std.testing.expectError(
        error.ContentTooLong,
        event_serialize_canonical_json(&output, &event),
    );
}

test "event verify id checked rejects too many tags" {
    const oversize_tags = [_]EventTag{.{ .items = &.{} }} ** (limits.tags_max + 1);
    const event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .sig = [_]u8{0x22} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "ok",
        .tags = oversize_tags[0..],
    };

    try std.testing.expectError(error.TooManyTags, event_verify_id_checked(&event));
    try std.testing.expectError(error.InvalidId, event_verify_id(&event));
}

test "event serialize canonical json rejects oversized tag item" {
    var large_item: [limits.tag_item_bytes_max + 1]u8 = undefined;
    @memset(large_item[0..], 'x');

    const items = [_][]const u8{ "e", large_item[0..] };
    const tags = [_]EventTag{.{ .items = items[0..] }};
    const event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .sig = [_]u8{0x22} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "ok",
        .tags = tags[0..],
    };
    var output: [128]u8 = undefined;

    try std.testing.expectError(
        error.TagItemTooLong,
        event_serialize_canonical_json(&output, &event),
    );
}

test "event compute id checked rejects too many tag items" {
    const too_many_items = [_][]const u8{"x"} ** (limits.tag_items_max + 1);
    const tags = [_]EventTag{.{ .items = too_many_items[0..] }};
    const event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .sig = [_]u8{0x22} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "ok",
        .tags = tags[0..],
    };

    try std.testing.expectError(error.TooManyTagItems, event_compute_id_checked(&event));
}

test "event verify id checked rejects non-utf8 tag item" {
    const invalid_item = [_]u8{ 0xC3, 0x28 };
    const items = [_][]const u8{ "p", invalid_item[0..] };
    const tags = [_]EventTag{.{ .items = items[0..] }};
    const event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .sig = [_]u8{0x22} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "ok",
        .tags = tags[0..],
    };

    try std.testing.expectError(error.InvalidUtf8, event_verify_id_checked(&event));
    try std.testing.expectError(error.InvalidId, event_verify_id(&event));
}

test "event parse json accepts minimal required fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input =
        "{" ++
        "\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
        "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
        "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
        "\"kind\":1," ++
        "\"created_at\":1700000000," ++
        "\"tags\":[]," ++
        "\"content\":\"ok\"}";

    const event = try event_parse_json(input, arena.allocator());
    try std.testing.expect(event.kind == 1);
    try std.testing.expect(event.created_at == 1_700_000_000);
    try std.testing.expect(event.tags.len == 0);
}

test "event parse value copies content and tag items into scratch" {
    var scratch_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer scratch_arena.deinit();
    var event: Event = undefined;

    {
        var parse_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer parse_arena.deinit();

        const input =
            "{" ++
            "\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
            "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
            "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
            "\"kind\":1,\"created_at\":1700000000," ++
            "\"tags\":[[\"e\",\"target\",\"relay\"]],\"content\":\"ok\"}";

        const root = try std.json.parseFromSliceLeaky(
            std.json.Value,
            parse_arena.allocator(),
            input,
            .{},
        );
        const source_content = root.object.get("content").?.string;
        const source_tags = root.object.get("tags").?.array.items[0].array.items;

        event = try event_parse_value(root, scratch_arena.allocator());
        try std.testing.expect(@intFromPtr(event.content.ptr) != @intFromPtr(source_content.ptr));
        try std.testing.expect(
            @intFromPtr(event.tags[0].items[1].ptr) != @intFromPtr(source_tags[1].string.ptr),
        );
    }

    try std.testing.expectEqualStrings("ok", event.content);
    try std.testing.expect(event.tags.len == 1);
    try std.testing.expect(event.tags[0].items.len == 3);
    try std.testing.expectEqualStrings("target", event.tags[0].items[1]);
}

test "event parse json rejects missing tags" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input =
        "{" ++
        "\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
        "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
        "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
        "\"kind\":1," ++
        "\"created_at\":1700000000," ++
        "\"content\":\"ok\"}";

    try std.testing.expectError(error.InvalidField, event_parse_json(input, arena.allocator()));
}

test "event parse json rejects too many tags" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var input_buffer: [33_000]u8 = undefined;
    var stream = std.io.fixedBufferStream(&input_buffer);
    const writer = stream.writer();

    try writer.writeAll(
        "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
            "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
            "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
            "\"kind\":1,\"created_at\":1,\"tags\":[",
    );

    var index: u32 = 0;
    while (index < limits.tags_max + 1) : (index += 1) {
        if (index > 0) {
            try writer.writeAll(",");
        }
        try writer.writeAll("[]");
    }
    try writer.writeAll("],\"content\":\"ok\"}");

    const input = input_buffer[0..stream.pos];
    try std.testing.expectError(error.TooManyTags, event_parse_json(input, arena.allocator()));
}

test "event parse json rejects too many tag items" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var input_buffer: [16_384]u8 = undefined;
    var stream = std.io.fixedBufferStream(&input_buffer);
    const writer = stream.writer();

    try writer.writeAll(
        "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
            "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
            "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
            "\"kind\":1,\"created_at\":1,\"tags\":[[",
    );

    var index: u32 = 0;
    while (index < limits.tag_items_max + 1) : (index += 1) {
        if (index > 0) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\"x\"");
    }
    try writer.writeAll("]],\"content\":\"ok\"}");

    const input = input_buffer[0..stream.pos];
    try std.testing.expectError(error.TooManyTagItems, event_parse_json(input, arena.allocator()));
}

test "event parse json rejects tag item too long" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var long_item_buffer: [limits.tag_item_bytes_max + 1]u8 = undefined;
    @memset(long_item_buffer[0..], 'x');

    var input_buffer: [16_384]u8 = undefined;
    var stream = std.io.fixedBufferStream(&input_buffer);
    const writer = stream.writer();

    try writer.writeAll(
        "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
            "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
            "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
            "\"kind\":1,\"created_at\":1,\"tags\":[[\"e\",\"",
    );
    try writer.writeAll(long_item_buffer[0..]);
    try writer.writeAll("\"]],\"content\":\"ok\"}");

    const input = input_buffer[0..stream.pos];
    try std.testing.expectError(error.TagItemTooLong, event_parse_json(input, arena.allocator()));
}

test "event verify signature routes through boundary module" {
    var event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 42,
        .content = "hello",
    };
    _ = try std.fmt.hexToBytes(
        &event.pubkey,
        "F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9",
    );
    _ = try std.fmt.hexToBytes(
        &event.sig,
        "E907831F80848D1069A5371B402410364BDF1C5F8307B0084C55F1CE2DCA8215" ++
            "25F66A4A85EA8B71E482A74F382D2CE5EBEEE8FDB2172F477DF4900D310536C0",
    );

    secp256k1_backend.reset_counters();
    try event_verify_signature(&event);

    const call_count = secp256k1_backend.get_verify_signature_call_count();
    try std.testing.expect(call_count == 1);
    try std.testing.expect(call_count != 0);
}

test "event parse json forces input bounds errors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(error.InputTooShort, event_parse_json("", arena.allocator()));

    var too_long: [limits.event_json_max + 1]u8 = undefined;
    @memset(too_long[0..], 'a');
    try std.testing.expectError(
        error.InputTooLong,
        event_parse_json(too_long[0..], arena.allocator()),
    );

    var far_too_long: [limits.event_json_max + 2]u8 = undefined;
    @memset(far_too_long[0..], 'a');
    try std.testing.expectError(
        error.InputTooLong,
        event_parse_json(far_too_long[0..], arena.allocator()),
    );
}

test "event parse json forces invalid json and invalid field" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const malformed_json = "{\"id\":";
    try std.testing.expectError(
        error.InvalidJson,
        event_parse_json(malformed_json, arena.allocator()),
    );

    const wrong_kind_type =
        "{" ++
        "\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
        "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
        "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
        "\"kind\":\"1\"," ++
        "\"created_at\":1,\"tags\":[],\"content\":\"ok\"}";
    try std.testing.expectError(
        error.InvalidField,
        event_parse_json(wrong_kind_type, arena.allocator()),
    );
}

test "event parse json rejects duplicate critical key" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const duplicate_id =
        "{" ++
        "\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
        "\"id\":\"1123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
        "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
        "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
        "\"kind\":1,\"created_at\":1,\"tags\":[],\"content\":\"ok\"}";
    try std.testing.expectError(
        error.DuplicateField,
        event_parse_json(duplicate_id, arena.allocator()),
    );
}

test "event parse json rejects invalid hex length and uppercase case" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const invalid_hex_length =
        "{" ++
        "\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcde\"," ++
        "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
        "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
        "\"kind\":1,\"created_at\":1,\"tags\":[],\"content\":\"ok\"}";
    try std.testing.expectError(
        error.InvalidHex,
        event_parse_json(invalid_hex_length, arena.allocator()),
    );

    const invalid_hex_case =
        "{" ++
        "\"id\":\"ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef0123456789\"," ++
        "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
        "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
        "\"kind\":1,\"created_at\":1,\"tags\":[],\"content\":\"ok\"}";
    try std.testing.expectError(
        error.InvalidHex,
        event_parse_json(invalid_hex_case, arena.allocator()),
    );
}

test "event parse json exposes invalid utf8 through public path" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const invalid_utf8 = [_]u8{ '{', '"', 'i', 'd', '"', ':', '"', 0xC3, 0x28, '"', '}' };
    try std.testing.expectError(
        error.InvalidUtf8,
        event_parse_json(invalid_utf8[0..], arena.allocator()),
    );
}

test "event parse json rejects content over max bound" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var content_buffer: [limits.content_bytes_max + 1]u8 = undefined;
    @memset(content_buffer[0..], 'x');

    var input_buffer: [limits.event_json_max]u8 = undefined;
    var stream = std.io.fixedBufferStream(&input_buffer);
    const writer = stream.writer();

    try writer.writeAll(
        "{\"id\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\"," ++
            "\"pubkey\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"," ++
            "\"sig\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ++
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"," ++
            "\"kind\":1,\"created_at\":1,\"tags\":[],\"content\":\"",
    );
    try writer.writeAll(content_buffer[0..]);
    try writer.writeAll("\"}");

    const input = input_buffer[0..stream.pos];
    try std.testing.expectError(error.InvalidField, event_parse_json(input, arena.allocator()));
}

test "event verify rejects invalid id explicitly" {
    var event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x44} ** 32,
        .sig = [_]u8{0x55} ** 64,
        .kind = 42,
        .created_at = 1_700_000_000,
        .content = "hello",
    };

    event.id = event_compute_id(&event);
    event.id[0] ^= 1;
    try std.testing.expectError(error.InvalidId, event_verify_id(&event));
}

test "event verify rejects invalid signature explicitly" {
    var event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 42,
        .content = "hello",
    };
    _ = try std.fmt.hexToBytes(
        &event.pubkey,
        "F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9",
    );
    _ = try std.fmt.hexToBytes(
        &event.sig,
        "E907831F80848D1069A5371B402410364BDF1C5F8307B0084C55F1CE2DCA8215" ++
            "25F66A4A85EA8B71E482A74F382D2CE5EBEEE8FDB2172F477DF4900D310536C0",
    );

    event.sig[0] ^= 1;
    try std.testing.expectError(error.InvalidSignature, event_verify_signature(&event));
}

test "event verify preserves backend unavailable mapping" {
    const mapped_error = map_backend_verify_error(error.BackendUnavailable);

    try std.testing.expect(mapped_error == error.BackendUnavailable);
    try std.testing.expect(mapped_error != error.InvalidSignature);
}

test "event verify rejects invalid pubkey explicitly" {
    var event = Event{
        .id = [_]u8{9} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "x",
    };
    _ = try std.fmt.hexToBytes(
        &event.pubkey,
        "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC30",
    );
    event.sig[0] = 1;

    try std.testing.expectError(error.InvalidPubkey, event_verify_signature(&event));
}
