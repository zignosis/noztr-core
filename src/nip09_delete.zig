const std = @import("std");
const nip01_event = @import("nip01_event.zig");
const limits = @import("limits.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const delete_event_kind: u32 = 5;

pub const DeleteError = error{
    InvalidDeleteEventKind,
    EmptyDeleteTargets,
    InvalidETag,
    InvalidATag,
    InvalidAddressCoordinate,
    CrossAuthorDelete,
};

pub const DeleteExtractError = error{
    BufferTooSmall,
    EmptyDeleteTargets,
    InvalidETag,
    InvalidATag,
    InvalidAddressCoordinate,
};

pub const DeleteExtractCheckedError = DeleteExtractError || error{InvalidDeleteEventKind};

const DeleteTargetParseError = error{
    InvalidETag,
    InvalidATag,
    InvalidAddressCoordinate,
};

pub const DeleteAddressCoordinate = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
};

pub const DeleteTarget = union(enum) {
    e: [32]u8,
    a: DeleteAddressCoordinate,
};

/// Extracts `e` and `a` deletion targets from a kind-5 delete event.
pub fn delete_extract_targets(
    delete_event: *const nip01_event.Event,
    out: []DeleteTarget,
) DeleteExtractError!u16 {
    std.debug.assert(@intFromPtr(delete_event) != 0);
    std.debug.assert(out.len <= std.math.maxInt(u16));

    var count: u16 = 0;
    var index: usize = 0;
    while (index < delete_event.tags.len) : (index += 1) {
        const tag = delete_event.tags[index];
        const maybe_target = try parse_delete_tag_to_target(tag);
        if (maybe_target == null) {
            continue;
        }
        if (count == out.len) {
            return error.BufferTooSmall;
        }

        out[count] = maybe_target.?;
        count += 1;
    }

    if (count == 0) {
        return error.EmptyDeleteTargets;
    }
    return count;
}

/// Validates kind-5 and then extracts `e` and `a` deletion targets.
pub fn delete_extract_targets_checked(
    delete_event: *const nip01_event.Event,
    out: []DeleteTarget,
) DeleteExtractCheckedError!u16 {
    std.debug.assert(@intFromPtr(delete_event) != 0);
    std.debug.assert(out.len <= std.math.maxInt(u16));

    try validate_delete_kind(delete_event);
    return delete_extract_targets(delete_event, out);
}

/// Returns whether a validated kind-5 delete can apply to `target_event`.
pub fn deletion_can_apply(
    delete_event: *const nip01_event.Event,
    target_event: *const nip01_event.Event,
) DeleteError!bool {
    std.debug.assert(@intFromPtr(delete_event) != 0);
    std.debug.assert(@intFromPtr(target_event) != 0);

    try validate_delete_kind(delete_event);
    if (!std.mem.eql(u8, &delete_event.pubkey, &target_event.pubkey)) {
        return error.CrossAuthorDelete;
    }

    var has_targets = false;
    var index: usize = 0;
    while (index < delete_event.tags.len) : (index += 1) {
        const tag = delete_event.tags[index];
        const maybe_target = try parse_delete_tag_to_target(tag);
        if (maybe_target == null) {
            continue;
        }

        has_targets = true;
        if (target_event.kind == delete_event_kind) {
            continue;
        }
        if (delete_target_matches_event(maybe_target.?, delete_event.created_at, target_event)) {
            return true;
        }
    }

    if (!has_targets) {
        return error.EmptyDeleteTargets;
    }
    return false;
}

fn validate_delete_kind(delete_event: *const nip01_event.Event) error{InvalidDeleteEventKind}!void {
    std.debug.assert(delete_event.kind <= std.math.maxInt(u32));
    std.debug.assert(delete_event.created_at <= std.math.maxInt(u64));

    if (delete_event.kind != delete_event_kind) {
        return error.InvalidDeleteEventKind;
    }
}

fn parse_delete_tag_to_target(tag: nip01_event.EventTag) DeleteTargetParseError!?DeleteTarget {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.id_hex_length == 64);

    if (tag.items.len == 0) {
        return null;
    }

    const tag_name = tag.items[0];
    if (std.mem.eql(u8, tag_name, "e")) {
        return .{ .e = try parse_e_tag_value(tag) };
    }
    if (std.mem.eql(u8, tag_name, "a")) {
        return .{ .a = try parse_a_tag_value(tag) };
    }
    return null;
}

fn parse_e_tag_value(tag: nip01_event.EventTag) DeleteTargetParseError![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.id_hex_length == 64);

    if (tag.items.len < 2) {
        return error.InvalidETag;
    }
    return parse_lower_hex_32(tag.items[1]) catch {
        return error.InvalidETag;
    };
}

