const std = @import("std");
const secp256k1_backend = @import("crypto/secp256k1_backend.zig");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const delegation_tag_name = "delegation";

pub const DelegationError = error{
    InvalidDelegationTag,
    InvalidDelegatorPubkey,
    InvalidCondition,
    InvalidConditionValue,
    InvalidSignature,
    InvalidSecretKey,
    BackendUnavailable,
    TooManyConditions,
    ConditionsNotMet,
    BufferTooSmall,
};

pub const DelegationCondition = union(enum) {
    kind_eq: u32,
    created_at_lt: u64,
    created_at_gt: u64,
};

pub const DelegationConditions = struct {
    items: []const DelegationCondition,
    text: []const u8,
};

pub const DelegationTag = struct {
    delegator_pubkey: [32]u8,
    conditions_text: []const u8,
    signature: [64]u8,
};

pub const BuiltTag = struct {
    items: [4][]const u8 = undefined,
    item_count: u8 = 0,
    conditions_storage: [limits.tag_item_bytes_max]u8 = undefined,
    pubkey_hex: [limits.pubkey_hex_length]u8 = undefined,
    signature_hex: [limits.sig_hex_length]u8 = undefined,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Parses a canonical `delegation` tag.
pub fn delegation_tag_parse(tag: nip01_event.EventTag) DelegationError!DelegationTag {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 4);

    if (tag.items.len != 4) return error.InvalidDelegationTag;
    if (!std.mem.eql(u8, tag.items[0], delegation_tag_name)) return error.InvalidDelegationTag;

    try validate_condition_text(tag.items[2]);
    return .{
        .delegator_pubkey = parse_lower_hex_32(tag.items[1]) catch {
            return error.InvalidDelegatorPubkey;
        },
        .conditions_text = tag.items[2],
        .signature = parse_lower_hex_64(tag.items[3]) catch return error.InvalidSignature,
    };
}

/// Parses a bounded delegation condition query string and preserves the original text.
pub fn delegation_conditions_parse(
    text: []const u8,
    out: []DelegationCondition,
) DelegationError!DelegationConditions {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(out.len <= limits.nip26_conditions_max);

    if (text.len == 0) return error.InvalidCondition;

    var count: u8 = 0;
    var start: usize = 0;
    while (start < text.len) {
        const end = std.mem.indexOfScalarPos(u8, text, start, '&') orelse text.len;
        const segment = text[start..end];
        if (segment.len == 0) return error.InvalidCondition;
        if (count == out.len) return error.TooManyConditions;
        out[count] = try parse_condition(segment);
        count += 1;
        if (end == text.len) break;
        start = end + 1;
    }

    return .{ .items = out[0..count], .text = text };
}

/// Formats parsed delegation conditions back to their canonical query-string form.
pub fn delegation_conditions_format(
    output: []u8,
    conditions: DelegationConditions,
) DelegationError![]const u8 {
    std.debug.assert(output.len <= limits.nip26_message_bytes_max);
    std.debug.assert(conditions.items.len <= limits.nip26_conditions_max);

    if (conditions.items.len == 0) return error.InvalidCondition;
    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();

    for (conditions.items, 0..) |condition, index| {
        if (index != 0) writer.writeByte('&') catch return error.BufferTooSmall;
        try write_condition(writer, condition);
    }
    return stream.getWritten();
}

/// Builds the exact delegation message string for the delegatee pubkey and conditions text.
pub fn delegation_message_build(
    output: []u8,
    delegatee_pubkey: *const [32]u8,
    conditions_text: []const u8,
) DelegationError![]const u8 {
    std.debug.assert(output.len <= limits.nip26_message_bytes_max);
    std.debug.assert(@intFromPtr(delegatee_pubkey) != 0);

    try validate_condition_text(conditions_text);
    const pubkey_hex = std.fmt.bytesToHex(delegatee_pubkey.*, .lower);
    return std.fmt.bufPrint(
        output,
        "nostr:delegation:{s}:{s}",
        .{ pubkey_hex[0..], conditions_text },
    ) catch return error.BufferTooSmall;
}

/// Signs the delegation message deterministically for the supplied delegatee and conditions.
pub fn delegation_signature_sign(
    output_signature: *[64]u8,
    delegator_secret_key: *const [32]u8,
    delegatee_pubkey: *const [32]u8,
    conditions_text: []const u8,
) DelegationError!void {
    std.debug.assert(@intFromPtr(output_signature) != 0);
    std.debug.assert(@intFromPtr(delegator_secret_key) != 0);

    var message_digest = try delegation_message_digest(delegatee_pubkey, conditions_text);
    secp256k1_backend.sign_schnorr_signature_deterministic(
        delegator_secret_key,
        &message_digest,
        output_signature,
    ) catch |sign_error| {
        return map_sign_error(sign_error);
    };
}

