const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const channel_create_kind: u32 = 40;
pub const channel_metadata_kind: u32 = 41;
pub const channel_message_kind: u32 = 42;
pub const hide_message_kind: u32 = 43;
pub const mute_user_kind: u32 = 44;

pub const Nip28Error = error{
    InvalidChannelCreateKind,
    InvalidChannelMetadataKind,
    InvalidChannelMessageKind,
    InvalidHideMessageKind,
    InvalidMuteUserKind,
    InvalidMetadataJson,
    MissingChannelTag,
    DuplicateChannelTag,
    InvalidChannelTag,
    DuplicateReplyTag,
    InvalidReplyTag,
    InvalidPubkeyTag,
    InvalidCategoryTag,
    MissingTargetEventTag,
    DuplicateTargetEventTag,
    InvalidTargetEventTag,
    MissingTargetPubkeyTag,
    DuplicateTargetPubkeyTag,
    InvalidTargetPubkeyTag,
    InvalidReasonJson,
    BufferTooSmall,
};

pub const ChannelMetadata = struct {
    name: ?[]const u8 = null,
    about: ?[]const u8 = null,
    picture: ?[]const u8 = null,
    relay_count: u16 = 0,
};

pub const ChannelReference = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const ChannelUpdateInfo = struct {
    channel: ChannelReference,
    metadata: ChannelMetadata,
    category_count: u16 = 0,
};

pub const ChannelMessageInfo = struct {
    channel: ChannelReference,
    reply: ?ChannelReference = null,
    content: []const u8,
    reply_pubkey_count: u16 = 0,
};

pub const HideMessageInfo = struct {
    target_event: [32]u8,
    reason: ?[]const u8 = null,
};

pub const MuteUserInfo = struct {
    target_pubkey: [32]u8,
    reason: ?[]const u8 = null,
};

pub const EventMarker = enum {
    root,
    reply,
};

pub const BuiltTag = struct {
    items: [4][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

pub const BuiltJson = struct {
    storage: [limits.content_bytes_max]u8 = undefined,
};

/// Parses bounded NIP-28 channel metadata JSON from kind-40 or kind-41 content.
pub fn channel_metadata_parse_json(
    content: []const u8,
    out_relays: [][]const u8,
    scratch: std.mem.Allocator,
) Nip28Error!ChannelMetadata {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const value = std.json.parseFromSliceLeaky(std.json.Value, scratch, content, .{}) catch {
        return error.InvalidMetadataJson;
    };
    if (value != .object) return error.InvalidMetadataJson;
    return parse_metadata_object(value.object, out_relays);
}

/// Extracts bounded channel-create metadata from a kind-40 event.
pub fn channel_create_extract(
    event: *const nip01_event.Event,
    out_relays: [][]const u8,
    scratch: std.mem.Allocator,
) Nip28Error!ChannelMetadata {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (event.kind != channel_create_kind) return error.InvalidChannelCreateKind;
    return channel_metadata_parse_json(event.content, out_relays, scratch);
}

/// Extracts bounded channel-update metadata from a kind-41 event.
pub fn channel_metadata_extract(
    event: *const nip01_event.Event,
    out_relays: [][]const u8,
    out_categories: [][]const u8,
    scratch: std.mem.Allocator,
) Nip28Error!ChannelUpdateInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (event.kind != channel_metadata_kind) return error.InvalidChannelMetadataKind;

    var channel: ?ChannelReference = null;
    var category_count: u16 = 0;
    for (event.tags) |tag| {
        try apply_update_tag(tag, &channel, out_categories, &category_count);
    }
    return .{
        .channel = channel orelse return error.MissingChannelTag,
        .metadata = try channel_metadata_parse_json(event.content, out_relays, scratch),
        .category_count = category_count,
    };
}

/// Extracts bounded channel-message linkage from a kind-42 event.
pub fn channel_message_extract(
    event: *const nip01_event.Event,
    out_reply_pubkeys: [][32]u8,
) Nip28Error!ChannelMessageInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_reply_pubkeys.len <= limits.tags_max);

    if (event.kind != channel_message_kind) return error.InvalidChannelMessageKind;

    var channel: ?ChannelReference = null;
    var reply: ?ChannelReference = null;
    var info = ChannelMessageInfo{ .channel = undefined, .content = event.content };
    for (event.tags) |tag| {
        try apply_message_tag(tag, &channel, &reply, &info, out_reply_pubkeys);
    }
    info.channel = channel orelse return error.MissingChannelTag;
    info.reply = reply;
    return info;
}

