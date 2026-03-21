const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_host = @import("internal/url_with_host.zig");

pub const label_event_kind: u32 = 1985;
pub const default_namespace: []const u8 = "ugc";

pub const Nip32Error = error{
    InvalidLabelEventKind,
    InvalidSelfLabelKind,
    MissingLabel,
    MissingTarget,
    InvalidNamespaceTag,
    InvalidLabelTag,
    InvalidEventTargetTag,
    InvalidPubkeyTargetTag,
    InvalidCoordinateTargetTag,
    InvalidRelayTargetTag,
    InvalidHashtagTargetTag,
    BufferTooSmall,
};

pub const LabelNamespace = struct {
    value: []const u8,
    is_tag_value_namespace: bool = false,
};

pub const Label = struct {
    value: []const u8,
    namespace: []const u8,
};

pub const EventTarget = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const PubkeyTarget = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const CoordinateTarget = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const LabelTarget = union(enum) {
    event: EventTarget,
    pubkey: PubkeyTarget,
    coordinate: CoordinateTarget,
    relay: []const u8,
    hashtag: []const u8,
};

pub const LabelEventInfo = struct {
    content: []const u8,
    namespaces: []const LabelNamespace,
    labels: []const Label,
    targets: []const LabelTarget,
};

pub const SelfLabelInfo = struct {
    kind: u32,
    content: []const u8,
    namespaces: []const LabelNamespace,
    labels: []const Label,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extract bounded labels and targets from a kind-1985 label event.
pub fn label_event_extract(
    event: *const nip01_event.Event,
    out_namespaces: []LabelNamespace,
    out_labels: []Label,
    out_targets: []LabelTarget,
) Nip32Error!LabelEventInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_namespaces.len <= limits.tags_max);

    if (event.kind != label_event_kind) return error.InvalidLabelEventKind;

    var namespace_count: u16 = 0;
    var label_count: u16 = 0;
    var target_count: u16 = 0;
    for (event.tags) |tag| {
        try apply_label_event_tag(
            tag,
            out_namespaces,
            &namespace_count,
            out_labels,
            &label_count,
            out_targets,
            &target_count,
        );
    }
    if (label_count == 0) return error.MissingLabel;
    try validate_label_namespaces(
        out_namespaces[0..namespace_count],
        out_labels[0..label_count],
    );
    if (target_count == 0) return error.MissingTarget;
    return .{
        .content = event.content,
        .namespaces = out_namespaces[0..namespace_count],
        .labels = out_labels[0..label_count],
        .targets = out_targets[0..target_count],
    };
}

/// Extract bounded self-labels from a non-1985 event.
pub fn self_labels_extract(
    event: *const nip01_event.Event,
    out_namespaces: []LabelNamespace,
    out_labels: []Label,
) Nip32Error!SelfLabelInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_labels.len <= limits.tags_max);

    if (event.kind == label_event_kind) return error.InvalidSelfLabelKind;

    var namespace_count: u16 = 0;
    var label_count: u16 = 0;
    for (event.tags) |tag| {
        try apply_self_label_tag(tag, out_namespaces, &namespace_count, out_labels, &label_count);
    }
    try validate_label_namespaces(
        out_namespaces[0..namespace_count],
        out_labels[0..label_count],
    );
    return .{
        .kind = event.kind,
        .content = event.content,
        .namespaces = out_namespaces[0..namespace_count],
        .labels = out_labels[0..label_count],
    };
}

/// Builds a canonical NIP-32 `L` tag.
pub fn label_build_namespace_tag(
    output: *BuiltTag,
    namespace: []const u8,
) Nip32Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(namespace.len <= limits.tag_item_bytes_max);

    output.items[0] = "L";
    output.items[1] = parse_namespace(namespace) catch return error.InvalidNamespaceTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-32 `l` tag.
