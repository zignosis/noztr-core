const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

/// Typed failures for strict NIP-13 PoW parsing and validation.
pub const PowError = error{
    DifficultyOutOfRange,
    InvalidNonceTag,
    InvalidNonceCounter,
    InvalidNonceCommitment,
};

/// Typed failures for canonical trust-boundary PoW checks.
///
/// `InvalidId` is emitted when in-memory event shape is invalid for canonical id verification
/// or when `event.id` does not match canonical serialization.
pub const PowVerifiedIdError = PowError || error{InvalidId};

/// Counts leading zero bits in a 32-byte event id.
pub fn pow_leading_zero_bits(id: *const [32]u8) u16 {
    std.debug.assert(@intFromPtr(id) != 0);
    std.debug.assert(id.len == 32);

    var bits: u16 = 0;
    var index: u8 = 0;
    while (index < id.len) : (index += 1) {
        const byte = id[index];
        if (byte == 0) {
            bits += 8;
            continue;
        }

        var bit_mask: u8 = 0x80;
        while ((byte & bit_mask) == 0) : (bit_mask >>= 1) {
            bits += 1;
        }
        break;
    }

    std.debug.assert(bits <= 256);
    std.debug.assert(bits >= 0);
    return bits;
}

/// Extracts optional committed nonce difficulty from a strict nonce tag.
pub fn pow_extract_nonce_target(event: *const nip01_event.Event) PowError!?u16 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.id.len == 32);

    var found_nonce = false;
    var nonce_target: ?u16 = null;
    var tag_index: usize = 0;
    while (tag_index < event.tags.len) : (tag_index += 1) {
        const tag = event.tags[tag_index];
        if (tag.items.len == 0) {
            continue;
        }
        if (!std.mem.eql(u8, tag.items[0], "nonce")) {
            continue;
        }

        if (found_nonce) {
            return error.InvalidNonceTag;
        }
        found_nonce = true;

        if (tag.items.len == 2) {
            try parse_nonce_counter(tag.items[1]);
            continue;
        }
        if (tag.items.len == 3) {
            try parse_nonce_counter(tag.items[1]);
            nonce_target = try parse_nonce_target(tag.items[2]);
            continue;
        }
        return error.InvalidNonceTag;
    }

    return nonce_target;
}

/// Non-canonical compatibility-only PoW helper.
///
/// This function validates nonce-tag shape and compares `event.id` difficulty to `required_bits`,
/// but does not verify `event.id` integrity. It is not safe at trust boundaries where events are
/// untrusted. Use `pow_meets_difficulty_verified_id` for canonical trust-boundary behavior.
pub fn pow_meets_difficulty(event: *const nip01_event.Event, required_bits: u16) PowError!bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.id.len == 32);

    if (required_bits > 256) {
        return error.DifficultyOutOfRange;
    }

    const nonce_target = try pow_extract_nonce_target(event);
    if (!event_has_nonce_tag(event)) {
        return false;
    }

    const leading_zero_bits = pow_leading_zero_bits(&event.id);
    try enforce_nonce_commitment_policy(nonce_target, required_bits, leading_zero_bits);
    return leading_zero_bits >= required_bits;
}

fn enforce_nonce_commitment_policy(
    nonce_target: ?u16,
    required_bits: u16,
    leading_zero_bits: u16,
) PowError!void {
    std.debug.assert(required_bits <= 256);
    std.debug.assert(@sizeOf(u16) == 2);
    std.debug.assert(leading_zero_bits <= 256);

    if (nonce_target) |committed_bits| {
        if (committed_bits < required_bits) {
            return error.InvalidNonceCommitment;
        }
        if (leading_zero_bits < committed_bits) {
            return error.InvalidNonceCommitment;
        }
    }
}