fn parse_a_tag_value(tag: nip01_event.EventTag) DeleteTargetParseError!DeleteAddressCoordinate {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (tag.items.len < 2) {
        return error.InvalidATag;
    }

    return parse_address_coordinate(tag.items[1]) catch {
        return error.InvalidAddressCoordinate;
    };
}

fn parse_address_coordinate(
    text: []const u8,
) error{InvalidAddressCoordinate}!DeleteAddressCoordinate {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse {
        return error.InvalidAddressCoordinate;
    };
    if (first_colon == 0) {
        return error.InvalidAddressCoordinate;
    }

    const second_search = text[first_colon + 1 ..];
    const second_colon_rel = std.mem.indexOfScalar(u8, second_search, ':') orelse {
        return error.InvalidAddressCoordinate;
    };
    const second_colon = first_colon + 1 + second_colon_rel;
    if (second_colon == first_colon + 1) {
        return error.InvalidAddressCoordinate;
    }

    const kind_text = text[0..first_colon];
    const pubkey_text = text[first_colon + 1 .. second_colon];
    const identifier = text[second_colon + 1 ..];
    const kind = std.fmt.parseUnsigned(u32, kind_text, 10) catch {
        return error.InvalidAddressCoordinate;
    };

    var pubkey: [32]u8 = undefined;
    parse_lower_hex_into_32(pubkey_text, &pubkey) catch {
        return error.InvalidAddressCoordinate;
    };
    try validate_coordinate_kind(kind, identifier);
    return .{ .kind = kind, .pubkey = pubkey, .identifier = identifier };
}

fn validate_coordinate_kind(
    kind: u32,
    identifier: []const u8,
) error{InvalidAddressCoordinate}!void {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    const is_replaceable = kind == 0 or kind == 3 or (kind >= 10_000 and kind < 20_000);
    const is_addressable = kind >= 30_000 and kind < 40_000;
    if (!is_replaceable and !is_addressable) {
        return error.InvalidAddressCoordinate;
    }
    if (is_replaceable and identifier.len != 0) {
        return error.InvalidAddressCoordinate;
    }
    if (is_addressable and identifier.len == 0) {
        return error.InvalidAddressCoordinate;
    }
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn parse_lower_hex_into_32(text: []const u8, output: *[32]u8) error{InvalidHex}!void {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@intFromPtr(output) != 0);

    output.* = try lower_hex_32.parse(text);
}

fn delete_target_matches_event(
    target: DeleteTarget,
    delete_created_at: u64,
    event: *const nip01_event.Event,
) bool {
    std.debug.assert(delete_created_at <= std.math.maxInt(u64));
    std.debug.assert(event.created_at <= std.math.maxInt(u64));

    return switch (target) {
        .e => |target_id| std.mem.eql(u8, &target_id, &event.id),
        .a => |coordinate| {
            if (delete_created_at < event.created_at) {
                return false;
            }
            return coordinate_matches_event(coordinate, event);
        },
    };
}

fn coordinate_matches_event(
    coordinate: DeleteAddressCoordinate,
    event: *const nip01_event.Event,
) bool {
    std.debug.assert(coordinate.kind <= std.math.maxInt(u32));
    std.debug.assert(event.kind <= std.math.maxInt(u32));

    if (coordinate.kind != event.kind) {
        return false;
    }
    if (!std.mem.eql(u8, &coordinate.pubkey, &event.pubkey)) {
        return false;
    }

    const d_value = find_unique_d_tag_value(event) orelse return false;
    if (!std.mem.eql(u8, coordinate.identifier, d_value)) {
        return false;
    }
    return true;
}

// Policy: coordinate matching rejects events that contain duplicate `d` tags.
// This keeps matching deterministic by requiring a single unambiguous identifier.
fn find_unique_d_tag_value(event: *const nip01_event.Event) ?[]const u8 {
    std.debug.assert(event.tags.len <= limits.tags_max);
    std.debug.assert(@intFromPtr(event) != 0);

    var found_d = false;
    var found_value: []const u8 = undefined;
    var index: usize = 0;
    while (index < event.tags.len) : (index += 1) {
        const tag = event.tags[index];
        if (tag.items.len < 2) {
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "d")) {
            if (found_d) {
                return null;
            }
            found_d = true;
            found_value = tag.items[1];
        }
    }
    if (found_d) {
        return found_value;
    }
    return null;
}