pub fn label_build_label_tag(
    output: *BuiltTag,
    value: []const u8,
    namespace: ?[]const u8,
) Nip32Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    output.items[0] = "l";
    output.items[1] = parse_label_value(value) catch return error.InvalidLabelTag;
    output.item_count = 2;
    if (namespace) |mark| {
        output.items[2] = parse_namespace(mark) catch return error.InvalidLabelTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical NIP-32 event target `e` tag.
pub fn label_build_event_target_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
) Nip32Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_id_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(event_id_hex) catch return error.InvalidEventTargetTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidEventTargetTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical NIP-32 pubkey target `p` tag.
pub fn label_build_pubkey_target_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
) Nip32Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidPubkeyTargetTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidPubkeyTargetTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical NIP-32 coordinate target `a` tag.
pub fn label_build_coordinate_target_tag(
    output: *BuiltTag,
    coordinate_text: []const u8,
    relay_hint: ?[]const u8,
) Nip32Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(coordinate_text.len <= limits.tag_item_bytes_max);

    _ = parse_coordinate(coordinate_text) catch return error.InvalidCoordinateTargetTag;
    output.items[0] = "a";
    output.items[1] = coordinate_text;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidCoordinateTargetTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical NIP-32 relay target `r` tag.
pub fn label_build_relay_target_tag(
    output: *BuiltTag,
    relay_url: []const u8,
) Nip32Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(relay_url.len <= limits.tag_item_bytes_max);

    output.items[0] = "r";
    output.items[1] = parse_url(relay_url) catch return error.InvalidRelayTargetTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical NIP-32 hashtag target `t` tag.
pub fn label_build_hashtag_target_tag(
    output: *BuiltTag,
    hashtag: []const u8,
) Nip32Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(hashtag.len <= limits.tag_item_bytes_max);

    output.items[0] = "t";
    output.items[1] = parse_hashtag(hashtag) catch return error.InvalidHashtagTargetTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_label_event_tag(
    tag: nip01_event.EventTag,
    out_namespaces: []LabelNamespace,
    namespace_count: *u16,
    out_labels: []Label,
    label_count: *u16,
    out_targets: []LabelTarget,
    target_count: *u16,
) Nip32Error!void {
    std.debug.assert(@intFromPtr(namespace_count) != 0);
    std.debug.assert(@intFromPtr(target_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "L")) {
        return parse_namespace_tag(tag, out_namespaces, namespace_count);
    }
    if (std.mem.eql(u8, tag.items[0], "l")) {
        return parse_label_tag(tag, out_labels, label_count);
    }
    return parse_target_tag(tag, out_targets, target_count);
}

fn apply_self_label_tag(
    tag: nip01_event.EventTag,
    out_namespaces: []LabelNamespace,
    namespace_count: *u16,
    out_labels: []Label,
    label_count: *u16,
) Nip32Error!void {
    std.debug.assert(@intFromPtr(namespace_count) != 0);
    std.debug.assert(@intFromPtr(label_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "L")) {
        return parse_namespace_tag(tag, out_namespaces, namespace_count);
    }
    if (std.mem.eql(u8, tag.items[0], "l")) {
        return parse_label_tag(tag, out_labels, label_count);
    }
}

fn parse_namespace_tag(
    tag: nip01_event.EventTag,
    out: []LabelNamespace,
    count: *u16,
) Nip32Error!void {
    std.debug.assert(@intFromPtr(count) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidNamespaceTag;
    if (count.* == out.len) return error.BufferTooSmall;
    const namespace = parse_namespace(tag.items[1]) catch return error.InvalidNamespaceTag;
    out[count.*] = .{
        .value = namespace,
        .is_tag_value_namespace = std.mem.startsWith(u8, namespace, "#"),
    };
    count.* += 1;
}

fn parse_label_tag(
    tag: nip01_event.EventTag,
    out: []Label,
    count: *u16,
) Nip32Error!void {
    std.debug.assert(@intFromPtr(count) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidLabelTag;
    if (count.* == out.len) return error.BufferTooSmall;
    const namespace = if (tag.items.len >= 3)
        parse_namespace(tag.items[2]) catch return error.InvalidLabelTag
    else
        default_namespace;
    out[count.*] = .{
        .value = parse_label_value(tag.items[1]) catch return error.InvalidLabelTag,
        .namespace = namespace,
    };
    count.* += 1;
}

fn parse_target_tag(
    tag: nip01_event.EventTag,
    out: []LabelTarget,
    count: *u16,
) Nip32Error!void {
    std.debug.assert(@intFromPtr(count) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len == 0) return;
    if (tag.items[0].len == 0) return;
    if (count.* == out.len) return error.BufferTooSmall;
    const parsed = if (std.mem.eql(u8, tag.items[0], "e"))
        LabelTarget{ .event = try parse_event_target(tag) }
    else if (std.mem.eql(u8, tag.items[0], "p"))
        LabelTarget{ .pubkey = try parse_pubkey_target(tag) }
    else if (std.mem.eql(u8, tag.items[0], "a"))
        LabelTarget{ .coordinate = try parse_coordinate_target(tag) }
    else if (std.mem.eql(u8, tag.items[0], "r"))
        LabelTarget{ .relay = try parse_relay_target(tag) }
    else if (std.mem.eql(u8, tag.items[0], "t"))
        LabelTarget{ .hashtag = try parse_hashtag_target(tag) }
    else
        return;
    out[count.*] = parsed;
    count.* += 1;
}

fn parse_event_target(tag: nip01_event.EventTag) Nip32Error!EventTarget {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.id_hex_length == limits.pubkey_hex_length);

    if (tag.items.len < 2 or tag.items.len > 5) return error.InvalidEventTargetTag;
    return .{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidEventTargetTag,
        .relay_hint = try parse_optional_url_item(tag, 2, error.InvalidEventTargetTag),
    };
}

fn parse_pubkey_target(tag: nip01_event.EventTag) Nip32Error!PubkeyTarget {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (tag.items.len < 2 or tag.items.len > 4) return error.InvalidPubkeyTargetTag;
    return .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidPubkeyTargetTag,
        .relay_hint = try parse_optional_url_item(tag, 2, error.InvalidPubkeyTargetTag),
    };
}

