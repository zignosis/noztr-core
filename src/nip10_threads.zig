const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const text_note_event_kind: u32 = 1;

const nip10_e_tag_items_max: u8 = 5;
const nip10_marker_bytes_max: u8 = 5;

pub const ThreadError = error{
    InvalidEventKind,
    InvalidETag,
    InvalidEventId,
    InvalidRelayHint,
    InvalidMarker,
    InvalidPubkey,
    DuplicateRootTag,
    DuplicateReplyTag,
    BufferTooSmall,
};

pub const ThreadMarker = enum {
    root,
    reply,
};

pub const ThreadReference = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
    author_pubkey: ?[32]u8 = null,
};

pub const ThreadInfo = struct {
    root: ?ThreadReference = null,
    reply: ?ThreadReference = null,
    mention_count: u16 = 0,
};

const ParsedThreadTag = struct {
    reference: ThreadReference,
    kind: ThreadTagKind = .unmarked,
};

const ThreadTagKind = enum {
    unmarked,
    root,
    reply,
    mention,
};

const TagTail = struct {
    kind: ThreadTagKind = .unmarked,
    author_pubkey: ?[32]u8 = null,
};

const ThreadScan = struct {
    info: ThreadInfo = .{},
    saw_root_or_reply: bool = false,
    explicit_mention_count: u16 = 0,
    unmarked_count: u16 = 0,
    first_unmarked: ?ThreadReference = null,
    last_unmarked: ?ThreadReference = null,
};

/// Parses a NIP-10 thread marker token.
pub fn thread_marker_parse(marker: []const u8) error{InvalidMarker}!ThreadMarker {
    std.debug.assert(marker.len <= limits.tag_item_bytes_max);
    std.debug.assert(nip10_marker_bytes_max == 5);

    if (marker.len > nip10_marker_bytes_max) {
        return error.InvalidMarker;
    }
    if (std.mem.eql(u8, marker, "root")) {
        return .root;
    }
    if (std.mem.eql(u8, marker, "reply")) {
        return .reply;
    }
    return error.InvalidMarker;
}

/// Extracts strict NIP-10 thread references from a kind-1 text note into caller-owned mentions.
pub fn thread_extract(
    event: *const nip01_event.Event,
    mentions_out: []ThreadReference,
) ThreadError!ThreadInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(mentions_out.len <= std.math.maxInt(u16));

    if (event.kind != text_note_event_kind) {
        return error.InvalidEventKind;
    }

    const scan = try scan_thread_tags(event);
    const mention_count = try final_mention_count(scan, mentions_out.len);
    if (scan.saw_root_or_reply) {
        return fill_explicit_mode(event, mentions_out, scan, mention_count);
    }
    return fill_positional_mode(event, mentions_out, scan, mention_count);
}

fn apply_marked_reference(
    info: *ThreadInfo,
    marker: ThreadMarker,
    reference: ThreadReference,
) ThreadError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromEnum(marker) <= @intFromEnum(ThreadMarker.reply));

    if (marker == .root) {
        if (info.root != null) {
            return error.DuplicateRootTag;
        }
        info.root = reference;
        return;
    }
    if (info.reply != null) {
        return error.DuplicateReplyTag;
    }
    info.reply = reference;
}

fn parse_thread_tag(tag: nip01_event.EventTag) ThreadError!?ParsedThreadTag {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(nip10_e_tag_items_max == 5);

    if (tag.items.len == 0) {
        return error.InvalidETag;
    }
    if (!std.mem.eql(u8, tag.items[0], "e")) {
        return null;
    }
    if (tag.items.len < 2) {
        return error.InvalidETag;
    }
    if (tag.items.len > nip10_e_tag_items_max) {
        return error.InvalidETag;
    }

    const event_id = parse_lower_hex_32(tag.items[1]) catch {
        return error.InvalidEventId;
    };
    var relay_hint: ?[]const u8 = null;
    if (tag.items.len >= 3) {
        relay_hint = parse_optional_hint(tag.items[2]) catch {
            return error.InvalidRelayHint;
        };
    }
    const parsed_tail = try parse_tag_tail(tag);

    return .{
        .reference = .{
            .event_id = event_id,
            .relay_hint = relay_hint,
            .author_pubkey = parsed_tail.author_pubkey,
        },
        .kind = parsed_tail.kind,
    };
}