/// Extracts the target message and optional reason from a kind-43 hide-message event.
pub fn hide_message_extract(
    event: *const nip01_event.Event,
    scratch: std.mem.Allocator,
) Nip28Error!HideMessageInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (event.kind != hide_message_kind) return error.InvalidHideMessageKind;

    var target: ?[32]u8 = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0 or !std.mem.eql(u8, tag.items[0], "e")) continue;
        if (target != null) return error.DuplicateTargetEventTag;
        target = parse_event_id_tag(tag) catch return error.InvalidTargetEventTag;
    }
    return .{
        .target_event = target orelse return error.MissingTargetEventTag,
        .reason = try parse_reason_json(event.content, scratch),
    };
}

/// Extracts the target pubkey and optional reason from a kind-44 mute-user event.
pub fn mute_user_extract(
    event: *const nip01_event.Event,
    scratch: std.mem.Allocator,
) Nip28Error!MuteUserInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (event.kind != mute_user_kind) return error.InvalidMuteUserKind;

    var target: ?[32]u8 = null;
    for (event.tags) |tag| {
        if (tag.items.len == 0 or !std.mem.eql(u8, tag.items[0], "p")) continue;
        if (target != null) return error.DuplicateTargetPubkeyTag;
        target = parse_pubkey_tag(tag) catch return error.InvalidTargetPubkeyTag;
    }
    return .{
        .target_pubkey = target orelse return error.MissingTargetPubkeyTag,
        .reason = try parse_reason_json(event.content, scratch),
    };
}

/// Builds canonical NIP-28 channel metadata JSON.
pub fn channel_build_metadata_json(
    output: *BuiltJson,
    name: ?[]const u8,
    about: ?[]const u8,
    picture: ?[]const u8,
    relays: []const []const u8,
) Nip28Error![]const u8 {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(relays.len <= limits.tag_items_max);

    try validate_metadata_fields(name, about, picture, relays);
    var stream = std.io.fixedBufferStream(output.storage[0..]);
    var writer = stream.writer();
    try write_metadata_json(&writer, name, about, picture, relays);
    return stream.getWritten();
}

/// Builds an `e` tag for a channel root or reply reference.
pub fn channel_build_event_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
    marker: EventMarker,
) Nip28Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_id_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(event_id_hex) catch return error.InvalidChannelTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidChannelTag;
        output.item_count = 3;
    }
    output.items[output.item_count] = switch (marker) {
        .root => "root",
        .reply => "reply",
    };
    output.item_count += 1;
    return output.as_event_tag();
}

/// Builds a `p` tag for a reply author reference.
pub fn channel_build_pubkey_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
) Nip28Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidPubkeyTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidPubkeyTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical category `t` tag for kind-41 channel metadata.
pub fn channel_build_category_tag(
    output: *BuiltTag,
    category: []const u8,
) Nip28Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(category.len <= limits.tag_item_bytes_max);

    output.items[0] = "t";
    output.items[1] = parse_nonempty_utf8(category) catch return error.InvalidCategoryTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds canonical moderation metadata JSON with an optional `reason`.
pub fn channel_build_reason_json(
    output: *BuiltJson,
    reason: []const u8,
) Nip28Error![]const u8 {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(reason.len <= limits.content_bytes_max);

    _ = parse_nonempty_utf8(reason) catch return error.InvalidReasonJson;
    var stream = std.io.fixedBufferStream(output.storage[0..]);
    var writer = stream.writer();
    writer.writeAll("{\"reason\":") catch return error.BufferTooSmall;
    try write_json_string(&writer, reason);
    writer.writeByte('}') catch return error.BufferTooSmall;
    return stream.getWritten();
}

fn parse_metadata_object(
    object: std.json.ObjectMap,
    out_relays: [][]const u8,
) Nip28Error!ChannelMetadata {
    std.debug.assert(out_relays.len <= limits.tags_max);
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);

    var metadata = ChannelMetadata{};
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;
        if (std.mem.eql(u8, key, "name")) {
            metadata.name = try parse_optional_string_field(value, error.InvalidMetadataJson);
            continue;
        }
        if (std.mem.eql(u8, key, "about")) {
            metadata.about = try parse_optional_string_field(value, error.InvalidMetadataJson);
            continue;
        }
        if (std.mem.eql(u8, key, "picture")) {
            metadata.picture = try parse_optional_url_field(value);
            continue;
        }
        if (std.mem.eql(u8, key, "relays")) {
            metadata.relay_count = try parse_metadata_relays(value, out_relays);
        }
    }
    return metadata;
}