/// Canonical trust-boundary PoW wrapper.
///
/// This wrapper verifies `event.id` against canonical event serialization first, then applies the
/// strict nonce-shape and difficulty checks from `pow_meets_difficulty`. Use this entry point for
/// untrusted event inputs and relay-facing policy checks.
pub fn pow_meets_difficulty_verified_id(
    event: *const nip01_event.Event,
    required_bits: u16,
) PowVerifiedIdError!bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.id.len == 32);

    if (!event_shape_is_valid_for_id_verify(event)) {
        return error.InvalidId;
    }

    nip01_event.event_verify_id(event) catch {
        return error.InvalidId;
    };

    return pow_meets_difficulty(event, required_bits);
}

fn parse_nonce_counter(counter_text: []const u8) PowError!void {
    std.debug.assert(counter_text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u64) == 8);

    if (counter_text.len > std.math.maxInt(u16)) {
        return error.InvalidNonceCounter;
    }
    if (counter_text.len == 0) {
        return error.InvalidNonceCounter;
    }
    _ = std.fmt.parseUnsigned(u64, counter_text, 10) catch {
        return error.InvalidNonceCounter;
    };
}

fn parse_nonce_target(target_text: []const u8) PowError!u16 {
    std.debug.assert(target_text.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u16) == 2);

    if (target_text.len > std.math.maxInt(u16)) {
        return error.InvalidNonceCommitment;
    }
    if (target_text.len == 0) {
        return error.InvalidNonceCommitment;
    }
    const target = std.fmt.parseUnsigned(u16, target_text, 10) catch {
        return error.InvalidNonceCommitment;
    };
    if (target > 256) {
        return error.InvalidNonceCommitment;
    }
    return target;
}

fn event_has_nonce_tag(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.id.len == 32);

    var tag_index: usize = 0;
    while (tag_index < event.tags.len) : (tag_index += 1) {
        const tag = event.tags[tag_index];
        if (tag.items.len == 0) {
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "nonce")) {
            return true;
        }
    }
    return false;
}

fn event_shape_is_valid_for_id_verify(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(limits.tags_max > 0);

    if (event.content.len > limits.content_bytes_max) {
        return false;
    }
    if (event.tags.len > limits.tags_max) {
        return false;
    }

    var tag_index: usize = 0;
    while (tag_index < event.tags.len) : (tag_index += 1) {
        const tag = event.tags[tag_index];
        if (tag.items.len > limits.tag_items_max) {
            return false;
        }

        var item_index: usize = 0;
        while (item_index < tag.items.len) : (item_index += 1) {
            const tag_item = tag.items[item_index];
            if (tag_item.len > limits.tag_item_bytes_max) {
                return false;
            }
        }
    }

    return true;
}

fn test_event(id: [32]u8, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= std.math.maxInt(u16));
    std.debug.assert(id.len == 32);

    return .{
        .id = id,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "",
        .tags = tags,
    };
}

test "pow leading zero vectors cover deterministic boundaries" {
    const id_all_zero = [_]u8{0} ** 32;
    const id_first_one = [_]u8{0x80} ++ ([_]u8{0} ** 31);
    const id_nibble = [_]u8{ 0x0f, 0xaa } ++ ([_]u8{0} ** 30);
    const id_twelve = [_]u8{ 0x00, 0x0f } ++ ([_]u8{0} ** 30);
    const id_one = [_]u8{ 0x7f, 0xff } ++ ([_]u8{0} ** 30);

    try std.testing.expectEqual(@as(u16, 256), pow_leading_zero_bits(&id_all_zero));
    try std.testing.expectEqual(@as(u16, 0), pow_leading_zero_bits(&id_first_one));
    try std.testing.expectEqual(@as(u16, 4), pow_leading_zero_bits(&id_nibble));
    try std.testing.expectEqual(@as(u16, 12), pow_leading_zero_bits(&id_twelve));
    try std.testing.expectEqual(@as(u16, 1), pow_leading_zero_bits(&id_one));
}