fn test_event(
    kind: u32,
    pubkey: [32]u8,
    created_at: u64,
    id: [32]u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(created_at <= std.math.maxInt(u64));

    return .{
        .id = id,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = created_at,
        .content = "",
        .tags = tags,
    };
}

fn hex32(text: []const u8) [32]u8 {
    std.debug.assert(text.len == limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    var value: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&value, text) catch unreachable;
    return value;
}

test "delete_extract_targets valid vectors and deterministic order" {
    const e_id_hex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const e_id = hex32(e_id_hex);
    const pubkey_a = [_]u8{0xaa} ** 32;
    const a_tag_value = "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:" ++
        "profile-1";

    const e_items = [_][]const u8{ "e", e_id_hex };
    const a_items = [_][]const u8{ "a", a_tag_value };
    const p_items = [_][]const u8{ "p", "ignore-me" };
    const e_items_second = [_][]const u8{
        "e",
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = p_items[0..] },
        .{ .items = e_items[0..] },
        .{ .items = a_items[0..] },
        .{ .items = e_items_second[0..] },
    };

    const delete_event = test_event(delete_event_kind, pubkey_a, 500, [_]u8{0} ** 32, tags[0..]);
    var out: [3]DeleteTarget = undefined;
    const count = try delete_extract_targets(&delete_event, out[0..]);

    try std.testing.expectEqual(@as(u16, 3), count);
    try std.testing.expectEqual(e_id, out[0].e);
    try std.testing.expectEqual(@as(u32, 30023), out[1].a.kind);
    try std.testing.expectEqual(pubkey_a, out[1].a.pubkey);
    try std.testing.expectEqualStrings("profile-1", out[1].a.identifier);
    try std.testing.expectEqual(
        hex32("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"),
        out[2].e,
    );
}

test "delete_extract_targets_checked kind-5 parity with extractor" {
    const pubkey = [_]u8{0xbb} ** 32;
    const e_one_hex = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const e_two_hex = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    const a_value = "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:" ++
        "channel";

    const e_one = [_][]const u8{ "e", e_one_hex };
    const p_ignored = [_][]const u8{ "p", "ignore" };
    const a_tag = [_][]const u8{ "a", a_value };
    const e_two = [_][]const u8{ "e", e_two_hex };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_one[0..] },
        .{ .items = p_ignored[0..] },
        .{ .items = a_tag[0..] },
        .{ .items = e_two[0..] },
    };

    const delete_event = test_event(delete_event_kind, pubkey, 100, [_]u8{0} ** 32, tags[0..]);
    var out_existing: [3]DeleteTarget = undefined;
    var out_checked: [3]DeleteTarget = undefined;

    const count_existing = try delete_extract_targets(&delete_event, out_existing[0..]);
    const count_checked = try delete_extract_targets_checked(&delete_event, out_checked[0..]);

    try std.testing.expectEqual(count_existing, count_checked);
    try std.testing.expectEqual(@as(u16, 3), count_checked);
    var index: usize = 0;
    while (index < count_checked) : (index += 1) {
        try std.testing.expectEqual(out_existing[index], out_checked[index]);
    }
}

test "delete_extract_targets_checked non-kind-5 rejects" {
    const pubkey = [_]u8{0xcc} ** 32;
    const e_items = [_][]const u8{
        "e",
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = e_items[0..] }};
    const not_delete = test_event(1, pubkey, 100, [_]u8{0} ** 32, tags[0..]);

    var out: [1]DeleteTarget = undefined;
    try std.testing.expectError(
        error.InvalidDeleteEventKind,
        delete_extract_targets_checked(&not_delete, out[0..]),
    );
}