fn parse_tag_tail(tag: nip01_event.EventTag) ThreadError!TagTail {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(nip10_e_tag_items_max == 5);

    var tag_3: ?[]const u8 = null;
    if (tag.items.len >= 4 and tag.items[3].len > 0) {
        tag_3 = tag.items[3];
    }
    var tag_4: ?[]const u8 = null;
    if (tag.items.len >= 5 and tag.items[4].len > 0) {
        tag_4 = tag.items[4];
    }

    var parsed = TagTail{};
    if (tag_3 != null and std.mem.eql(u8, tag_3.?, "mention")) {
        parsed.kind = .mention;
        if (tag_4 != null) {
            parsed.author_pubkey = try parse_pubkey(tag_4.?);
        }
        return parsed;
    }
    if (tag_3 != null and tag_4 != null) {
        parsed.kind = marker_kind(thread_marker_parse(tag_3.?) catch return error.InvalidMarker);
        parsed.author_pubkey = try parse_pubkey(tag_4.?);
        return parsed;
    }
    if (tag_3 != null and tag_4 == null) {
        const maybe_marker = thread_marker_parse(tag_3.?) catch null;
        if (maybe_marker) |marker| {
            parsed.kind = marker_kind(marker);
            return parsed;
        }
        parsed.author_pubkey = parse_pubkey(tag_3.?) catch return error.InvalidMarker;
        return parsed;
    }
    if (tag_3 == null and tag_4 != null) {
        parsed.author_pubkey = try parse_pubkey(tag_4.?);
    }
    return parsed;
}

fn marker_kind(marker: ThreadMarker) ThreadTagKind {
    std.debug.assert(@intFromEnum(marker) <= @intFromEnum(ThreadMarker.reply));
    std.debug.assert(@intFromEnum(ThreadTagKind.mention) == 3);

    return switch (marker) {
        .root => .root,
        .reply => .reply,
    };
}

fn scan_thread_tags(event: *const nip01_event.Event) ThreadError!ThreadScan {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    var scan = ThreadScan{};
    for (event.tags) |tag| {
        const parsed = try parse_thread_tag(tag);
        if (parsed == null) {
            continue;
        }
        switch (parsed.?.kind) {
            .root => {
                scan.saw_root_or_reply = true;
                try apply_marked_reference(&scan.info, .root, parsed.?.reference);
            },
            .reply => {
                scan.saw_root_or_reply = true;
                try apply_marked_reference(&scan.info, .reply, parsed.?.reference);
            },
            .mention => scan.explicit_mention_count += 1,
            .unmarked => {
                scan.unmarked_count += 1;
                if (scan.first_unmarked == null) {
                    scan.first_unmarked = parsed.?.reference;
                }
                scan.last_unmarked = parsed.?.reference;
            },
        }
    }
    return scan;
}

fn final_mention_count(scan: ThreadScan, output_len: usize) ThreadError!u16 {
    std.debug.assert(output_len <= std.math.maxInt(u16));
    std.debug.assert(scan.explicit_mention_count <= limits.tags_max);

    var count = scan.explicit_mention_count;
    if (scan.saw_root_or_reply) {
        count += scan.unmarked_count;
    } else if (scan.unmarked_count > 2) {
        count += scan.unmarked_count - 2;
    }
    if (count > output_len) {
        return error.BufferTooSmall;
    }
    return count;
}

fn fill_explicit_mode(
    event: *const nip01_event.Event,
    mentions_out: []ThreadReference,
    scan: ThreadScan,
    mention_count: u16,
) ThreadError!ThreadInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(mention_count <= mentions_out.len);

    var info = scan.info;
    var write_index: u16 = 0;
    for (event.tags) |tag| {
        const parsed = try parse_thread_tag(tag);
        if (parsed == null) {
            continue;
        }
        if (parsed.?.kind == .root or parsed.?.kind == .reply) {
            continue;
        }
        mentions_out[write_index] = parsed.?.reference;
        write_index += 1;
    }
    info.mention_count = mention_count;
    if (info.root != null and info.reply == null) {
        info.reply = info.root;
    }
    return info;
}

fn fill_positional_mode(
    event: *const nip01_event.Event,
    mentions_out: []ThreadReference,
    scan: ThreadScan,
    mention_count: u16,
) ThreadError!ThreadInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(mention_count <= mentions_out.len);

    var info = scan.info;
    if (scan.unmarked_count != 0) {
        info.root = scan.first_unmarked;
        info.reply = scan.last_unmarked;
    }
    if (scan.unmarked_count == 1) {
        info.reply = scan.first_unmarked;
    }

    var write_index: u16 = 0;
    var unmarked_index: u16 = 0;
    for (event.tags) |tag| {
        const parsed = try parse_thread_tag(tag);
        if (parsed == null) {
            continue;
        }
        if (parsed.?.kind == .mention) {
            mentions_out[write_index] = parsed.?.reference;
            write_index += 1;
            continue;
        }
        if (parsed.?.kind != .unmarked) {
            continue;
        }
        if (is_unmarked_mention(unmarked_index, scan.unmarked_count)) {
            mentions_out[write_index] = parsed.?.reference;
            write_index += 1;
        }
        unmarked_index += 1;
    }
    info.mention_count = mention_count;
    return info;
}