test "pow extracts valid nonce targets for 2 and 3 item nonce shapes" {
    const nonce_two_items = [_][]const u8{ "nonce", "44" };
    const nonce_three_items = [_][]const u8{ "nonce", "45", "20" };
    const topic_items = [_][]const u8{ "subject", "pow" };

    const tags_two = [_]nip01_event.EventTag{
        .{ .items = nonce_two_items[0..] },
        .{ .items = topic_items[0..] },
    };
    const tags_three = [_]nip01_event.EventTag{
        .{ .items = topic_items[0..] },
        .{ .items = nonce_three_items[0..] },
    };

    const id = [_]u8{0} ** 32;
    const event_two = test_event(id, tags_two[0..]);
    const event_three = test_event(id, tags_three[0..]);

    const target_two = try pow_extract_nonce_target(&event_two);
    const target_three = try pow_extract_nonce_target(&event_three);
    try std.testing.expect(target_two == null);
    try std.testing.expectEqual(@as(u16, 20), target_three.?);
}

test "pow meets difficulty valid vectors include required bits 0 and 256" {
    const nonce_two_items = [_][]const u8{ "nonce", "101" };
    const nonce_three_items = [_][]const u8{ "nonce", "102", "256" };
    const nonce_two_tags = [_]nip01_event.EventTag{.{ .items = nonce_two_items[0..] }};
    const nonce_three_tags = [_]nip01_event.EventTag{.{ .items = nonce_three_items[0..] }};

    const id_twelve = [_]u8{ 0x00, 0x0f } ++ ([_]u8{0} ** 30);
    const id_all_zero = [_]u8{0} ** 32;
    const id_no_zeros = [_]u8{0xff} ++ ([_]u8{0} ** 31);

    const event_twelve = test_event(id_twelve, nonce_two_tags[0..]);
    const event_all_zero = test_event(id_all_zero, nonce_three_tags[0..]);
    const event_no_zeros = test_event(id_no_zeros, nonce_two_tags[0..]);

    try std.testing.expect(try pow_meets_difficulty(&event_twelve, 12));
    try std.testing.expect(!(try pow_meets_difficulty(&event_twelve, 13)));
    try std.testing.expect(try pow_meets_difficulty(&event_twelve, 0));
    try std.testing.expect(try pow_meets_difficulty(&event_all_zero, 256));
    try std.testing.expect(!(try pow_meets_difficulty(&event_no_zeros, 1)));
}

test "pow returns false when nonce tag is absent" {
    const subject_items = [_][]const u8{ "subject", "no-nonce" };
    const tags = [_]nip01_event.EventTag{.{ .items = subject_items[0..] }};
    const event = test_event([_]u8{0} ** 32, tags[0..]);

    try std.testing.expect((try pow_extract_nonce_target(&event)) == null);
    try std.testing.expect(!(try pow_meets_difficulty(&event, 0)));
}

test "pow forcing errors covers all PowError variants" {
    const nonce_bad_arity = [_][]const u8{"nonce"};
    const nonce_bad_counter = [_][]const u8{ "nonce", "abc" };
    const nonce_bad_target = [_][]const u8{ "nonce", "1", "abc" };
    const nonce_target_out = [_][]const u8{ "nonce", "1", "257" };
    const nonce_valid = [_][]const u8{ "nonce", "1", "12" };

    const tags_bad_arity = [_]nip01_event.EventTag{.{ .items = nonce_bad_arity[0..] }};
    const tags_bad_counter = [_]nip01_event.EventTag{.{ .items = nonce_bad_counter[0..] }};
    const tags_bad_target = [_]nip01_event.EventTag{.{ .items = nonce_bad_target[0..] }};
    const tags_target_out = [_]nip01_event.EventTag{.{ .items = nonce_target_out[0..] }};
    const tags_valid = [_]nip01_event.EventTag{.{ .items = nonce_valid[0..] }};

    const id = [_]u8{0} ** 32;

    try std.testing.expectError(
        error.InvalidNonceTag,
        pow_extract_nonce_target(&test_event(id, tags_bad_arity[0..])),
    );
    try std.testing.expectError(
        error.InvalidNonceCounter,
        pow_extract_nonce_target(&test_event(id, tags_bad_counter[0..])),
    );
    try std.testing.expectError(
        error.InvalidNonceCommitment,
        pow_extract_nonce_target(&test_event(id, tags_bad_target[0..])),
    );
    try std.testing.expectError(
        error.InvalidNonceCommitment,
        pow_extract_nonce_target(&test_event(id, tags_target_out[0..])),
    );
    try std.testing.expectError(
        error.DifficultyOutOfRange,
        pow_meets_difficulty(&test_event(id, tags_valid[0..]), 257),
    );
}