fn parse_optional_string_field(
    value: std.json.Value,
    invalid_error: Nip28Error,
) Nip28Error!?[]const u8 {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(@intFromError(invalid_error) >= 0);

    if (value == .null) return null;
    if (value != .string) return invalid_error;
    return parse_nonempty_utf8(value.string) catch invalid_error;
}

fn parse_optional_url_field(value: std.json.Value) Nip28Error!?[]const u8 {
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (value == .null) return null;
    if (value != .string) return error.InvalidMetadataJson;
    return parse_url(value.string) catch return error.InvalidMetadataJson;
}

fn parse_metadata_relays(value: std.json.Value, out_relays: [][]const u8) Nip28Error!u16 {
    std.debug.assert(out_relays.len <= limits.tags_max);
    std.debug.assert(@typeInfo(std.json.Value) == .@"union");

    if (value != .array) return error.InvalidMetadataJson;
    if (value.array.items.len > out_relays.len) return error.BufferTooSmall;

    var count: u16 = 0;
    for (value.array.items) |item| {
        if (item != .string) return error.InvalidMetadataJson;
        out_relays[count] = parse_url(item.string) catch return error.InvalidMetadataJson;
        count += 1;
    }
    return count;
}

fn apply_update_tag(
    tag: nip01_event.EventTag,
    channel: *?ChannelReference,
    out_categories: [][]const u8,
    category_count: *u16,
) Nip28Error!void {
    std.debug.assert(@intFromPtr(channel) != 0);
    std.debug.assert(@intFromPtr(category_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "e")) {
        if (channel.* != null) return error.DuplicateChannelTag;
        channel.* = parse_channel_root_tag(tag) catch return error.InvalidChannelTag;
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "t")) {
        try append_category(tag, out_categories, category_count);
    }
}

fn append_category(
    tag: nip01_event.EventTag,
    out_categories: [][]const u8,
    count: *u16,
) Nip28Error!void {
    std.debug.assert(@intFromPtr(count) != 0);
    std.debug.assert(count.* <= out_categories.len);

    if (tag.items.len != 2) return error.InvalidCategoryTag;
    if (count.* == out_categories.len) return error.BufferTooSmall;
    out_categories[count.*] = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidCategoryTag;
    count.* += 1;
}

fn apply_message_tag(
    tag: nip01_event.EventTag,
    channel: *?ChannelReference,
    reply: *?ChannelReference,
    info: *ChannelMessageInfo,
    out_reply_pubkeys: [][32]u8,
) Nip28Error!void {
    std.debug.assert(@intFromPtr(channel) != 0);
    std.debug.assert(@intFromPtr(info) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "e")) {
        try parse_message_event_tag(tag, channel, reply);
        return;
    }
    if (std.mem.eql(u8, tag.items[0], "p")) {
        try append_reply_pubkey(tag, info, out_reply_pubkeys);
    }
}

fn parse_message_event_tag(
    tag: nip01_event.EventTag,
    channel: *?ChannelReference,
    reply: *?ChannelReference,
) Nip28Error!void {
    std.debug.assert(@intFromPtr(channel) != 0);
    std.debug.assert(@intFromPtr(reply) != 0);

    const marker = if (tag.items.len >= 4) tag.items[3] else "";
    if (std.mem.eql(u8, marker, "root")) {
        if (channel.* != null) return error.DuplicateChannelTag;
        channel.* = parse_channel_root_tag(tag) catch return error.InvalidChannelTag;
        return;
    }
    if (std.mem.eql(u8, marker, "reply")) {
        if (reply.* != null) return error.DuplicateReplyTag;
        reply.* = parse_reply_tag(tag) catch return error.InvalidReplyTag;
    }
}

fn append_reply_pubkey(
    tag: nip01_event.EventTag,
    info: *ChannelMessageInfo,
    out_reply_pubkeys: [][32]u8,
) Nip28Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.reply_pubkey_count <= out_reply_pubkeys.len);

    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidPubkeyTag;
    if (info.reply_pubkey_count == out_reply_pubkeys.len) return error.BufferTooSmall;
    out_reply_pubkeys[info.reply_pubkey_count] = parse_lower_hex_32(tag.items[1]) catch {
        return error.InvalidPubkeyTag;
    };
    info.reply_pubkey_count += 1;
}

fn parse_reason_json(content: []const u8, scratch: std.mem.Allocator) Nip28Error!?[]const u8 {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (content.len == 0) return null;
    const value = std.json.parseFromSliceLeaky(std.json.Value, scratch, content, .{}) catch {
        return error.InvalidReasonJson;
    };
    if (value != .object) return error.InvalidReasonJson;
    const reason_value = value.object.get("reason") orelse return null;
    if (reason_value != .string) return error.InvalidReasonJson;
    return parse_nonempty_utf8(reason_value.string) catch return error.InvalidReasonJson;
}