/// Verifies the delegation signature for one delegatee pubkey.
pub fn delegation_signature_verify(
    tag: *const DelegationTag,
    delegatee_pubkey: *const [32]u8,
) DelegationError!void {
    std.debug.assert(@intFromPtr(tag) != 0);
    std.debug.assert(@intFromPtr(delegatee_pubkey) != 0);

    var message_digest = try delegation_message_digest(delegatee_pubkey, tag.conditions_text);
    secp256k1_backend.verify_schnorr_signature(
        &tag.delegator_pubkey,
        &message_digest,
        &tag.signature,
    ) catch |verify_error| {
        return map_verify_error(verify_error);
    };
}

/// Checks whether parsed conditions all match the supplied event fields.
pub fn delegation_event_satisfies(
    conditions: DelegationConditions,
    event: *const nip01_event.Event,
) bool {
    std.debug.assert(conditions.items.len <= limits.nip26_conditions_max);
    std.debug.assert(@intFromPtr(event) != 0);

    for (conditions.items) |condition| {
        if (!condition_matches(condition, event)) return false;
    }
    return true;
}

/// Validates one delegation tag for one event and returns the parsed conditions.
pub fn delegation_event_validate(
    tag: *const DelegationTag,
    event: *const nip01_event.Event,
    out_conditions: []DelegationCondition,
) DelegationError!DelegationConditions {
    std.debug.assert(@intFromPtr(tag) != 0);
    std.debug.assert(@intFromPtr(event) != 0);

    const conditions = try delegation_conditions_parse(tag.conditions_text, out_conditions);
    try delegation_signature_verify(tag, &event.pubkey);
    if (!delegation_event_satisfies(conditions, event)) return error.ConditionsNotMet;
    return conditions;
}

/// Builds a canonical `delegation` tag from parsed fields.
pub fn delegation_tag_build(
    output: *BuiltTag,
    tag: *const DelegationTag,
) DelegationError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(tag) != 0);

    try validate_condition_text(tag.conditions_text);
    output.items[0] = delegation_tag_name;
    output.items[1] = write_hex(output.pubkey_hex[0..], tag.delegator_pubkey[0..]);
    output.items[2] = try copy_conditions_text(output.conditions_storage[0..], tag.conditions_text);
    output.items[3] = write_hex(output.signature_hex[0..], tag.signature[0..]);
    output.item_count = 4;
    return output.as_event_tag();
}

fn parse_condition(text: []const u8) DelegationError!DelegationCondition {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.kind_max == std.math.maxInt(u16));

    if (std.mem.startsWith(u8, text, "kind=")) {
        const value_text = text["kind=".len..];
        const value = parse_u32(value_text) catch return error.InvalidConditionValue;
        if (value > limits.kind_max) return error.InvalidConditionValue;
        return .{ .kind_eq = value };
    }
    if (std.mem.startsWith(u8, text, "created_at<")) {
        const value = parse_u64(text["created_at<".len..]) catch return error.InvalidConditionValue;
        return .{ .created_at_lt = value };
    }
    if (std.mem.startsWith(u8, text, "created_at>")) {
        const value = parse_u64(text["created_at>".len..]) catch return error.InvalidConditionValue;
        return .{ .created_at_gt = value };
    }
    return error.InvalidCondition;
}

fn write_condition(
    writer: anytype,
    condition: DelegationCondition,
) DelegationError!void {
    std.debug.assert(@typeInfo(DelegationCondition) == .@"union");
    std.debug.assert(@TypeOf(writer) != void);

    switch (condition) {
        .kind_eq => |value| writer.print("kind={d}", .{value}) catch return error.BufferTooSmall,
        .created_at_lt => |value| writer.print(
            "created_at<{d}",
            .{value},
        ) catch return error.BufferTooSmall,
        .created_at_gt => |value| writer.print(
            "created_at>{d}",
            .{value},
        ) catch return error.BufferTooSmall,
    }
}

fn condition_matches(condition: DelegationCondition, event: *const nip01_event.Event) bool {
    std.debug.assert(@typeInfo(DelegationCondition) == .@"union");
    std.debug.assert(@intFromPtr(event) != 0);

    return switch (condition) {
        .kind_eq => |value| event.kind == value,
        .created_at_lt => |value| event.created_at < value,
        .created_at_gt => |value| event.created_at > value,
    };
}

