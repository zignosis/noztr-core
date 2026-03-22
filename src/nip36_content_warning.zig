const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip32_labeling = @import("nip32_labeling.zig");

pub const tag_name: []const u8 = "content-warning";
pub const label_namespace: []const u8 = "content-warning";

pub const Nip36Error = error{
    InvalidContentWarningTag,
    InvalidContentWarningLabel,
};

pub const ContentWarningInfo = struct {
    reason: ?[]const u8 = null,
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

/// Extracts the first NIP-36 content-warning tag from an event.
pub fn content_warning_extract(
    event: *const nip01_event.Event,
) Nip36Error!?ContentWarningInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], tag_name)) continue;
        return .{ .reason = try parse_reason(tag) };
    }
    return null;
}

/// Builds a canonical NIP-36 `content-warning` tag.
pub fn content_warning_build_tag(
    output: *BuiltTag,
    reason: ?[]const u8,
) Nip36Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(reason == null or reason.?.len <= limits.tag_item_bytes_max);

    output.items[0] = tag_name;
    output.item_count = 1;
    if (reason) |value| {
        const parsed = parse_utf8(value) catch return error.InvalidContentWarningTag;
        if (parsed.len == 0) return output.as_event_tag();
        output.items[1] = parsed;
        output.item_count = 2;
    }
    return output.as_event_tag();
}

/// Builds the canonical NIP-32 `L` namespace tag for content-warning labels.
pub fn content_warning_build_namespace_tag(
    output: *nip32_labeling.BuiltTag,
) Nip36Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(label_namespace.len <= limits.tag_item_bytes_max);

    return nip32_labeling.label_build_namespace_tag(output, label_namespace) catch {
        return error.InvalidContentWarningLabel;
    };
}

/// Builds the canonical NIP-32 `l` tag for content-warning labels.
pub fn content_warning_build_label_tag(
    output: *nip32_labeling.BuiltTag,
    label: []const u8,
) Nip36Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(label.len <= limits.tag_item_bytes_max);

    return nip32_labeling.label_build_label_tag(output, label, label_namespace) catch {
        return error.InvalidContentWarningLabel;
    };
}

/// Compatibility alias for older NIP-36 content-warning tag builder naming.
pub const build_content_warning_tag = content_warning_build_tag;

/// Compatibility alias for older NIP-36 namespace tag builder naming.
pub const build_content_warning_namespace_tag = content_warning_build_namespace_tag;

/// Compatibility alias for older NIP-36 label tag builder naming.
pub const build_content_warning_label_tag = content_warning_build_label_tag;

/// Returns whether a parsed NIP-32 namespace is the NIP-36 content-warning namespace.
pub fn namespace_is_content_warning(namespace: nip32_labeling.LabelNamespace) bool {
    std.debug.assert(namespace.value.len <= limits.tag_item_bytes_max);
    std.debug.assert(label_namespace.len <= limits.tag_item_bytes_max);

    return std.mem.eql(u8, namespace.value, label_namespace);
}

/// Returns whether a parsed NIP-32 label is in the NIP-36 content-warning namespace.
pub fn label_is_content_warning(label: nip32_labeling.Label) bool {
    std.debug.assert(label.value.len <= limits.tag_item_bytes_max);
    std.debug.assert(label.namespace.len <= limits.tag_item_bytes_max);

    return std.mem.eql(u8, label.namespace, label_namespace);
}

fn parse_reason(tag: nip01_event.EventTag) Nip36Error!?[]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len == 1) return null;
    const reason = parse_utf8(tag.items[1]) catch return error.InvalidContentWarningTag;
    if (reason.len == 0) return null;
    return reason;
}

fn parse_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn test_event(tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(limits.tags_max <= std.math.maxInt(u16));

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

test "content warning extract treats empty reason as absent" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "title", "ignored" } },
        .{ .items = &.{ tag_name, "" } },
        .{ .items = &.{ tag_name, "later" } },
    };

    const parsed = try content_warning_extract(&test_event(tags[0..]));
    try std.testing.expect(parsed != null);
    try std.testing.expect(parsed.?.reason == null);
}

test "content warning extract handles absent and reasonless tags" {
    const absent_tags = [_]nip01_event.EventTag{.{ .items = &.{ "t", "nostr" } }};
    const reasonless_tags = [_]nip01_event.EventTag{.{ .items = &.{ tag_name } }};

    try std.testing.expect((try content_warning_extract(&test_event(absent_tags[0..]))) == null);
    const parsed = try content_warning_extract(&test_event(reasonless_tags[0..]));
    try std.testing.expect(parsed != null);
    try std.testing.expect(parsed.?.reason == null);
}

test "content warning extract ignores extra items but rejects invalid utf8" {
    const valid_tags = [_]nip01_event.EventTag{.{ .items = &.{ tag_name, "reason", "ignored" } }};
    const invalid_reason = [_]u8{ 0xff, 0xfe };
    const invalid_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ tag_name, invalid_reason[0..] } },
    };

    const parsed = try content_warning_extract(&test_event(valid_tags[0..]));
    try std.testing.expectEqualStrings("reason", parsed.?.reason.?);
    try std.testing.expectError(
        error.InvalidContentWarningTag,
        content_warning_extract(&test_event(invalid_tags[0..])),
    );
}

test "content warning builders emit canonical tags" {
    var warning_tag: BuiltTag = .{};
    var empty_warning_tag: BuiltTag = .{};
    var namespace_tag: nip32_labeling.BuiltTag = .{};
    var label_tag: nip32_labeling.BuiltTag = .{};

    const built_warning = try content_warning_build_tag(&warning_tag, "reason");
    try std.testing.expectEqualStrings(tag_name, built_warning.items[0]);
    try std.testing.expectEqualStrings("reason", built_warning.items[1]);
    const built_empty_warning = try content_warning_build_tag(&empty_warning_tag, "");
    try std.testing.expectEqual(@as(usize, 1), built_empty_warning.items.len);
    try std.testing.expectEqualStrings(tag_name, built_empty_warning.items[0]);

    const built_namespace = try content_warning_build_namespace_tag(&namespace_tag);
    try std.testing.expectEqualStrings("L", built_namespace.items[0]);
    try std.testing.expectEqualStrings(label_namespace, built_namespace.items[1]);

    const built_label = try content_warning_build_label_tag(&label_tag, "nudity");
    try std.testing.expectEqualStrings("l", built_label.items[0]);
    try std.testing.expectEqualStrings("nudity", built_label.items[1]);
    try std.testing.expectEqualStrings(label_namespace, built_label.items[2]);
}

test "content warning namespace and label matching stay exact" {
    const namespace = nip32_labeling.LabelNamespace{ .value = label_namespace };
    const other_namespace = nip32_labeling.LabelNamespace{ .value = "ugc" };
    const label = nip32_labeling.Label{ .value = "spam", .namespace = label_namespace };
    const other_label = nip32_labeling.Label{ .value = "spam", .namespace = "ugc" };

    try std.testing.expect(namespace_is_content_warning(namespace));
    try std.testing.expect(!namespace_is_content_warning(other_namespace));
    try std.testing.expect(label_is_content_warning(label));
    try std.testing.expect(!label_is_content_warning(other_label));
}