fn validate_metadata_fields(
    name: ?[]const u8,
    about: ?[]const u8,
    picture: ?[]const u8,
    relays: []const []const u8,
) Nip28Error!void {
    std.debug.assert(relays.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_item_bytes_max > 0);

    if (name) |value| _ = parse_nonempty_utf8(value) catch return error.InvalidMetadataJson;
    if (about) |value| _ = parse_nonempty_utf8(value) catch return error.InvalidMetadataJson;
    if (picture) |value| _ = parse_url(value) catch return error.InvalidMetadataJson;
    for (relays) |relay| _ = parse_url(relay) catch return error.InvalidMetadataJson;
}

fn write_metadata_json(
    writer: anytype,
    name: ?[]const u8,
    about: ?[]const u8,
    picture: ?[]const u8,
    relays: []const []const u8,
) Nip28Error!void {
    std.debug.assert(relays.len <= limits.tag_items_max);
    std.debug.assert(@TypeOf(writer) != void);

    try writer.writeByte('{');
    var needs_comma = false;
    needs_comma = try write_optional_json_string(writer, needs_comma, "name", name);
    needs_comma = try write_optional_json_string(writer, needs_comma, "about", about);
    needs_comma = try write_optional_json_string(writer, needs_comma, "picture", picture);
    if (relays.len != 0) try write_relays_array(writer, relays, &needs_comma);
    try writer.writeByte('}');
}

fn write_optional_json_string(
    writer: anytype,
    needs_comma: bool,
    key: []const u8,
    value: ?[]const u8,
) Nip28Error!bool {
    std.debug.assert(key.len <= limits.tag_item_bytes_max);
    std.debug.assert(@TypeOf(writer) != void);

    if (value == null) return needs_comma;
    if (needs_comma) writer.writeByte(',') catch return error.BufferTooSmall;
    try write_json_string(writer, key);
    writer.writeByte(':') catch return error.BufferTooSmall;
    try write_json_string(writer, value.?);
    return true;
}

fn write_relays_array(writer: anytype, relays: []const []const u8, needs_comma: *bool) Nip28Error!void {
    std.debug.assert(@intFromPtr(needs_comma) != 0);
    std.debug.assert(relays.len <= limits.tag_items_max);

    if (needs_comma.*) writer.writeByte(',') catch return error.BufferTooSmall;
    try write_json_string(writer, "relays");
    writer.writeAll(":[") catch return error.BufferTooSmall;
    for (relays, 0..) |relay, index| {
        if (index != 0) writer.writeByte(',') catch return error.BufferTooSmall;
        try write_json_string(writer, relay);
    }
    writer.writeByte(']') catch return error.BufferTooSmall;
    needs_comma.* = true;
}

fn write_json_string(writer: anytype, text: []const u8) Nip28Error!void {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(@TypeOf(writer) != void);

    writer.writeByte('"') catch return error.BufferTooSmall;
    for (text) |byte| {
        switch (byte) {
            '"' => writer.writeAll("\\\"") catch return error.BufferTooSmall,
            '\\' => writer.writeAll("\\\\") catch return error.BufferTooSmall,
            '\n' => writer.writeAll("\\n") catch return error.BufferTooSmall,
            '\r' => writer.writeAll("\\r") catch return error.BufferTooSmall,
            '\t' => writer.writeAll("\\t") catch return error.BufferTooSmall,
            else => {
                if (byte < 0x20) {
                    writer.print("\\u00{x:0>2}", .{byte}) catch return error.BufferTooSmall;
                } else {
                    writer.writeByte(byte) catch return error.BufferTooSmall;
                }
            },
        }
    }
    writer.writeByte('"') catch return error.BufferTooSmall;
}

fn parse_channel_root_tag(tag: nip01_event.EventTag) error{InvalidTag}!ChannelReference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len < 4 or tag.items.len > 4) return error.InvalidTag;
    if (!std.mem.eql(u8, tag.items[3], "root")) return error.InvalidTag;
    return .{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidTag,
        .relay_hint = parse_optional_url_slot(tag, 2) catch return error.InvalidTag,
    };
}

fn parse_reply_tag(tag: nip01_event.EventTag) error{InvalidTag}!ChannelReference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len < 4 or tag.items.len > 4) return error.InvalidTag;
    if (!std.mem.eql(u8, tag.items[3], "reply")) return error.InvalidTag;
    return .{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidTag,
        .relay_hint = parse_optional_url_slot(tag, 2) catch return error.InvalidTag,
    };
}

