const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const alt_tag_name: []const u8 = "alt";

pub const Nip31Error = error{
    DuplicateAltTag,
    InvalidAltTag,
};

pub const BuiltTag = struct {
    items: [2][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts the strict `alt` fallback summary from an event, or `null` when absent.
pub fn alt_extract(event: *const nip01_event.Event) Nip31Error!?[]const u8 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    var alt: ?[]const u8 = null;
    for (event.tags) |tag| {
        if (!is_alt_tag(tag)) continue;
        if (alt != null) return error.DuplicateAltTag;
        alt = parse_alt_tag(tag) catch return error.InvalidAltTag;
    }
    return alt;
}

/// Builds a canonical `alt` tag for unknown or custom event kinds.
pub fn alt_build_tag(output: *BuiltTag, summary: []const u8) Nip31Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(summary.len <= limits.tag_item_bytes_max);

    output.items[0] = alt_tag_name;
    output.items[1] = parse_nonempty_utf8(summary) catch return error.InvalidAltTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn is_alt_tag(tag: nip01_event.EventTag) bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max > 0);

    return tag.items.len != 0 and std.mem.eql(u8, tag.items[0], alt_tag_name);
}

fn parse_alt_tag(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTag;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

test "NIP-31 extract alt summary" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "alt", "human summary" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x31} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = 10_031,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x22} ** 64,
    };

    const summary = try alt_extract(&event);

    try std.testing.expect(summary != null);
    try std.testing.expectEqualStrings("human summary", summary.?);
}

test "NIP-31 rejects duplicate alt tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "alt", "one" } },
        .{ .items = &.{ "alt", "two" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x32} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = 10_032,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x23} ** 64,
    };

    try std.testing.expectError(error.DuplicateAltTag, alt_extract(&event));
}

test "NIP-31 builds canonical alt tag" {
    var built: BuiltTag = .{};

    const tag = try alt_build_tag(&built, "short fallback");

    try std.testing.expectEqualStrings("alt", tag.items[0]);
    try std.testing.expectEqualStrings("short fallback", tag.items[1]);
}