fn validate_condition_text(text: []const u8) DelegationError!void {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.nip26_conditions_max > 0);

    var conditions_buf: [limits.nip26_conditions_max]DelegationCondition = undefined;
    _ = try delegation_conditions_parse(text, conditions_buf[0..]);
}

fn delegation_message_digest(
    delegatee_pubkey: *const [32]u8,
    conditions_text: []const u8,
) DelegationError![32]u8 {
    std.debug.assert(@intFromPtr(delegatee_pubkey) != 0);
    std.debug.assert(conditions_text.len <= limits.tag_item_bytes_max);

    var message_buffer: [limits.nip26_message_bytes_max]u8 = undefined;
    const message = try delegation_message_build(
        message_buffer[0..],
        delegatee_pubkey,
        conditions_text,
    );
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update(message);

    var digest: [32]u8 = undefined;
    hash.final(&digest);
    return digest;
}

fn copy_conditions_text(output: []u8, text: []const u8) DelegationError![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.tag_item_bytes_max);

    if (output.len < text.len) return error.BufferTooSmall;
    @memcpy(output[0..text.len], text);
    return output[0..text.len];
}

fn write_hex(output: []u8, bytes: []const u8) []const u8 {
    std.debug.assert(output.len == bytes.len * 2);
    std.debug.assert(bytes.len > 0);

    for (bytes, 0..) |byte, index| {
        const offset = index * 2;
        output[offset] = nibble_to_hex(byte >> 4);
        output[offset + 1] = nibble_to_hex(byte & 0x0f);
    }
    return output;
}

fn nibble_to_hex(value: u8) u8 {
    std.debug.assert(value < 16);
    std.debug.assert(@sizeOf(u8) == 1);

    if (value < 10) return '0' + value;
    return 'a' + (value - 10);
}

fn parse_u32(text: []const u8) error{InvalidNumber}!u32 {
    std.debug.assert(text.len <= 20);
    std.debug.assert(@sizeOf(u32) == 4);

    if (text.len == 0) return error.InvalidNumber;
    return std.fmt.parseUnsigned(u32, text, 10) catch return error.InvalidNumber;
}

fn parse_u64(text: []const u8) error{InvalidNumber}!u64 {
    std.debug.assert(text.len <= 20);
    std.debug.assert(@sizeOf(u64) == 8);

    if (text.len == 0) return error.InvalidNumber;
    return std.fmt.parseUnsigned(u64, text, 10) catch return error.InvalidNumber;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.pubkey_hex_length);
    std.debug.assert(limits.pubkey_hex_length == 64);

    var output: [32]u8 = undefined;
    try validate_lower_hex(text, limits.pubkey_hex_length);
    _ = std.fmt.hexToBytes(output[0..], text) catch return error.InvalidHex;
    return output;
}

fn parse_lower_hex_64(text: []const u8) error{InvalidHex}![64]u8 {
    std.debug.assert(text.len <= limits.sig_hex_length);
    std.debug.assert(limits.sig_hex_length == 128);

    var output: [64]u8 = undefined;
    try validate_lower_hex(text, limits.sig_hex_length);
    _ = std.fmt.hexToBytes(output[0..], text) catch return error.InvalidHex;
    return output;
}

fn validate_lower_hex(text: []const u8, expected_length: u8) error{InvalidHex}!void {
    std.debug.assert(expected_length > 0);
    std.debug.assert(expected_length <= limits.sig_hex_length);

    if (text.len != expected_length) return error.InvalidHex;
    for (text) |byte| {
        if (!std.ascii.isHex(byte)) return error.InvalidHex;
        if (std.ascii.isUpper(byte)) return error.InvalidHex;
    }
}