test "pow invalid nonce arity over 3 is rejected" {
    const nonce_four_items = [_][]const u8{ "nonce", "1", "20", "extra" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_four_items[0..] }};
    const event = test_event([_]u8{0} ** 32, tags[0..]);

    try std.testing.expectError(error.InvalidNonceTag, pow_extract_nonce_target(&event));
    try std.testing.expectError(error.InvalidNonceTag, pow_meets_difficulty(&event, 10));
}

test "pow duplicate nonce tags are rejected as malformed shape" {
    const nonce_a = [_][]const u8{ "nonce", "1" };
    const nonce_b = [_][]const u8{ "nonce", "2", "20" };
    const tags = [_]nip01_event.EventTag{
        .{ .items = nonce_a[0..] },
        .{ .items = nonce_b[0..] },
    };
    const event = test_event([_]u8{0} ** 32, tags[0..]);

    try std.testing.expectError(error.InvalidNonceTag, pow_extract_nonce_target(&event));
    try std.testing.expectError(error.InvalidNonceTag, pow_meets_difficulty(&event, 1));
}

test "pow rejects nonce commitment below required threshold" {
    const nonce_items = [_][]const u8{ "nonce", "1", "11" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_items[0..] }};
    const id_twelve = [_]u8{ 0x00, 0x0f } ++ ([_]u8{0} ** 30);
    const event = test_event(id_twelve, tags[0..]);

    try std.testing.expectError(error.InvalidNonceCommitment, pow_meets_difficulty(&event, 12));
}

test "pow rejects nonce commitment overstating actual leading-zero bits" {
    const nonce_items = [_][]const u8{ "nonce", "1", "13" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_items[0..] }};
    const id_twelve = [_]u8{ 0x00, 0x0f } ++ ([_]u8{0} ** 30);
    const event = test_event(id_twelve, tags[0..]);

    try std.testing.expectError(error.InvalidNonceCommitment, pow_meets_difficulty(&event, 12));
}

test "pow accepts nonce commitment satisfied by actual leading-zero bits" {
    const nonce_items = [_][]const u8{ "nonce", "1", "12" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_items[0..] }};
    const id_twelve = [_]u8{ 0x00, 0x0f } ++ ([_]u8{0} ** 30);
    const event = test_event(id_twelve, tags[0..]);

    try std.testing.expect(try pow_meets_difficulty(&event, 12));
}

test "pow verified-id wrapper accepts valid id path" {
    const nonce_items = [_][]const u8{ "nonce", "200" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_items[0..] }};

    var event = test_event([_]u8{0} ** 32, tags[0..]);
    event.id = try nip01_event.event_compute_id(&event);

    try std.testing.expect(try pow_meets_difficulty_verified_id(&event, 0));
}

test "pow verified-id wrapper rejects invalid event id before pow check" {
    const nonce_items = [_][]const u8{ "nonce", "201" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_items[0..] }};

    var event = test_event([_]u8{0} ** 32, tags[0..]);
    event.id = try nip01_event.event_compute_id(&event);
    event.id[0] ^= 0x01;

    try std.testing.expectError(error.InvalidId, pow_meets_difficulty_verified_id(&event, 0));
}

