const std = @import("std");
const limits = @import("limits.zig");
const shared_errors = @import("errors.zig");
const secp256k1_backend = @import("crypto/secp256k1_backend.zig");

pub const EventParseError = shared_errors.EventParseError;
pub const EventVerifyError = shared_errors.EventVerifyError;

pub const ReplaceDecision = enum {
    keep_current,
    replace_with_candidate,
};

pub const Event = struct {
    id: [32]u8,
    pubkey: [32]u8,
    sig: [64]u8,
    kind: u32,
    created_at: u64,
    content: []const u8,
};

pub fn event_parse_json(input: []const u8, scratch: std.mem.Allocator) EventParseError!Event {
    std.debug.assert(input.len <= limits.event_json_max + 1);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len == 0) {
        return error.InputTooShort;
    }

    if (input.len > limits.event_json_max) {
        return error.InputTooLong;
    }

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        scratch,
        input,
        .{},
    ) catch |parse_error| {
        return map_event_json_parse_error(parse_error);
    };

    if (root != .object) {
        return error.InvalidJson;
    }

    return parse_event_object(root.object);
}

fn parse_event_object(object: std.json.ObjectMap) EventParseError!Event {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(limits.id_hex_length == 64);

    var parsed = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 0,
        .created_at = 0,
        .content = "",
    };
    var has_id = false;
    var has_pubkey = false;
    var has_sig = false;
    var has_kind = false;
    var has_created_at = false;
    var has_content = false;

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
            parsed.content = try parse_content_field(value);
            has_content = true;
        }
    }

    if (!has_id) return error.InvalidField;
    if (!has_pubkey) return error.InvalidField;
    if (!has_sig) return error.InvalidField;
    if (!has_kind) return error.InvalidField;
    if (!has_created_at) return error.InvalidField;
    if (!has_content) return error.InvalidField;

    return parsed;
}

pub fn event_serialize_canonical(
    output: []u8,
    event: *const Event,
) error{BufferTooSmall}![]const u8 {
    std.debug.assert(output.len >= 0);
    std.debug.assert(event.content.len <= limits.content_bytes_max);

    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    var index: u32 = 0;

    try write_buffer_bytes(output, &index, "[0,\"");
    try write_buffer_bytes(output, &index, pubkey_hex[0..]);
    try write_buffer_bytes(output, &index, "\",");
    try write_buffer_u64(output, &index, event.created_at);
    try write_buffer_bytes(output, &index, ",");
    try write_buffer_u64(output, &index, event.kind);
    try write_buffer_bytes(output, &index, ",[],");
    try write_buffer_json_string(output, &index, event.content);
    try write_buffer_bytes(output, &index, "]");

    return output[0..@intCast(index)];
}

pub fn event_compute_id(event: *const Event) [32]u8 {
    std.debug.assert(event.content.len <= limits.content_bytes_max);
    std.debug.assert(event.kind <= std.math.maxInt(u32));

    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});

    hash.update("[0,\"");
    hash.update(pubkey_hex[0..]);
    hash.update("\",");
    hash_update_u64(&hash, event.created_at);
    hash.update(",");
    hash_update_u64(&hash, event.kind);
    hash.update(",[],");
    hash_update_json_string(&hash, event.content);
    hash.update("]");

    var computed_id: [32]u8 = undefined;
    hash.final(&computed_id);
    return computed_id;
}

pub fn event_verify_id(event: *const Event) EventVerifyError!void {
    std.debug.assert(event.created_at <= std.math.maxInt(u64));
    std.debug.assert(event.id[0] <= 255);

    const computed_id = event_compute_id(event);
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

    try event_verify_id(event);
    try event_verify_signature(event);
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
        error.BackendUnavailable => error.InvalidSignature,
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
    const event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .sig = [_]u8{0x22} ** 64,
        .kind = 1,
        .created_at = 123,
        .content = "line\n\"quoted\"",
    };

    var buffer_a: [256]u8 = undefined;
    var buffer_b: [256]u8 = undefined;
    const serialized_a = try event_serialize_canonical(&buffer_a, &event);
    const serialized_b = try event_serialize_canonical(&buffer_b, &event);

    try std.testing.expectEqualStrings(
        "[0,\"1111111111111111111111111111111111111111111111111111111111111111\",123,1,[]," ++
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
        "\"content\":\"ok\"}";

    const event = try event_parse_json(input, arena.allocator());
    try std.testing.expect(event.kind == 1);
    try std.testing.expect(event.created_at == 1_700_000_000);
}

test "event verify signature routes through boundary module" {
    var event = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{7} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 42,
        .content = "hello",
    };
    event.id = event_compute_id(&event);
    event.sig[0] = event.id[0];

    secp256k1_backend.reset_counters();
    try event_verify_signature(&event);

    const call_count = secp256k1_backend.get_verify_signature_call_count();
    try std.testing.expect(call_count == 1);
    try std.testing.expect(call_count != 0);
}

test "event typed errors are forceable through public paths" {
    var event = Event{
        .id = [_]u8{9} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "x",
    };
    event.sig[0] = 1;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(error.InputTooShort, event_parse_json("", std.testing.allocator));
    try std.testing.expectError(error.InvalidPubkey, event_verify_signature(&event));
    try std.testing.expectError(error.InvalidId, event_verify_id(&event));
    try std.testing.expectError(
        error.InvalidHex,
        event_parse_json("{\"id\":\"XYZ\"}", arena.allocator()),
    );
}
