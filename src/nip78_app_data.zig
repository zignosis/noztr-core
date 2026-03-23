const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const app_data_kind: u32 = 30078;

pub const AppDataError = error{
    InvalidAppDataKind,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
};

pub const AppData = struct {
    identifier: []const u8,
    content: []const u8,
};

pub const TagBuilder = struct {
    items: [2][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const TagBuilder) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Returns whether an event is the strict `kind:30078` app-data helper surface.
pub fn app_data_is_supported(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= limits.kind_max);

    return event.kind == app_data_kind;
}

/// Extracts the strict `d` identifier and opaque content from a `kind:30078` event.
pub fn app_data_extract(event: *const nip01_event.Event) AppDataError!AppData {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != app_data_kind) return error.InvalidAppDataKind;

    var identifier: ?[]const u8 = null;
    for (event.tags) |tag| {
        if (!is_identifier_tag(tag)) continue;
        if (identifier != null) return error.DuplicateIdentifierTag;
        identifier = parse_identifier_tag(tag) catch return error.InvalidIdentifierTag;
    }
    return .{
        .identifier = identifier orelse return error.MissingIdentifierTag,
        .content = event.content,
    };
}

/// Builds the required `d` tag for `kind:30078` app-data events.
pub fn app_data_build_identifier_tag(
    output: *TagBuilder,
    identifier: []const u8,
) AppDataError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn is_identifier_tag(tag: nip01_event.EventTag) bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max > 0);

    return tag.items.len != 0 and std.mem.eql(u8, tag.items[0], "d");
}

fn parse_identifier_tag(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
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

test "NIP-78 extracts identifier and opaque content" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "app-settings" } },
        .{ .items = &.{ "x-app", "opaque" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x78} ** 32,
        .pubkey = [_]u8{0x13} ** 32,
        .created_at = 3,
        .kind = app_data_kind,
        .tags = tags[0..],
        .content = "{\"theme\":\"dark\"}",
        .sig = [_]u8{0x24} ** 64,
    };

    const info = try app_data_extract(&event);

    try std.testing.expectEqualStrings("app-settings", info.identifier);
    try std.testing.expectEqualStrings("{\"theme\":\"dark\"}", info.content);
}

test "NIP-78 rejects duplicate identifiers" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "one" } },
        .{ .items = &.{ "d", "two" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x79} ** 32,
        .pubkey = [_]u8{0x14} ** 32,
        .created_at = 4,
        .kind = app_data_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x25} ** 64,
    };

    try std.testing.expectError(error.DuplicateIdentifierTag, app_data_extract(&event));
}

test "NIP-78 builds canonical identifier tag" {
    var built: TagBuilder = .{};

    const tag = try app_data_build_identifier_tag(&built, "profile-cache");

    try std.testing.expectEqualStrings("d", tag.items[0]);
    try std.testing.expectEqualStrings("profile-cache", tag.items[1]);
}