fn parse_coordinate_target(tag: nip01_event.EventTag) Nip32Error!CoordinateTarget {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.kind_max == std.math.maxInt(u16));

    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidCoordinateTargetTag;
    var parsed = parse_coordinate(tag.items[1]) catch return error.InvalidCoordinateTargetTag;
    parsed.relay_hint = try parse_optional_url_item(tag, 2, error.InvalidCoordinateTargetTag);
    return parsed;
}

fn parse_relay_target(tag: nip01_event.EventTag) Nip32Error![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidRelayTargetTag;
    return parse_url(tag.items[1]) catch return error.InvalidRelayTargetTag;
}

fn parse_hashtag_target(tag: nip01_event.EventTag) Nip32Error![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidHashtagTargetTag;
    return parse_hashtag(tag.items[1]) catch return error.InvalidHashtagTargetTag;
}

fn validate_label_namespaces(
    namespaces: []const LabelNamespace,
    labels: []const Label,
) Nip32Error!void {
    std.debug.assert(namespaces.len <= limits.tags_max);
    std.debug.assert(labels.len <= limits.tags_max);

    if (namespaces.len == 0) return;
    for (labels) |label| {
        if (namespace_exists(namespaces, label.namespace)) continue;
        return error.InvalidLabelTag;
    }
}

fn namespace_exists(namespaces: []const LabelNamespace, value: []const u8) bool {
    std.debug.assert(namespaces.len <= limits.tags_max);
    std.debug.assert(value.len <= limits.tag_item_bytes_max);

    for (namespaces) |namespace| {
        if (std.mem.eql(u8, namespace.value, value)) return true;
    }
    return false;
}

fn parse_coordinate(text: []const u8) error{InvalidCoordinate}!CoordinateTarget {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidCoordinate;
    if (first_colon == 0) return error.InvalidCoordinate;
    const second_search = text[first_colon + 1 ..];
    const second_rel = std.mem.indexOfScalar(u8, second_search, ':') orelse {
        return error.InvalidCoordinate;
    };
    const second_colon = first_colon + 1 + second_rel;
    if (second_colon == first_colon + 1) return error.InvalidCoordinate;
    const kind = std.fmt.parseUnsigned(u32, text[0..first_colon], 10) catch {
        return error.InvalidCoordinate;
    };
    const pubkey = parse_lower_hex_32(text[first_colon + 1 .. second_colon]) catch {
        return error.InvalidCoordinate;
    };
    const identifier = text[second_colon + 1 ..];
    try validate_coordinate_kind(kind, identifier);
    return .{ .kind = kind, .pubkey = pubkey, .identifier = identifier };
}

fn validate_coordinate_kind(kind: u32, identifier: []const u8) error{InvalidCoordinate}!void {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    const replaceable = kind == 0 or kind == 3 or (kind >= 10_000 and kind < 20_000);
    const addressable = kind >= 30_000 and kind < 40_000;
    if (!replaceable and !addressable) return error.InvalidCoordinate;
    if (replaceable and identifier.len != 0) return error.InvalidCoordinate;
    if (addressable and identifier.len == 0) return error.InvalidCoordinate;
}

