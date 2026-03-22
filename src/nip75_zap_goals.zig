const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_scheme = @import("internal/url_with_scheme.zig");

pub const goal_kind: u32 = 9041;

pub const ZapGoalError = error{
    InvalidGoalKind,
    MissingRelaysTag,
    DuplicateRelaysTag,
    InvalidRelaysTag,
    MissingAmountTag,
    DuplicateAmountTag,
    InvalidAmountTag,
    DuplicateClosedAtTag,
    InvalidClosedAtTag,
    DuplicateImageTag,
    InvalidImageTag,
    DuplicateSummaryTag,
    InvalidSummaryTag,
    DuplicateUrlTag,
    InvalidUrlTag,
    DuplicateGoalTag,
    DuplicateCoordinateTag,
    InvalidCoordinateTag,
    InvalidGoalTag,
    BufferTooSmall,
};

pub const GoalInfo = struct {
    content: []const u8,
    amount_msats: u64,
    relay_count: u16 = 0,
    closed_at: ?u64 = null,
    image_url: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    url_link: ?[]const u8 = null,
    coordinate_link: ?[]const u8 = null,
};

pub const GoalReference = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const BuiltTag = struct {
    items: [limits.tag_items_max][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded zap-goal metadata from a kind-9041 goal event.
pub fn goal_extract(event: *const nip01_event.Event, out_relays: [][]const u8) ZapGoalError!GoalInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_relays.len <= limits.tag_items_max);

    if (event.kind != goal_kind) return error.InvalidGoalKind;

    var info = GoalInfo{ .content = event.content, .amount_msats = undefined };
    var saw_relays = false;
    var saw_amount = false;
    for (event.tags) |tag| {
        try apply_goal_tag(tag, &info, out_relays, &saw_relays, &saw_amount);
    }
    if (!saw_relays) return error.MissingRelaysTag;
    if (!saw_amount) return error.MissingAmountTag;
    return info;
}

/// Extracts a `goal` reference tag from any event, or `null` when absent.
pub fn goal_reference_extract(event: *const nip01_event.Event) ZapGoalError!?GoalReference {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    var reference: ?GoalReference = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "goal")) continue;
        if (reference != null) return error.DuplicateGoalTag;
        reference = parse_goal_reference_tag(tag) catch return error.InvalidGoalTag;
    }
    return reference;
}

pub fn goal_build_relays_tag(
    output: *BuiltTag,
    relays: []const []const u8,
) ZapGoalError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(relays.len <= limits.tag_items_max);

    if (relays.len == 0) return error.InvalidRelaysTag;
    output.items[0] = "relays";
    output.item_count = 1;
    for (relays) |relay| {
        output.items[output.item_count] = parse_url(relay) catch return error.InvalidRelaysTag;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

pub fn goal_build_amount_tag(
    output: *BuiltTag,
    amount_msats: u64,
) ZapGoalError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(amount_msats <= std.math.maxInt(u64));

    output.items[0] = "amount";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{amount_msats}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn goal_build_closed_at_tag(
    output: *BuiltTag,
    unix_seconds: u64,
) ZapGoalError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(unix_seconds <= std.math.maxInt(u64));

    output.items[0] = "closed_at";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{unix_seconds}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn goal_build_image_tag(
    output: *BuiltTag,
    image_url: []const u8,
) ZapGoalError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    output.items[0] = "image";
    output.items[1] = parse_url(image_url) catch return error.InvalidImageTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn goal_build_summary_tag(
    output: *BuiltTag,
    summary: []const u8,
) ZapGoalError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    output.items[0] = "summary";
    output.items[1] = parse_nonempty_utf8(summary) catch return error.InvalidSummaryTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn goal_build_reference_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
) ZapGoalError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    _ = lower_hex_32.parse(event_id_hex) catch return error.InvalidGoalTag;
    output.items[0] = "goal";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidGoalTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

fn apply_goal_tag(
    tag: nip01_event.EventTag,
    info: *GoalInfo,
    out_relays: [][]const u8,
    saw_relays: *bool,
    saw_amount: *bool,
) ZapGoalError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_relays) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "relays")) return apply_relays_tag(tag, info, out_relays, saw_relays);
    if (std.mem.eql(u8, tag.items[0], "amount")) return apply_amount_tag(tag, info, saw_amount);
    if (std.mem.eql(u8, tag.items[0], "closed_at")) return apply_timestamp_tag(tag, &info.closed_at, error.DuplicateClosedAtTag, error.InvalidClosedAtTag);
    if (std.mem.eql(u8, tag.items[0], "image")) return apply_url_field(tag, &info.image_url, error.DuplicateImageTag, error.InvalidImageTag);
    if (std.mem.eql(u8, tag.items[0], "summary")) return apply_text_field(tag, &info.summary, error.DuplicateSummaryTag, error.InvalidSummaryTag);
    if (std.mem.eql(u8, tag.items[0], "r")) return apply_url_field(tag, &info.url_link, error.DuplicateUrlTag, error.InvalidUrlTag);
    if (std.mem.eql(u8, tag.items[0], "a")) return apply_coordinate_field(tag, &info.coordinate_link);
}

fn apply_relays_tag(
    tag: nip01_event.EventTag,
    info: *GoalInfo,
    out_relays: [][]const u8,
    saw_relays: *bool,
) ZapGoalError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_relays) != 0);

    if (saw_relays.*) return error.DuplicateRelaysTag;
    if (tag.items.len < 2) return error.InvalidRelaysTag;
    if (tag.items.len - 1 > out_relays.len) return error.BufferTooSmall;
    var index: usize = 1;
    while (index < tag.items.len) : (index += 1) {
        out_relays[index - 1] = parse_url(tag.items[index]) catch return error.InvalidRelaysTag;
    }
    info.relay_count = @intCast(tag.items.len - 1);
    saw_relays.* = true;
}