fn map_verify_error(verify_error: secp256k1_backend.BackendVerifyError) DelegationError {
    std.debug.assert(@intFromError(verify_error) >= 0);
    std.debug.assert(@typeInfo(DelegationError) == .error_set);

    return switch (verify_error) {
        error.InvalidPublicKey => error.InvalidDelegatorPubkey,
        error.InvalidSignature => error.InvalidSignature,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

fn map_sign_error(sign_error: secp256k1_backend.BackendSignError) DelegationError {
    std.debug.assert(@intFromError(sign_error) >= 0);
    std.debug.assert(@typeInfo(DelegationError) == .error_set);

    return switch (sign_error) {
        error.InvalidSecretKey => error.InvalidSecretKey,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

test "delegation conditions parse and format preserve order" {
    var parsed_conditions: [3]DelegationCondition = undefined;
    const conditions = try delegation_conditions_parse(
        "kind=1&created_at>1674834236&created_at<1677426236",
        parsed_conditions[0..],
    );
    try std.testing.expectEqual(@as(usize, 3), conditions.items.len);
    try std.testing.expect(conditions.items[0] == .kind_eq);
    try std.testing.expect(conditions.items[1] == .created_at_gt);

    var output: [96]u8 = undefined;
    const rendered = try delegation_conditions_format(output[0..], conditions);
    try std.testing.expectEqualStrings(conditions.text, rendered);
}

test "delegation conditions reject malformed query segments" {
    var conditions_buffer: [2]DelegationCondition = undefined;

    try std.testing.expectError(
        error.InvalidCondition,
        delegation_conditions_parse("kind=1&&created_at>1", conditions_buffer[0..]),
    );
    try std.testing.expectError(
        error.InvalidCondition,
        delegation_conditions_parse("kind<1", conditions_buffer[0..]),
    );
    try std.testing.expectError(
        error.InvalidConditionValue,
        delegation_conditions_parse("kind=999999", conditions_buffer[0..]),
    );
}

test "delegation sign verify and tag build roundtrip" {
    const delegator_secret = parse_lower_hex_32(
        "ee35e8bb71131c02c1d7e73231daa48e9953d329a4b701f7133c8f46dd21139c",
    ) catch unreachable;
    const delegatee_pubkey = parse_lower_hex_32(
        "477318cfb5427b9cfc66a9fa376150c1ddbc62115ae27cef72417eb959691396",
    ) catch unreachable;
    const delegator_pubkey = parse_lower_hex_32(
        "8e0d3d3eb2881ec137a11debe736a9086715a8c8beeeda615780064d68bc25dd",
    ) catch unreachable;
    const conditions_text = "kind=1&created_at>1674834236&created_at<1677426236";

    var signature: [64]u8 = undefined;
    try delegation_signature_sign(
        &signature,
        &delegator_secret,
        &delegatee_pubkey,
        conditions_text,
    );

    const tag = DelegationTag{
        .delegator_pubkey = delegator_pubkey,
        .conditions_text = conditions_text,
        .signature = signature,
    };
    try delegation_signature_verify(&tag, &delegatee_pubkey);

    var built: BuiltTag = .{};
    const event_tag = try delegation_tag_build(&built, &tag);
    const parsed = try delegation_tag_parse(event_tag);
    try std.testing.expectEqualStrings(conditions_text, parsed.conditions_text);
    try std.testing.expectEqualSlices(u8, tag.signature[0..], parsed.signature[0..]);
}

test "delegation event validate enforces signature and all conditions" {
    const delegator_secret = parse_lower_hex_32(
        "ee35e8bb71131c02c1d7e73231daa48e9953d329a4b701f7133c8f46dd21139c",
    ) catch unreachable;
    const delegator_pubkey = parse_lower_hex_32(
        "8e0d3d3eb2881ec137a11debe736a9086715a8c8beeeda615780064d68bc25dd",
    ) catch unreachable;
    const delegatee_pubkey = parse_lower_hex_32(
        "477318cfb5427b9cfc66a9fa376150c1ddbc62115ae27cef72417eb959691396",
    ) catch unreachable;
    const conditions_text = "kind=1&created_at>1674834236&created_at<1677426236";

    var signature: [64]u8 = undefined;
    try delegation_signature_sign(
        &signature,
        &delegator_secret,
        &delegatee_pubkey,
        conditions_text,
    );
    const tag = DelegationTag{
        .delegator_pubkey = delegator_pubkey,
        .conditions_text = conditions_text,
        .signature = signature,
    };
    const matching = test_event(delegatee_pubkey, 1, 1_674_900_000);
    var parsed_conditions: [3]DelegationCondition = undefined;
    _ = try delegation_event_validate(&tag, &matching, parsed_conditions[0..]);

    const wrong_kind = test_event(delegatee_pubkey, 4, 1_674_900_000);
    try std.testing.expectError(
        error.ConditionsNotMet,
        delegation_event_validate(&tag, &wrong_kind, parsed_conditions[0..]),
    );
}

test "delegation backend mapping preserves outage distinct from caller blame" {
    try std.testing.expect(map_verify_error(error.BackendUnavailable) == error.BackendUnavailable);
    try std.testing.expect(map_sign_error(error.BackendUnavailable) == error.BackendUnavailable);
    try std.testing.expect(map_verify_error(error.BackendUnavailable) != error.InvalidSignature);
    try std.testing.expect(map_sign_error(error.BackendUnavailable) != error.InvalidSecretKey);
}

fn test_event(pubkey: [32]u8, kind: u32, created_at: u64) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(created_at > 0);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = created_at,
        .content = "",
        .tags = &.{},
    };
}