fn parse_optional_url_item(
    tag: nip01_event.EventTag,
    index: usize,
    invalid: Nip32Error,
) Nip32Error!?[]const u8 {
    std.debug.assert(index <= limits.tag_items_max);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len <= index) return null;
    if (tag.items[index].len == 0) return null;
    return parse_url(tag.items[index]) catch return invalid;
}

fn parse_namespace(text: []const u8) error{InvalidNamespace}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    const parsed = parse_nonempty_utf8(text) catch return error.InvalidNamespace;
    if (std.mem.eql(u8, parsed, "#")) return error.InvalidNamespace;
    return parsed;
}

fn parse_label_value(text: []const u8) error{InvalidLabel}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return parse_nonempty_utf8(text) catch return error.InvalidLabel;
}

fn parse_hashtag(text: []const u8) error{InvalidHashtag}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    const parsed = parse_nonempty_utf8(text) catch return error.InvalidHashtag;
    if (std.mem.indexOfScalar(u8, parsed, ' ') != null) return error.InvalidHashtag;
    for (parsed) |byte| {
        if (std.ascii.isUpper(byte)) return error.InvalidHashtag;
    }
    return parsed;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    return url_with_host.parse(text, limits.tag_item_bytes_max);
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn test_event(kind: u32, content: []const u8, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 0,
        .content = content,
        .tags = tags,
    };
}

test "label event extract parses namespaces labels and targets" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "L", "#t" } },
        .{ .items = &.{ "L", "license" } },
        .{ .items = &.{ "l", "nostr", "#t" } },
        .{ .items = &.{ "l", "MIT", "license" } },
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "wss://relay.example" } },
        .{ .items = &.{ "a", "30023:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:article" } },
        .{ .items = &.{ "r", "wss://relay.example" } },
        .{ .items = &.{ "t", "topic" } },
    };
    var namespaces: [4]LabelNamespace = undefined;
    var labels: [4]Label = undefined;
    var targets: [5]LabelTarget = undefined;
    const parsed = try label_event_extract(&test_event(label_event_kind, "why", tags[0..]), namespaces[0..], labels[0..], targets[0..]);

    try std.testing.expectEqualStrings("why", parsed.content);
    try std.testing.expectEqual(@as(usize, 2), parsed.namespaces.len);
    try std.testing.expect(parsed.namespaces[0].is_tag_value_namespace);
    try std.testing.expectEqual(@as(usize, 2), parsed.labels.len);
    try std.testing.expectEqualStrings("#t", parsed.labels[0].namespace);
    try std.testing.expectEqual(@as(usize, 5), parsed.targets.len);
}

test "label event extract accepts implicit ugc labels and self labels" {
    const label_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "l", "personal" } },
        .{ .items = &.{ "t", "topic" } },
    };
    var namespaces: [1]LabelNamespace = undefined;
    var labels: [2]Label = undefined;
    var targets: [1]LabelTarget = undefined;
    const parsed = try label_event_extract(
        &test_event(label_event_kind, "", label_tags[0..]),
        namespaces[0..],
        labels[0..],
        targets[0..],
    );
    try std.testing.expectEqual(@as(usize, 0), parsed.namespaces.len);
    try std.testing.expectEqualStrings(default_namespace, parsed.labels[0].namespace);

    const self_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "L", "ISO-639-1" } },
        .{ .items = &.{ "l", "en", "ISO-639-1" } },
    };
    const self_info = try self_labels_extract(&test_event(1, "English", self_tags[0..]), namespaces[0..], labels[0..]);
    try std.testing.expectEqual(@as(usize, 1), self_info.labels.len);
    try std.testing.expectEqualStrings("en", self_info.labels[0].value);
}

test "label event extract rejects invalid namespace use and missing targets" {
    const missing_target_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "L", "license" } },
        .{ .items = &.{ "l", "MIT", "license" } },
    };
    const missing_mark_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "L", "license" } },
        .{ .items = &.{ "l", "MIT" } },
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
    };
    var namespaces: [2]LabelNamespace = undefined;
    var labels: [2]Label = undefined;
    var targets: [2]LabelTarget = undefined;

    try std.testing.expectError(
        error.MissingTarget,
        label_event_extract(&test_event(label_event_kind, "", missing_target_tags[0..]), namespaces[0..], labels[0..], targets[0..]),
    );
    try std.testing.expectError(
        error.InvalidLabelTag,
        label_event_extract(&test_event(label_event_kind, "", missing_mark_tags[0..]), namespaces[0..], labels[0..], targets[0..]),
    );
}