fn apply_amount_tag(tag: nip01_event.EventTag, info: *GoalInfo, saw_amount: *bool) ZapGoalError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_amount) != 0);

    if (saw_amount.*) return error.DuplicateAmountTag;
    if (tag.items.len != 2) return error.InvalidAmountTag;
    info.amount_msats = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch {
        return error.InvalidAmountTag;
    };
    saw_amount.* = true;
}

fn apply_timestamp_tag(
    tag: nip01_event.EventTag,
    field: *?u64,
    duplicate_error: ZapGoalError,
    invalid_error: ZapGoalError,
) ZapGoalError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch return invalid_error;
}

fn apply_url_field(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: ZapGoalError,
    invalid_error: ZapGoalError,
) ZapGoalError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_url(tag.items[1]) catch return invalid_error;
}

fn apply_text_field(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: ZapGoalError,
    invalid_error: ZapGoalError,
) ZapGoalError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return duplicate_error;
    if (tag.items.len != 2) return invalid_error;
    field.* = parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
}

fn apply_coordinate_field(tag: nip01_event.EventTag, field: *?[]const u8) ZapGoalError!void {
    std.debug.assert(@intFromPtr(field) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (field.* != null) return error.DuplicateCoordinateTag;
    if (tag.items.len != 2) return error.InvalidCoordinateTag;
    field.* = parse_coordinate_text(tag.items[1]) catch return error.InvalidCoordinateTag;
}

fn parse_goal_reference_tag(tag: nip01_event.EventTag) error{InvalidTag}!GoalReference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidTag;
    return .{
        .event_id = lower_hex_32.parse(tag.items[1]) catch return error.InvalidTag,
        .relay_hint = if (tag.items.len == 3)
            parse_url(tag.items[2]) catch return error.InvalidTag
        else
            null,
    };
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return url_with_scheme.parse_utf8(text, limits.tag_item_bytes_max);
}

fn parse_coordinate_text(text: []const u8) error{InvalidCoordinate}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidCoordinate;
    var parts = std.mem.splitScalar(u8, text, ':');
    const kind_text = parts.next() orelse return error.InvalidCoordinate;
    const pubkey_text = parts.next() orelse return error.InvalidCoordinate;
    const identifier = parts.next() orelse return error.InvalidCoordinate;
    if (parts.next() != null) return error.InvalidCoordinate;
    _ = std.fmt.parseUnsigned(u32, kind_text, 10) catch return error.InvalidCoordinate;
    _ = lower_hex_32.parse(pubkey_text) catch return error.InvalidCoordinate;
    if (identifier.len == 0) return error.InvalidCoordinate;
    if (!std.unicode.utf8ValidateSlice(identifier)) return error.InvalidCoordinate;
    return text;
}

test "NIP-75 extracts goal metadata and relays" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "relays", "wss://relay.one", "wss://relay.two" } },
        .{ .items = &.{ "amount", "210000" } },
        .{ .items = &.{ "closed_at", "1700000000" } },
        .{ .items = &.{ "image", "https://cdn.example/goal.png" } },
        .{ .items = &.{ "summary", "travel expenses" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x75} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = goal_kind,
        .tags = tags[0..],
        .content = "goal body",
        .sig = [_]u8{0x22} ** 64,
    };
    var relays: [2][]const u8 = undefined;

    const info = try goal_extract(&event, relays[0..]);

    try std.testing.expectEqualStrings("goal body", info.content);
    try std.testing.expectEqual(@as(u64, 210000), info.amount_msats);
    try std.testing.expectEqual(@as(u16, 2), info.relay_count);
    try std.testing.expectEqual(@as(?u64, 1_700_000_000), info.closed_at);
}

test "NIP-75 extracts goal references from other events" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "goal",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "wss://relay.example.com",
        } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x76} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = 30_023,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x23} ** 64,
    };

    const reference = try goal_reference_extract(&event);

    try std.testing.expect(reference != null);
    try std.testing.expectEqualStrings("wss://relay.example.com", reference.?.relay_hint.?);
}

test "NIP-75 rejects duplicate goal references with typed goal error" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "goal", "1111111111111111111111111111111111111111111111111111111111111111" } },
        .{ .items = &.{ "goal", "2222222222222222222222222222222222222222222222222222222222222222" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x77} ** 32,
        .pubkey = [_]u8{0x13} ** 32,
        .created_at = 3,
        .kind = 1,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x24} ** 64,
    };

    try std.testing.expectError(error.DuplicateGoalTag, goal_reference_extract(&event));
}

test "NIP-75 builds canonical goal tags" {
    var relays_built: BuiltTag = .{};
    var amount_built: BuiltTag = .{};

    const relays = try goal_build_relays_tag(&relays_built, &.{"wss://relay.one"});
    const amount = try goal_build_amount_tag(&amount_built, 210000);

    try std.testing.expectEqualStrings("relays", relays.items[0]);
    try std.testing.expectEqualStrings("wss://relay.one", relays.items[1]);
    try std.testing.expectEqualStrings("amount", amount.items[0]);
    try std.testing.expectEqualStrings("210000", amount.items[1]);
}

test "NIP-75 rejects overlong goal reference builder input with typed error" {
    var built: BuiltTag = .{};
    const overlong = [_]u8{'a'} ** (limits.tag_item_bytes_max + 1);

    try std.testing.expectError(
        error.InvalidGoalTag,
        goal_build_reference_tag(&built, overlong[0..], null),
    );
}
