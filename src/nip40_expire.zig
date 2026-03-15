const std = @import("std");
const nip01_event = @import("nip01_event.zig");

pub const ExpirationError = error{InvalidExpirationTag};

pub fn event_expiration_unix_seconds(event: *const nip01_event.Event) ExpirationError!?u64 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= std.math.maxInt(usize));

    var parsed_expiration: ?u64 = null;
    var index: usize = 0;
    while (index < event.tags.len) : (index += 1) {
        const value = try parse_expiration_tag_value(event.tags[index]);
        if (value == null) {
            continue;
        }
        parsed_expiration = value;
        break;
    }

    return parsed_expiration;
}

pub fn event_is_expired_at(
    event: *const nip01_event.Event,
    now_unix_seconds: u64,
) ExpirationError!bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(now_unix_seconds <= std.math.maxInt(u64));

    const expiration = try event_expiration_unix_seconds(event);
    if (expiration == null) {
        return false;
    }

    return now_unix_seconds > expiration.?;
}

fn parse_expiration_tag_value(tag: nip01_event.EventTag) ExpirationError!?u64 {
    std.debug.assert(tag.items.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u64) == 8);

    if (tag.items.len > std.math.maxInt(u16)) {
        return error.InvalidExpirationTag;
    }

    if (tag.items.len == 0) {
        return null;
    }
    if (!std.mem.eql(u8, tag.items[0], "expiration")) {
        return null;
    }
    if (tag.items.len < 2) {
        return null;
    }
    if (tag.items[1].len == 0) {
        return null;
    }

    const parsed = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch return null;
    return parsed;
}

fn event_for_tags(tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= std.math.maxInt(u16));
    std.debug.assert(tags.len >= 0);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{1} ** 32,
        .sig = [_]u8{2} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "x",
        .tags = tags,
    };
}

test "expiration vectors valid include boundary and deterministic no-expiration" {
    const no_tags = [_]nip01_event.EventTag{};
    const non_exp_items = [_][]const u8{ "p", "abcdef" };
    const non_exp_tags = [_]nip01_event.EventTag{.{ .items = non_exp_items[0..] }};
    const future_items = [_][]const u8{ "expiration", "1700000005" };
    const future_tags = [_]nip01_event.EventTag{.{ .items = future_items[0..] }};
    const same_a = [_][]const u8{ "expiration", "1700000010" };
    const same_b = [_][]const u8{ "expiration", "1700000010" };
    const duplicate_same_tags = [_]nip01_event.EventTag{
        .{ .items = same_a[0..] },
        .{ .items = same_b[0..] },
    };

    const no_expiration = try event_expiration_unix_seconds(&event_for_tags(no_tags[0..]));
    try std.testing.expect(no_expiration == null);
    try std.testing.expect(
        !(try event_is_expired_at(&event_for_tags(no_tags[0..]), 42)),
    );
    try std.testing.expect(!(try event_is_expired_at(&event_for_tags(no_tags[0..]), 42)));

    try std.testing.expect(
        (try event_expiration_unix_seconds(&event_for_tags(non_exp_tags[0..]))) == null,
    );
    try std.testing.expect(
        !(try event_is_expired_at(&event_for_tags(non_exp_tags[0..]), 999)),
    );
    try std.testing.expectEqual(
        @as(?u64, 1_700_000_005),
        try event_expiration_unix_seconds(&event_for_tags(future_tags[0..])),
    );
    try std.testing.expect(
        !(try event_is_expired_at(&event_for_tags(future_tags[0..]), 1_700_000_004)),
    );
    try std.testing.expect(
        !(try event_is_expired_at(&event_for_tags(future_tags[0..]), 1_700_000_005)),
    );
    try std.testing.expect(
        try event_is_expired_at(&event_for_tags(future_tags[0..]), 1_700_000_006),
    );
    try std.testing.expectEqual(
        @as(?u64, 1_700_000_010),
        try event_expiration_unix_seconds(&event_for_tags(duplicate_same_tags[0..])),
    );
}