fn is_unmarked_mention(index: u16, total_count: u16) bool {
    std.debug.assert(index < total_count or total_count == 0);
    std.debug.assert(total_count <= limits.tags_max);

    if (total_count <= 2) {
        return false;
    }
    return index != 0 and index + 1 != total_count;
}

fn parse_pubkey(text: []const u8) ThreadError![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return parse_lower_hex_32(text) catch {
        return error.InvalidPubkey;
    };
}

fn parse_optional_hint(text: []const u8) error{InvalidHint}!?[]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    if (text.len == 0) {
        return null;
    }
    if (!std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidHint;
    }
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.id_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn thread_event(tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(text_note_event_kind == 1);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = text_note_event_kind,
        .created_at = 0,
        .content = "",
        .tags = tags,
    };
}

test "thread marker parse accepts root and reply" {
    try std.testing.expectEqual(ThreadMarker.root, try thread_marker_parse("root"));
    try std.testing.expectEqual(ThreadMarker.reply, try thread_marker_parse("reply"));
}

test "thread extract marked root-only reply infers direct reply" {
    const root_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "wss://relay.root",
        "root",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = root_tag[0..] }};
    const event = thread_event(tags[0..]);
    var mentions: [1]ThreadReference = undefined;

    const parsed = try thread_extract(&event, mentions[0..]);

    try std.testing.expect(parsed.root != null);
    try std.testing.expect(parsed.reply != null);
    try std.testing.expect(parsed.root.?.event_id[0] == 0x11);
    try std.testing.expect(parsed.reply.?.event_id[0] == 0x11);
    try std.testing.expectEqualStrings("wss://relay.root", parsed.root.?.relay_hint.?);
    try std.testing.expect(parsed.root.?.author_pubkey.?[0] == 0xaa);
    try std.testing.expectEqual(@as(u16, 0), parsed.mention_count);
}

test "thread extract marked tags keep unmarked mentions and empty hints absent" {
    const root_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "",
        "root",
    };
    const reply_tag = [_][]const u8{
        "e",
        "2222222222222222222222222222222222222222222222222222222222222222",
        "wss://relay.reply",
        "reply",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    };
    const mention_tag = [_][]const u8{
        "e",
        "3333333333333333333333333333333333333333333333333333333333333333",
        "",
        "",
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = root_tag[0..] },
        .{ .items = mention_tag[0..] },
        .{ .items = reply_tag[0..] },
    };
    const event = thread_event(tags[0..]);
    var mentions: [2]ThreadReference = undefined;

    const parsed = try thread_extract(&event, mentions[0..]);

    try std.testing.expect(parsed.root != null);
    try std.testing.expect(parsed.reply != null);
    try std.testing.expect(parsed.root.?.relay_hint == null);
    try std.testing.expect(parsed.reply.?.event_id[0] == 0x22);
    try std.testing.expect(parsed.reply.?.author_pubkey.?[0] == 0xbb);
    try std.testing.expectEqual(@as(u16, 1), parsed.mention_count);
    try std.testing.expect(mentions[0].event_id[0] == 0x33);
    try std.testing.expect(mentions[0].relay_hint == null);
    try std.testing.expect(mentions[0].author_pubkey.?[0] == 0xcc);
}

test "thread extract accepts 4-slot pubkey fallback in canonical thread reference" {
    const widened_tag = [_][]const u8{
        "e",
        "3333333333333333333333333333333333333333333333333333333333333333",
        "",
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    };
    var mentions: [1]ThreadReference = undefined;

    const parsed = try thread_extract(&thread_event(&.{.{ .items = widened_tag[0..] }}), mentions[0..]);

    try std.testing.expect(parsed.root != null);
    try std.testing.expect(parsed.reply != null);
    try std.testing.expect(parsed.root.?.event_id[0] == 0x33);
    try std.testing.expect(parsed.reply.?.author_pubkey.?[0] == 0xcc);
    try std.testing.expectEqual(@as(u16, 0), parsed.mention_count);
}