test "deletion_can_apply valid vectors include e and a and delete no-op" {
    const pubkey = [_]u8{0x11} ** 32;
    const target_id_hex =
        "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";
    const target_id = hex32(target_id_hex);

    const e_items = [_][]const u8{ "e", target_id_hex };
    const a_items = [_][]const u8{
        "a",
        "30023:1111111111111111111111111111111111111111111111111111111111111111:room",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_items[0..] },
        .{ .items = a_items[0..] },
    };
    const delete_event = test_event(delete_event_kind, pubkey, 1_000, [_]u8{9} ** 32, tags[0..]);

    const target_by_id = test_event(1, pubkey, 900, target_id, &[_]nip01_event.EventTag{});
    try std.testing.expect(try deletion_can_apply(&delete_event, &target_by_id));

    const target_by_id_newer = test_event(1, pubkey, 1_001, target_id, &[_]nip01_event.EventTag{});
    try std.testing.expect(try deletion_can_apply(&delete_event, &target_by_id_newer));

    const d_items = [_][]const u8{ "d", "room" };
    const target_addressed_tags = [_]nip01_event.EventTag{.{ .items = d_items[0..] }};
    const target_by_a = test_event(30023, pubkey, 900, [_]u8{7} ** 32, target_addressed_tags[0..]);
    try std.testing.expect(try deletion_can_apply(&delete_event, &target_by_a));

    const target_newer_by_a = test_event(
        30023,
        pubkey,
        1_001,
        [_]u8{8} ** 32,
        target_addressed_tags[0..],
    );
    try std.testing.expect(!(try deletion_can_apply(&delete_event, &target_newer_by_a)));

    const delete_target = test_event(
        delete_event_kind,
        pubkey,
        900,
        target_id,
        &[_]nip01_event.EventTag{},
    );
    try std.testing.expect(!(try deletion_can_apply(&delete_event, &delete_target)));

    const non_match_id = test_event(1, pubkey, 900, [_]u8{3} ** 32, &[_]nip01_event.EventTag{});
    try std.testing.expect(!(try deletion_can_apply(&delete_event, &non_match_id)));
}

test "delete invalid vectors cover empty targets and kind checks" {
    const pubkey = [_]u8{0x22} ** 32;

    const no_targets = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        &[_]nip01_event.EventTag{},
    );
    try std.testing.expectError(
        error.EmptyDeleteTargets,
        delete_extract_targets(&no_targets, &.{}),
    );
    try std.testing.expectError(
        error.EmptyDeleteTargets,
        deletion_can_apply(&no_targets, &no_targets),
    );

    const bad_kind = test_event(1, pubkey, 100, [_]u8{0} ** 32, &[_]nip01_event.EventTag{});
    var out_one: [1]DeleteTarget = undefined;
    try std.testing.expectError(
        error.EmptyDeleteTargets,
        delete_extract_targets(&bad_kind, out_one[0..]),
    );
    try std.testing.expectError(
        error.InvalidDeleteEventKind,
        deletion_can_apply(&bad_kind, &no_targets),
    );
}

test "delete invalid vectors cover malformed e and a tags" {
    const pubkey = [_]u8{0x22} ** 32;
    const no_targets = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        &[_]nip01_event.EventTag{},
    );
    var out_one: [1]DeleteTarget = undefined;

    const e_missing_items = [_][]const u8{"e"};
    const tags_bad_e = [_]nip01_event.EventTag{.{ .items = e_missing_items[0..] }};
    const bad_e_event = test_event(delete_event_kind, pubkey, 100, [_]u8{0} ** 32, tags_bad_e[0..]);
    try std.testing.expectError(
        error.InvalidETag,
        delete_extract_targets(&bad_e_event, out_one[0..]),
    );
    try std.testing.expectError(error.InvalidETag, deletion_can_apply(&bad_e_event, &no_targets));

    const e_bad_hex = [_][]const u8{ "e", "ABCDEF" };
    const tags_bad_e_hex = [_]nip01_event.EventTag{.{ .items = e_bad_hex[0..] }};
    const bad_e_hex_event = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        tags_bad_e_hex[0..],
    );
    try std.testing.expectError(
        error.InvalidETag,
        delete_extract_targets(&bad_e_hex_event, out_one[0..]),
    );

    const a_missing_items = [_][]const u8{"a"};
    const tags_bad_a = [_]nip01_event.EventTag{.{ .items = a_missing_items[0..] }};
    const bad_a_event = test_event(delete_event_kind, pubkey, 100, [_]u8{0} ** 32, tags_bad_a[0..]);
    try std.testing.expectError(
        error.InvalidATag,
        delete_extract_targets(&bad_a_event, out_one[0..]),
    );
    try std.testing.expectError(error.InvalidATag, deletion_can_apply(&bad_a_event, &no_targets));
}

