const std = @import("std");
const nip01_event = @import("nip01_event.zig");

/// Typed failures for strict NIP-13 PoW parsing and validation.
pub const PowError = error{
    DifficultyOutOfRange,
    InvalidNonceTag,
    InvalidNonceCounter,
    InvalidNonceCommitment,
};

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
    std.debug.assert(event.tags.len <= std.math.maxInt(u16));

    var found_nonce = false;
    var nonce_target: ?u16 = null;
    var tag_index: u16 = 0;
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

/// Validates nonce-tag shape and compares event id difficulty against the required threshold.
pub fn pow_meets_difficulty(event: *const nip01_event.Event, required_bits: u16) PowError!bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(required_bits <= std.math.maxInt(u16));

    if (required_bits > 256) {
        return error.DifficultyOutOfRange;
    }

    _ = try pow_extract_nonce_target(event);
    if (!event_has_nonce_tag(event)) {
        return false;
    }

    const leading_zero_bits = pow_leading_zero_bits(&event.id);
    return leading_zero_bits >= required_bits;
}

fn parse_nonce_counter(counter_text: []const u8) PowError!void {
    std.debug.assert(counter_text.len <= std.math.maxInt(u16));
    std.debug.assert(@sizeOf(u64) == 8);

    if (counter_text.len == 0) {
        return error.InvalidNonceCounter;
    }
    _ = std.fmt.parseUnsigned(u64, counter_text, 10) catch {
        return error.InvalidNonceCounter;
    };
}

fn parse_nonce_target(target_text: []const u8) PowError!u16 {
    std.debug.assert(target_text.len <= std.math.maxInt(u16));
    std.debug.assert(@sizeOf(u16) == 2);

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
    std.debug.assert(event.tags.len <= std.math.maxInt(u16));

    var tag_index: u16 = 0;
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
