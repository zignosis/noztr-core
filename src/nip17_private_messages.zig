const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip59_wrap = @import("nip59_wrap.zig");

pub const dm_kind: u32 = 14;
pub const dm_relays_kind: u32 = 10050;

pub const Nip17RelayListError = error{
    InvalidRelayListKind,
    InvalidRelayTag,
    InvalidRelayUrl,
    BufferTooSmall,
};

pub const Nip17Error = nip59_wrap.WrapError || error{
    InvalidMessageKind,
    InvalidRecipientTag,
    MissingRecipientTag,
    InvalidReplyTag,
    DuplicateReplyTag,
    InvalidSubjectTag,
    BufferTooSmall,
} || Nip17RelayListError;

pub const DmRecipient = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const DmReplyRef = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const DmMessageInfo = struct {
    recipients: []const DmRecipient,
    subject: ?[]const u8 = null,
    reply_to: ?DmReplyRef = null,
    content: []const u8,
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

/// Parse a kind-14 NIP-17 direct message event.
pub fn nip17_message_parse(
    event: *const nip01_event.Event,
    recipients_out: []DmRecipient,
) Nip17Error!DmMessageInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(recipients_out.len <= limits.tags_max);

    if (event.kind != dm_kind) return error.InvalidMessageKind;
    if (!std.unicode.utf8ValidateSlice(event.content)) return error.InvalidMessageKind;

    var info = DmMessageInfo{
        .recipients = recipients_out[0..0],
        .content = event.content,
    };
    var count: u16 = 0;
    for (event.tags) |tag| {
        try parse_message_tag(tag, &info, recipients_out, &count);
    }
    if (count == 0) return error.MissingRecipientTag;
    info.recipients = recipients_out[0..count];
    return info;
}

/// Unwrap a gift wrap and parse the inner kind-14 direct message rumor.
pub fn nip17_unwrap_message(
    output_rumor: *nip01_event.Event,
    recipient_private_key: *const [32]u8,
    wrap_event: *const nip01_event.Event,
    recipients_out: []DmRecipient,
    scratch: std.mem.Allocator,
) Nip17Error!DmMessageInfo {
    std.debug.assert(@intFromPtr(output_rumor) != 0);
    std.debug.assert(@intFromPtr(recipient_private_key) != 0);

    try nip59_wrap.nip59_unwrap(output_rumor, recipient_private_key, wrap_event, scratch);
    return nip17_message_parse(output_rumor, recipients_out);
}

/// Extract ordered relay URLs from a kind-10050 relay list event.
pub fn nip17_relay_list_extract(
    event: *const nip01_event.Event,
    out: [][]const u8,
) Nip17RelayListError!u16 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out.len <= limits.tags_max);

    if (event.kind != dm_relays_kind) return error.InvalidRelayListKind;

    var count: u16 = 0;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "relay")) continue;
        const relay_url = parse_relay_tag(tag) catch return error.InvalidRelayTag;
        if (count == out.len) return error.BufferTooSmall;
        out[count] = relay_url;
        count += 1;
    }
    return count;
}

/// Build a canonical `p` tag for a NIP-17 recipient.
pub fn nip17_build_recipient_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
) Nip17Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(pubkey_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidRecipientTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] =
            (parse_optional_url(value) catch return error.InvalidRecipientTag) orelse
            return error.InvalidRecipientTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Build a canonical `relay` tag for a kind-10050 relay list.
pub fn nip17_build_relay_tag(
    output: *BuiltTag,
    relay_url: []const u8,
) Nip17RelayListError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(relay_url.len <= limits.tag_item_bytes_max);

    output.items[0] = "relay";
    output.items[1] = parse_url(relay_url) catch return error.InvalidRelayUrl;
    output.item_count = 2;
    return output.as_event_tag();
}

fn parse_message_tag(
    tag: nip01_event.EventTag,
    info: *DmMessageInfo,
    recipients_out: []DmRecipient,
    count: *u16,
) Nip17Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "p")) return parse_recipient_tag(tag, recipients_out, count);
    if (std.mem.eql(u8, tag.items[0], "e")) return parse_reply_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "subject")) return parse_subject_tag(tag, info);
}

fn parse_recipient_tag(
    tag: nip01_event.EventTag,
    recipients_out: []DmRecipient,
    count: *u16,
) Nip17Error!void {
    std.debug.assert(@intFromPtr(count) != 0);
    std.debug.assert(recipients_out.len <= limits.tags_max);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidRecipientTag;
    if (count.* == recipients_out.len) return error.BufferTooSmall;
    recipients_out[count.*] = .{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidRecipientTag,
        .relay_hint = null,
    };
    if (tag.items.len == 3) {
        recipients_out[count.*].relay_hint =
            parse_optional_url(tag.items[2]) catch return error.InvalidRecipientTag;
    }
    count.* += 1;
}

fn parse_reply_tag(tag: nip01_event.EventTag, info: *DmMessageInfo) Nip17Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (info.reply_to != null) return error.DuplicateReplyTag;
    if (tag.items.len < 2 or tag.items.len > 5) return error.InvalidReplyTag;

    var reply = DmReplyRef{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidReplyTag,
    };
    if (tag.items.len >= 3) {
        if (std.mem.eql(u8, tag.items[2], "reply")) {
            if (tag.items.len != 3) return error.InvalidReplyTag;
            info.reply_to = reply;
            return;
        }
        reply.relay_hint = parse_optional_url(tag.items[2]) catch return error.InvalidReplyTag;
    }
    if (tag.items.len == 4) {
        try validate_reply_suffix(tag.items[3]);
    }
    if (tag.items.len == 5) {
        if (!std.mem.eql(u8, tag.items[3], "reply")) return error.InvalidReplyTag;
        _ = parse_lower_hex_32(tag.items[4]) catch return error.InvalidReplyTag;
    }
    info.reply_to = reply;
}