test "delete invalid vectors cover invalid coordinate and cross-author" {
    const pubkey = [_]u8{0x22} ** 32;
    const other_pubkey = [_]u8{0x33} ** 32;
    const no_targets = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        &[_]nip01_event.EventTag{},
    );
    var out_one: [1]DeleteTarget = undefined;

    const a_bad_coord = [_][]const u8{ "a", "30023:nothex" };
    const tags_bad_coord = [_]nip01_event.EventTag{.{ .items = a_bad_coord[0..] }};
    const bad_coord_event = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        tags_bad_coord[0..],
    );
    try std.testing.expectError(
        error.InvalidAddressCoordinate,
        delete_extract_targets(&bad_coord_event, out_one[0..]),
    );
    try std.testing.expectError(
        error.InvalidAddressCoordinate,
        deletion_can_apply(&bad_coord_event, &no_targets),
    );

    const a_ephemeral = [_][]const u8{
        "a",
        "20500:2222222222222222222222222222222222222222222222222222222222222222:",
    };
    const tags_ephemeral = [_]nip01_event.EventTag{.{ .items = a_ephemeral[0..] }};
    const ephemeral_event = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        tags_ephemeral[0..],
    );
    try std.testing.expectError(
        error.InvalidAddressCoordinate,
        delete_extract_targets(&ephemeral_event, out_one[0..]),
    );

    const a_replaceable_with_identifier = [_][]const u8{
        "a",
        "10000:2222222222222222222222222222222222222222222222222222222222222222:room",
    };
    const tags_replaceable = [_]nip01_event.EventTag{
        .{ .items = a_replaceable_with_identifier[0..] },
    };
    const replaceable_event = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        tags_replaceable[0..],
    );
    try std.testing.expectError(
        error.InvalidAddressCoordinate,
        delete_extract_targets(&replaceable_event, out_one[0..]),
    );

    const a_addressable_without_identifier = [_][]const u8{
        "a",
        "30023:2222222222222222222222222222222222222222222222222222222222222222:",
    };
    const tags_addressable = [_]nip01_event.EventTag{
        .{ .items = a_addressable_without_identifier[0..] },
    };
    const addressable_event = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        tags_addressable[0..],
    );
    try std.testing.expectError(
        error.InvalidAddressCoordinate,
        delete_extract_targets(&addressable_event, out_one[0..]),
    );

    const valid_e = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const tags_valid_e = [_]nip01_event.EventTag{.{ .items = valid_e[0..] }};
    const delete_cross_author = test_event(
        delete_event_kind,
        pubkey,
        100,
        [_]u8{0} ** 32,
        tags_valid_e[0..],
    );
    const foreign_target = test_event(
        1,
        other_pubkey,
        90,
        [_]u8{1} ** 32,
        &[_]nip01_event.EventTag{},
    );
    try std.testing.expectError(
        error.CrossAuthorDelete,
        deletion_can_apply(&delete_cross_author, &foreign_target),
    );
}

test "delete extractor forces buffer too small" {
    const pubkey = [_]u8{0x44} ** 32;
    const e_first = [_][]const u8{
        "e",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const e_second = [_][]const u8{
        "e",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_first[0..] },
        .{ .items = e_second[0..] },
    };
    const delete_event = test_event(delete_event_kind, pubkey, 100, [_]u8{0} ** 32, tags[0..]);

    var out: [1]DeleteTarget = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        delete_extract_targets(&delete_event, out[0..]),
    );
}

test "deletion_can_apply coordinate path rejects duplicate d tags" {
    const pubkey = [_]u8{0x55} ** 32;
    const a_items = [_][]const u8{
        "a",
        "30023:5555555555555555555555555555555555555555555555555555555555555555:room",
    };
    const delete_tags = [_]nip01_event.EventTag{.{ .items = a_items[0..] }};
    const delete_event = test_event(delete_event_kind, pubkey, 100, [_]u8{0x10} ** 32, delete_tags[0..]);

    const d_first = [_][]const u8{ "d", "room" };
    const d_second = [_][]const u8{ "d", "room" };
    const target_tags = [_]nip01_event.EventTag{
        .{ .items = d_first[0..] },
        .{ .items = d_second[0..] },
    };
    const target_event = test_event(30023, pubkey, 90, [_]u8{0x20} ** 32, target_tags[0..]);

    try std.testing.expect(!(try deletion_can_apply(&delete_event, &target_event)));
}

test "deletion_can_apply coordinate path accepts single d tag" {
    const pubkey = [_]u8{0x66} ** 32;
    const a_items = [_][]const u8{
        "a",
        "30023:6666666666666666666666666666666666666666666666666666666666666666:room",
    };
    const delete_tags = [_]nip01_event.EventTag{.{ .items = a_items[0..] }};
    const delete_event = test_event(delete_event_kind, pubkey, 100, [_]u8{0x30} ** 32, delete_tags[0..]);

    const d_items = [_][]const u8{ "d", "room" };
    const target_tags = [_]nip01_event.EventTag{.{ .items = d_items[0..] }};
    const target_event = test_event(30023, pubkey, 90, [_]u8{0x40} ** 32, target_tags[0..]);

    try std.testing.expect(try deletion_can_apply(&delete_event, &target_event));
}