test "expiration vectors invalid include malformed timestamp and empty value" {
    const arity_one = [_][]const u8{"expiration"};
    const arity_three = [_][]const u8{ "expiration", "5", "extra" };
    const empty_value = [_][]const u8{ "expiration", "" };
    const negative_value = [_][]const u8{ "expiration", "-1" };
    const alpha_value = [_][]const u8{ "expiration", "10x" };
    const overflow_value = [_][]const u8{ "expiration", "18446744073709551616" };
    const dup_a = [_][]const u8{ "expiration", "100" };
    const dup_b = [_][]const u8{ "expiration", "101" };

    const tags_arity_one = [_]nip01_event.EventTag{.{ .items = arity_one[0..] }};
    const tags_arity_three = [_]nip01_event.EventTag{.{ .items = arity_three[0..] }};
    const tags_empty_value = [_]nip01_event.EventTag{.{ .items = empty_value[0..] }};
    const tags_negative_value = [_]nip01_event.EventTag{.{ .items = negative_value[0..] }};
    const tags_alpha_value = [_]nip01_event.EventTag{.{ .items = alpha_value[0..] }};
    const tags_overflow_value = [_]nip01_event.EventTag{.{ .items = overflow_value[0..] }};
    const tags_dup_conflict = [_]nip01_event.EventTag{
        .{ .items = dup_a[0..] },
        .{ .items = dup_b[0..] },
    };

    try std.testing.expect(
        (try event_expiration_unix_seconds(&event_for_tags(tags_arity_one[0..]))) == null,
    );
    try std.testing.expectEqual(
        @as(?u64, 5),
        try event_expiration_unix_seconds(&event_for_tags(tags_arity_three[0..])),
    );
    try std.testing.expect(
        (try event_expiration_unix_seconds(&event_for_tags(tags_empty_value[0..]))) == null,
    );
    try std.testing.expect(
        (try event_expiration_unix_seconds(&event_for_tags(tags_negative_value[0..]))) == null,
    );
    try std.testing.expect(
        (try event_expiration_unix_seconds(&event_for_tags(tags_alpha_value[0..]))) == null,
    );
    try std.testing.expect(
        (try event_expiration_unix_seconds(&event_for_tags(tags_overflow_value[0..]))) == null,
    );
    try std.testing.expectEqual(
        @as(?u64, 100),
        try event_expiration_unix_seconds(&event_for_tags(tags_dup_conflict[0..])),
    );
}

test "expiration tag extra slots are ignored after the timestamp" {
    const bad_shape = [_][]const u8{ "expiration", "3", "extra" };
    const bad_tags = [_]nip01_event.EventTag{.{ .items = bad_shape[0..] }};

    try std.testing.expect(try event_is_expired_at(&event_for_tags(bad_tags[0..]), 4));
}

test "expiration malformed timestamps are ignored deterministically" {
    const bad_value = [_][]const u8{ "expiration", "not-a-u64" };
    const bad_tags = [_]nip01_event.EventTag{.{ .items = bad_value[0..] }};

    try std.testing.expect(!(try event_is_expired_at(&event_for_tags(bad_tags[0..]), 4)));
}

test "expiration conflicting duplicates use the first valid tag deterministically" {
    const first = [_][]const u8{ "expiration", "100" };
    const second = [_][]const u8{ "expiration", "200" };
    const tags = [_]nip01_event.EventTag{
        .{ .items = first[0..] },
        .{ .items = second[0..] },
    };

    try std.testing.expectEqual(
        @as(?u64, 100),
        try event_expiration_unix_seconds(&event_for_tags(tags[0..])),
    );
    try std.testing.expect(!(try event_is_expired_at(&event_for_tags(tags[0..]), 100)));
    try std.testing.expect(try event_is_expired_at(&event_for_tags(tags[0..]), 101));
}

test "expiration oversized item count returns InvalidExpirationTag" {
    const placeholder_items = [_][]const u8{"expiration"};
    const oversized_items_ptr: [*]const []const u8 = @ptrCast(placeholder_items[0..].ptr);
    const oversized_items = oversized_items_ptr[0 .. @as(usize, std.math.maxInt(u16)) + 1];

    const tags = [_]nip01_event.EventTag{.{ .items = oversized_items }};
    const event = event_for_tags(tags[0..]);

    try std.testing.expectError(error.InvalidExpirationTag, event_expiration_unix_seconds(&event));
}