fn parse_subject_tag(tag: nip01_event.EventTag, info: *DmMessageInfo) Nip17Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidSubjectTag;
    if (!std.unicode.utf8ValidateSlice(tag.items[1])) return error.InvalidSubjectTag;
    info.subject = tag.items[1];
}

fn parse_relay_tag(tag: nip01_event.EventTag) error{InvalidTag}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidTag;
    return parse_url(tag.items[1]) catch return error.InvalidTag;
}

fn parse_optional_url(text: []const u8) error{InvalidUrl}!?[]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return null;
    const parsed = try parse_url(text);
    return parsed;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    var output: [32]u8 = undefined;
    if (text.len != limits.id_hex_length) return error.InvalidHex;
    try validate_lower_hex(text);
    _ = std.fmt.hexToBytes(&output, text) catch return error.InvalidHex;
    return output;
}

fn validate_lower_hex(text: []const u8) error{InvalidHex}!void {
    std.debug.assert(text.len <= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    for (text) |byte| {
        if (byte >= '0' and byte <= '9') continue;
        if (byte >= 'a' and byte <= 'f') continue;
        return error.InvalidHex;
    }
}

fn validate_reply_suffix(text: []const u8) Nip17Error!void {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (std.mem.eql(u8, text, "reply")) return;
    _ = parse_lower_hex_32(text) catch return error.InvalidReplyTag;
}

fn test_event(
    kind: u32,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(content.len <= limits.content_bytes_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .created_at = 1,
        .kind = kind,
        .tags = tags,
        .content = content,
        .sig = [_]u8{0} ** 64,
    };
}

test "nip17 message parse extracts recipients subject and reply" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "wss://relay.example",
        } },
        .{ .items = &.{
            "e",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "",
            "reply",
        } },
        .{ .items = &.{ "subject", "Topic" } },
        .{ .items = &.{ "q", "ignored" } },
    };
    var recipients: [2]DmRecipient = undefined;

    const parsed = try nip17_message_parse(&test_event(dm_kind, "hello", tags[0..]), recipients[0..]);

    try std.testing.expectEqual(@as(usize, 1), parsed.recipients.len);
    try std.testing.expectEqualStrings("Topic", parsed.subject.?);
    try std.testing.expectEqualStrings("hello", parsed.content);
    try std.testing.expect(parsed.reply_to != null);
    try std.testing.expectEqualStrings("wss://relay.example", parsed.recipients[0].relay_hint.?);
}

test "nip17 message parse accepts long-form standard reply e tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
        .{ .items = &.{
            "e",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "",
            "reply",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };
    var recipients: [1]DmRecipient = undefined;

    const parsed = try nip17_message_parse(&test_event(dm_kind, "hello", tags[0..]), recipients[0..]);

    try std.testing.expectEqual(@as(usize, 1), parsed.recipients.len);
    try std.testing.expect(parsed.reply_to != null);
    try std.testing.expect(parsed.reply_to.?.relay_hint == null);
}

test "nip17 message parse rejects malformed message tags" {
    const no_recipient = [_]nip01_event.EventTag{.{ .items = &.{ "subject", "x" } }};
    const bad_recipient = [_]nip01_event.EventTag{.{ .items = &.{ "p", "bad" } }};
    const bad_reply = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" } },
        .{ .items = &.{ "e", "bad", "reply" } },
    };
    var recipients: [1]DmRecipient = undefined;

    try std.testing.expectError(
        error.MissingRecipientTag,
        nip17_message_parse(&test_event(dm_kind, "x", no_recipient[0..]), recipients[0..]),
    );
    try std.testing.expectError(
        error.InvalidRecipientTag,
        nip17_message_parse(&test_event(dm_kind, "x", bad_recipient[0..]), recipients[0..]),
    );
    try std.testing.expectError(
        error.InvalidReplyTag,
        nip17_message_parse(&test_event(dm_kind, "x", bad_reply[0..]), recipients[0..]),
    );
}

test "nip17 relay list extract keeps ordered relay tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "relay", "wss://relay.one" } },
        .{ .items = &.{ "name", "ignored" } },
        .{ .items = &.{ "relay", "wss://relay.two" } },
    };
    var relays: [2][]const u8 = undefined;

    const count = try nip17_relay_list_extract(&test_event(dm_relays_kind, "", tags[0..]), relays[0..]);

    try std.testing.expectEqual(@as(u16, 2), count);
    try std.testing.expectEqualStrings("wss://relay.one", relays[0]);
    try std.testing.expectEqualStrings("wss://relay.two", relays[1]);
}

test "nip17 builders emit canonical recipient and relay tags" {
    var recipient_tag: BuiltTag = .{};
    var relay_tag: BuiltTag = .{};

    const built_recipient = try nip17_build_recipient_tag(
        &recipient_tag,
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        "wss://relay.example",
    );
    const built_relay = try nip17_build_relay_tag(&relay_tag, "wss://relay.example");

    try std.testing.expectEqualStrings("p", built_recipient.items[0]);
    try std.testing.expectEqualStrings("wss://relay.example", built_recipient.items[2]);
    try std.testing.expectEqualStrings("relay", built_relay.items[0]);
    try std.testing.expectEqualStrings("wss://relay.example", built_relay.items[1]);
}