test "pow unchecked helper can accept forged id while verified wrapper rejects" {
    const nonce_items = [_][]const u8{ "nonce", "300" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_items[0..] }};

    var event = test_event([_]u8{0} ** 32, tags[0..]);
    event.id = try nip01_event.event_compute_id(&event);
    try std.testing.expect(try pow_meets_difficulty_verified_id(&event, 0));

    event.id = [_]u8{0} ** 32;

    try std.testing.expect(try pow_meets_difficulty(&event, 8));
    try std.testing.expectError(error.InvalidId, pow_meets_difficulty_verified_id(&event, 8));
}

test "pow verified-id wrapper preserves existing pow errors" {
    const nonce_bad_counter = [_][]const u8{ "nonce", "not-a-number" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_bad_counter[0..] }};

    var event = test_event([_]u8{0} ** 32, tags[0..]);
    event.id = try nip01_event.event_compute_id(&event);

    try std.testing.expectError(
        error.InvalidNonceCounter,
        pow_meets_difficulty_verified_id(&event, 1),
    );
}

test "pow oversized nonce counter and target lengths return typed errors" {
    const one_digit = [_]u8{'1'};
    const oversized_text_ptr: [*]const u8 = @ptrCast(one_digit[0..].ptr);
    const oversized_text = oversized_text_ptr[0 .. @as(usize, std.math.maxInt(u16)) + 1];

    const nonce_counter_oversized = [_][]const u8{ "nonce", oversized_text };
    const nonce_target_oversized = [_][]const u8{ "nonce", "1", oversized_text };

    const tags_counter = [_]nip01_event.EventTag{.{ .items = nonce_counter_oversized[0..] }};
    const tags_target = [_]nip01_event.EventTag{.{ .items = nonce_target_oversized[0..] }};

    const event_counter = test_event([_]u8{0} ** 32, tags_counter[0..]);
    const event_target = test_event([_]u8{0} ** 32, tags_target[0..]);

    try std.testing.expectError(
        error.InvalidNonceCounter,
        pow_extract_nonce_target(&event_counter),
    );
    try std.testing.expectError(
        error.InvalidNonceCommitment,
        pow_extract_nonce_target(&event_target),
    );
}

test "pow verified-id wrapper preflight rejects malformed in-memory event shape" {
    const nonce_items = [_][]const u8{ "nonce", "9" };
    const tags = [_]nip01_event.EventTag{.{ .items = nonce_items[0..] }};

    var oversized_content_bytes = [_]u8{'x'} ** (limits.content_bytes_max + 1);
    var event_bad_content = test_event([_]u8{0} ** 32, tags[0..]);
    event_bad_content.content = oversized_content_bytes[0..];

    try std.testing.expectError(
        error.InvalidId,
        pow_meets_difficulty_verified_id(&event_bad_content, 0),
    );

    const oversized_tags_ptr: [*]const nip01_event.EventTag = @ptrCast(tags[0..].ptr);
    const oversized_tags = oversized_tags_ptr[0 .. @as(usize, limits.tags_max) + 1];
    const event_bad_tags = test_event([_]u8{0} ** 32, oversized_tags);

    try std.testing.expectError(
        error.InvalidId,
        pow_meets_difficulty_verified_id(&event_bad_tags, 0),
    );

    const one_byte = [_]u8{'x'};
    const oversized_tag_item_ptr: [*]const u8 = @ptrCast(one_byte[0..].ptr);
    const oversized_tag_item =
        oversized_tag_item_ptr[0 .. @as(usize, limits.tag_item_bytes_max) + 1];
    const nonce_oversized_item = [_][]const u8{ "nonce", oversized_tag_item };
    const oversized_item_tags = [_]nip01_event.EventTag{.{ .items = nonce_oversized_item[0..] }};
    const event_bad_tag_item = test_event([_]u8{0} ** 32, oversized_item_tags[0..]);

    try std.testing.expectError(
        error.InvalidId,
        pow_meets_difficulty_verified_id(&event_bad_tag_item, 0),
    );
}
