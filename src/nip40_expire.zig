const std = @import("std");
const nip01_event = @import("nip01_event.zig");

pub const ExpirationError = error{ InvalidExpirationTag, InvalidTimestamp };

pub fn event_expiration_unix_seconds(event: *const nip01_event.Event) ExpirationError!?u64 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= std.math.maxInt(u16));

    var parsed_expiration: ?u64 = null;
    var index: u16 = 0;
    while (index < event.tags.len) : (index += 1) {
        const value = try parse_expiration_tag_value(event.tags[index]);
        if (value == null) {
            continue;
        }

        if (parsed_expiration == null) {
            parsed_expiration = value;
        } else {
            if (parsed_expiration.? != value.?) {
                return error.InvalidExpirationTag;
            }
        }
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
    std.debug.assert(tag.items.len <= std.math.maxInt(u16));
    std.debug.assert(@sizeOf(u64) == 8);

    if (tag.items.len == 0) {
        return null;
    }
    if (!std.mem.eql(u8, tag.items[0], "expiration")) {
        return null;
    }
    if (tag.items.len != 2) {
        return error.InvalidExpirationTag;
    }
    if (tag.items[1].len == 0) {
        return error.InvalidTimestamp;
    }

    const parsed = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch {
        return error.InvalidTimestamp;
    };
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

test "expiration vectors invalid include malformed shape and malformed timestamp" {
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

    try std.testing.expectError(
        error.InvalidExpirationTag,
        event_expiration_unix_seconds(&event_for_tags(tags_arity_one[0..])),
    );
    try std.testing.expectError(
        error.InvalidExpirationTag,
        event_expiration_unix_seconds(&event_for_tags(tags_arity_three[0..])),
    );
    try std.testing.expectError(
        error.InvalidTimestamp,
        event_expiration_unix_seconds(&event_for_tags(tags_empty_value[0..])),
    );
    try std.testing.expectError(
        error.InvalidTimestamp,
        event_expiration_unix_seconds(&event_for_tags(tags_negative_value[0..])),
    );
    try std.testing.expectError(
        error.InvalidTimestamp,
        event_expiration_unix_seconds(&event_for_tags(tags_alpha_value[0..])),
    );
    try std.testing.expectError(
        error.InvalidTimestamp,
        event_expiration_unix_seconds(&event_for_tags(tags_overflow_value[0..])),
    );
    try std.testing.expectError(
        error.InvalidExpirationTag,
        event_expiration_unix_seconds(&event_for_tags(tags_dup_conflict[0..])),
    );
}

test "expiration forcing test for InvalidExpirationTag" {
    const bad_shape = [_][]const u8{ "expiration", "3", "extra" };
    const bad_tags = [_]nip01_event.EventTag{.{ .items = bad_shape[0..] }};

    try std.testing.expectError(
        error.InvalidExpirationTag,
        event_is_expired_at(&event_for_tags(bad_tags[0..]), 4),
    );
}

test "expiration forcing test for InvalidTimestamp" {
    const bad_value = [_][]const u8{ "expiration", "not-a-u64" };
    const bad_tags = [_]nip01_event.EventTag{.{ .items = bad_value[0..] }};

    try std.testing.expectError(
        error.InvalidTimestamp,
        event_is_expired_at(&event_for_tags(bad_tags[0..]), 4),
    );
}