fn parse_event_id_tag(tag: nip01_event.EventTag) error{InvalidTag}![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_lower_hex_32(tag.items[1]) catch return error.InvalidTag;
}

fn parse_pubkey_tag(tag: nip01_event.EventTag) error{InvalidTag}![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_lower_hex_32(tag.items[1]) catch return error.InvalidTag;
}

fn parse_optional_url_slot(
    tag: nip01_event.EventTag,
    index: usize,
) error{InvalidTag}!?[]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(index <= limits.tag_items_max);

    if (index >= tag.items.len) return null;
    return parse_url(tag.items[index]) catch return error.InvalidTag;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (text.len == 0) return error.InvalidUrl;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.pubkey_hex_length);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len != limits.pubkey_hex_length) return error.InvalidHex;
    var out: [32]u8 = undefined;
    var index: usize = 0;
    while (index < out.len) : (index += 1) {
        const start = index * 2;
        out[index] = std.fmt.parseUnsigned(u8, text[start .. start + 2], 16) catch {
            return error.InvalidHex;
        };
    }
    if (!std.mem.eql(u8, &std.fmt.bytesToHex(out, .lower), text)) return error.InvalidHex;
    return out;
}

test "NIP-28 extracts channel create metadata" {
    const event = nip01_event.Event{
        .id = [_]u8{0x28} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = channel_create_kind,
        .tags = &.{},
        .content =
            "{\"name\":\"Demo\",\"about\":\"A room\",\"picture\":\"https://img.example/p.png\",\"relays\":[\"wss://relay.one\"]}",
        .sig = [_]u8{0x22} ** 64,
    };
    var relays: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const info = try channel_create_extract(&event, relays[0..], arena.allocator());

    try std.testing.expectEqualStrings("Demo", info.name.?);
    try std.testing.expectEqualStrings("A room", info.about.?);
    try std.testing.expectEqual(@as(u16, 1), info.relay_count);
    try std.testing.expectEqualStrings("wss://relay.one", relays[0]);
}

test "NIP-28 extracts channel update and message linkage" {
    const update_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "wss://relay.one", "root" } },
        .{ .items = &.{ "t", "zig" } },
    };
    const update = nip01_event.Event{
        .id = [_]u8{0x29} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = channel_metadata_kind,
        .tags = update_tags[0..],
        .content = "{\"name\":\"Updated\"}",
        .sig = [_]u8{0x23} ** 64,
    };
    var relays: [0][]const u8 = .{};
    var categories: [1][]const u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const update_info = try channel_metadata_extract(
        &update,
        relays[0..],
        categories[0..],
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("Updated", update_info.metadata.name.?);
    try std.testing.expectEqual(@as(u16, 1), update_info.category_count);

    const message_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "wss://relay.one", "root" } },
        .{ .items = &.{ "e", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "wss://relay.two", "reply" } },
        .{ .items = &.{ "p", "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" } },
    };
    const message = nip01_event.Event{
        .id = [_]u8{0x2a} ** 32,
        .pubkey = [_]u8{0x13} ** 32,
        .created_at = 3,
        .kind = channel_message_kind,
        .tags = message_tags[0..],
        .content = "hello",
        .sig = [_]u8{0x24} ** 64,
    };
    var reply_pubkeys: [1][32]u8 = undefined;

    const message_info = try channel_message_extract(&message, reply_pubkeys[0..]);
    try std.testing.expectEqualStrings("hello", message_info.content);
    try std.testing.expect(message_info.reply != null);
    try std.testing.expectEqual(@as(u16, 1), message_info.reply_pubkey_count);
}

test "NIP-28 extracts moderation targets and builds canonical helpers" {
    const hide_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd" } },
    };
    const hide = nip01_event.Event{
        .id = [_]u8{0x2b} ** 32,
        .pubkey = [_]u8{0x14} ** 32,
        .created_at = 4,
        .kind = hide_message_kind,
        .tags = hide_tags[0..],
        .content = "{\"reason\":\"spam\"}",
        .sig = [_]u8{0x25} ** 64,
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const hide_info = try hide_message_extract(&hide, arena.allocator());
    try std.testing.expectEqualStrings("spam", hide_info.reason.?);

    var json: BuiltJson = .{};
    const reason_json = try channel_build_reason_json(&json, "duplicate");
    try std.testing.expectEqualStrings("{\"reason\":\"duplicate\"}", reason_json);

    var tag: BuiltTag = .{};
    const built = try channel_build_event_tag(
        &tag,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "wss://relay.one",
        .root,
    );
    try std.testing.expectEqualStrings("root", built.items[3]);
}