test "label event builders emit canonical tags" {
    var namespace_tag: BuiltTag = .{};
    var label_tag: BuiltTag = .{};
    var event_tag: BuiltTag = .{};
    var pubkey_tag: BuiltTag = .{};
    var coordinate_tag: BuiltTag = .{};
    var relay_tag: BuiltTag = .{};
    var hashtag_tag: BuiltTag = .{};

    try std.testing.expectEqualStrings(
        "L",
        (try label_build_namespace_tag(&namespace_tag, "license")).items[0],
    );
    try std.testing.expectEqualStrings(
        "license",
        (try label_build_namespace_tag(&namespace_tag, "license")).items[1],
    );
    try std.testing.expectEqualStrings(
        "ugc",
        (try label_build_label_tag(&label_tag, "personal", default_namespace)).items[2],
    );
    try std.testing.expectEqualStrings(
        "e",
        (try label_build_event_target_tag(&event_tag, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", null)).items[0],
    );
    try std.testing.expectEqualStrings(
        "p",
        (try label_build_pubkey_target_tag(&pubkey_tag, "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", null)).items[0],
    );
    try std.testing.expectEqualStrings(
        "a",
        (try label_build_coordinate_target_tag(&coordinate_tag, "30023:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:article", null)).items[0],
    );
    try std.testing.expectEqualStrings(
        "r",
        (try label_build_relay_target_tag(&relay_tag, "wss://relay.example")).items[0],
    );
    try std.testing.expectEqualStrings(
        "t",
        (try label_build_hashtag_target_tag(&hashtag_tag, "topic")).items[0],
    );
    try std.testing.expectError(
        error.InvalidHashtagTargetTag,
        label_build_hashtag_target_tag(&hashtag_tag, "Topic"),
    );
}

test "label event extract rejects uppercase hashtag targets" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "l", "topic", "ugc" } },
        .{ .items = &.{ "t", "Topic" } },
    };
    var namespaces: [1]LabelNamespace = undefined;
    var labels: [1]Label = undefined;
    var targets: [1]LabelTarget = undefined;

    try std.testing.expectError(
        error.InvalidHashtagTargetTag,
        label_event_extract(
            &test_event(label_event_kind, "", tags[0..]),
            namespaces[0..],
            labels[0..],
            targets[0..],
        ),
    );
}

test "label event extract accepts standard long-form e and p targets" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "l", "report", "ugc" } },
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "", "root", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "", "alice" } },
    };
    var namespaces: [1]LabelNamespace = undefined;
    var labels: [1]Label = undefined;
    var targets: [2]LabelTarget = undefined;
    const parsed = try label_event_extract(
        &test_event(label_event_kind, "", tags[0..]),
        namespaces[0..],
        labels[0..],
        targets[0..],
    );
    try std.testing.expectEqual(@as(usize, 2), parsed.targets.len);
    switch (parsed.targets[0]) {
        .event => |target| try std.testing.expect(target.relay_hint == null),
        else => return error.UnexpectedError,
    }
    switch (parsed.targets[1]) {
        .pubkey => |target| try std.testing.expect(target.relay_hint == null),
        else => return error.UnexpectedError,
    }
}

test "label event extract ignores unrelated tags and extra label items" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "l", "topic", "ugc", "en", "extra" } },
        .{ .items = &.{ "title", "ignored" } },
        .{ .items = &.{ "emoji", "ignored", "https://example.com/ignored.png" } },
        .{ .items = &.{ "", "ignored" } },
        .{ .items = &.{ "t", "nostr" } },
    };
    var namespaces: [1]LabelNamespace = undefined;
    var labels: [1]Label = undefined;
    var targets: [1]LabelTarget = undefined;
    const parsed = try label_event_extract(
        &test_event(label_event_kind, "", tags[0..]),
        namespaces[0..],
        labels[0..],
        targets[0..],
    );

    try std.testing.expectEqual(@as(usize, 1), parsed.labels.len);
    try std.testing.expectEqualStrings("ugc", parsed.labels[0].namespace);
    try std.testing.expectEqual(@as(usize, 1), parsed.targets.len);
    switch (parsed.targets[0]) {
        .hashtag => |target| try std.testing.expectEqualStrings("nostr", target),
        else => return error.UnexpectedError,
    }
}