test "thread extract positional fallback resolves root mentions and reply" {
    const root_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const mention_tag = [_][]const u8{
        "e",
        "2222222222222222222222222222222222222222222222222222222222222222",
    };
    const reply_tag = [_][]const u8{
        "e",
        "3333333333333333333333333333333333333333333333333333333333333333",
        "wss://relay.reply",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = root_tag[0..] },
        .{ .items = mention_tag[0..] },
        .{ .items = reply_tag[0..] },
    };
    const event = thread_event(tags[0..]);
    var mentions: [3]ThreadReference = undefined;

    const parsed = try thread_extract(&event, mentions[0..]);

    try std.testing.expect(parsed.root != null);
    try std.testing.expect(parsed.reply != null);
    try std.testing.expect(parsed.root.?.event_id[0] == 0x11);
    try std.testing.expect(parsed.reply.?.event_id[0] == 0x33);
    try std.testing.expectEqualStrings("wss://relay.reply", parsed.reply.?.relay_hint.?);
    try std.testing.expectEqual(@as(u16, 1), parsed.mention_count);
    try std.testing.expect(mentions[0].event_id[0] == 0x22);
}

test "thread extract positional fallback with one e tag uses same root and reply" {
    const reply_tag = [_][]const u8{
        "e",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = reply_tag[0..] }};
    const event = thread_event(tags[0..]);
    var mentions: [1]ThreadReference = undefined;

    const parsed = try thread_extract(&event, mentions[0..]);

    try std.testing.expect(parsed.root != null);
    try std.testing.expect(parsed.reply != null);
    try std.testing.expect(parsed.root.?.event_id[0] == 0xaa);
    try std.testing.expect(parsed.reply.?.event_id[0] == 0xaa);
    try std.testing.expectEqual(@as(u16, 0), parsed.mention_count);
}

test "thread extract handles legacy mention marker as mention-only reference" {
    const mention_tag = [_][]const u8{
        "e",
        "9999999999999999999999999999999999999999999999999999999999999999",
        "",
        "mention",
        "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
    };
    var mentions: [1]ThreadReference = undefined;

    const parsed = try thread_extract(&thread_event(&.{.{ .items = mention_tag[0..] }}), mentions[0..]);

    try std.testing.expect(parsed.root == null);
    try std.testing.expect(parsed.reply == null);
    try std.testing.expectEqual(@as(u16, 1), parsed.mention_count);
    try std.testing.expect(mentions[0].event_id[0] == 0x99);
    try std.testing.expect(mentions[0].author_pubkey.?[0] == 0xdd);
}

test "thread extract rejects wrong kind and duplicate root tags" {
    const root_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "",
        "root",
    };
    const duplicate_root_tags = [_]nip01_event.EventTag{
        .{ .items = root_tag[0..] },
        .{ .items = root_tag[0..] },
    };
    const root_tags = [_]nip01_event.EventTag{.{ .items = root_tag[0..] }};
    var out: [2]ThreadReference = undefined;

    try std.testing.expectError(error.DuplicateRootTag, thread_extract(&thread_event(
        duplicate_root_tags[0..],
    ), out[0..]));

    try std.testing.expectError(
        error.InvalidEventKind,
        thread_extract(
            &.{
                .id = [_]u8{0} ** 32,
                .pubkey = [_]u8{0} ** 32,
                .sig = [_]u8{0} ** 64,
                .kind = 42,
                .created_at = 0,
                .content = "",
                .tags = root_tags[0..],
            },
            out[0..],
        ),
    );
}

test "thread extract rejects malformed tags and output overflow" {
    const bad_id_tag = [_][]const u8{ "e", "xyz" };
    const bad_pubkey_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "",
        "",
        "xyz",
    };
    const too_many_items_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "",
        "",
        "",
        "extra",
    };
    const good_tag = [_][]const u8{
        "e",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const overflow_tags = [_]nip01_event.EventTag{
        .{ .items = good_tag[0..] },
        .{ .items = good_tag[0..] },
        .{ .items = good_tag[0..] },
        .{ .items = good_tag[0..] },
    };
    var out: [1]ThreadReference = undefined;

    try std.testing.expectError(
        error.InvalidEventId,
        thread_extract(&thread_event(&.{.{ .items = bad_id_tag[0..] }}), out[0..]),
    );
    try std.testing.expectError(
        error.InvalidPubkey,
        thread_extract(&thread_event(&.{.{ .items = bad_pubkey_tag[0..] }}), out[0..]),
    );
    try std.testing.expectError(
        error.InvalidETag,
        thread_extract(&thread_event(&.{.{ .items = too_many_items_tag[0..] }}), out[0..]),
    );
    try std.testing.expectError(
        error.BufferTooSmall,
        thread_extract(&thread_event(overflow_tags[0..]), out[0..]),
    );
}
