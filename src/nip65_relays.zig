const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const relay_origin = @import("internal/relay_origin.zig");

pub const RelaysError = error{
    InvalidEventKind,
    InvalidRelayTag,
    InvalidRelayUrl,
    InvalidMarker,
    BufferTooSmall,
};

pub const RelayMarker = enum {
    read,
    write,
    both,
};

pub const RelayPermission = struct {
    relay_url: []const u8,
    marker: RelayMarker,
};

/// Parses a NIP-65 marker token (`""`, `"read"`, or `"write"`).
pub fn relay_marker_parse(marker: []const u8) error{InvalidMarker}!RelayMarker {
    std.debug.assert(limits.nip65_marker_bytes_max == 5);
    std.debug.assert(@sizeOf(RelayMarker) > 0);

    if (marker.len > limits.nip65_marker_bytes_max) {
        return error.InvalidMarker;
    }

    if (marker.len == 0) {
        return .both;
    }
    if (std.mem.eql(u8, marker, "read")) {
        return .read;
    }
    if (std.mem.eql(u8, marker, "write")) {
        return .write;
    }
    return error.InvalidMarker;
}

/// Extracts strict kind-10002 relay permissions from `r` tags into caller-owned output.
///
/// Lifetime and ownership:
/// - `RelayPermission.marker` is copied into `out`.
/// - `RelayPermission.relay_url` borrows from `event.tags` item storage.
/// - Keep `event` and its tag item backing storage alive and unmodified while using `out`.
pub fn relay_list_extract(
    event: *const nip01_event.Event,
    out: []RelayPermission,
) RelaysError!u16 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out.len <= std.math.maxInt(u16));

    if (event.kind != 10002) {
        return error.InvalidEventKind;
    }
    if (event.tags.len > limits.nip65_relays_max) {
        return error.InvalidRelayTag;
    }

    var count: u16 = 0;
    var tag_index: usize = 0;
    while (tag_index < event.tags.len) : (tag_index += 1) {
        const parsed = try parse_relay_tag(event.tags[tag_index]);
        const existing_index = find_existing_relay(out[0..count], parsed.origin);
        if (existing_index) |index| {
            out[index].marker = merge_relay_marker(out[index].marker, parsed.permission.marker);
            continue;
        }
        if (count == out.len) {
            return error.BufferTooSmall;
        }

        out[count] = parsed.permission;
        count += 1;
    }
    return count;
}

const ParsedRelayTag = struct {
    permission: RelayPermission,
    origin: relay_origin.WebsocketOrigin,
};

fn parse_relay_tag(tag: nip01_event.EventTag) RelaysError!ParsedRelayTag {
    std.debug.assert(limits.nip65_relay_tag_items_max == 3);
    std.debug.assert(@sizeOf(nip01_event.EventTag) > 0);

    if (tag.items.len > limits.nip65_relay_tag_items_max) {
        return error.InvalidRelayTag;
    }

    if (tag.items.len < 2) {
        return error.InvalidRelayTag;
    }
    if (tag.items.len > 3) {
        return error.InvalidRelayTag;
    }
    if (!std.mem.eql(u8, tag.items[0], "r")) {
        return error.InvalidRelayTag;
    }

    const relay_url = tag.items[1];
    if (relay_url.len > limits.nip65_relay_url_bytes_max) {
        return error.InvalidRelayUrl;
    }
    const parsed_origin = try relay_url_validate(relay_url);

    const marker = if (tag.items.len == 2)
        RelayMarker.both
    else blk: {
        if (tag.items[2].len > limits.nip65_marker_bytes_max) {
            return error.InvalidMarker;
        }
        const parsed_marker = relay_marker_parse(tag.items[2]) catch return error.InvalidMarker;
        break :blk parsed_marker;
    };

    return .{
        .permission = .{ .relay_url = relay_url, .marker = marker },
        .origin = parsed_origin,
    };
}

fn find_existing_relay(items: []const RelayPermission, incoming: relay_origin.WebsocketOrigin) ?u16 {
    std.debug.assert(items.len <= std.math.maxInt(u16));
    std.debug.assert(incoming.scheme.len > 0);

    var index: u16 = 0;
    while (index < items.len) : (index += 1) {
        const existing_maybe = relay_origin.parse_websocket_origin(items[index].relay_url);
        std.debug.assert(existing_maybe != null);
        const existing = existing_maybe orelse {
            return null;
        };
        if (relay_origin.websocket_origins_equal(existing, incoming)) {
            return index;
        }
    }
    return null;
}

fn merge_relay_marker(current: RelayMarker, incoming: RelayMarker) RelayMarker {
    std.debug.assert(@intFromEnum(current) <= @intFromEnum(RelayMarker.both));
    std.debug.assert(@intFromEnum(incoming) <= @intFromEnum(RelayMarker.both));

    if (current == .both) {
        return .both;
    }
    if (incoming == .both) {
        return .both;
    }
    if (current == incoming) {
        return current;
    }
    return .both;
}

fn relay_url_validate(url: []const u8) RelaysError!relay_origin.WebsocketOrigin {
    std.debug.assert(url.len <= limits.nip65_relay_url_bytes_max);
    std.debug.assert(@sizeOf(relay_origin.WebsocketOrigin) > 0);

    if (url.len == 0) {
        return error.InvalidRelayUrl;
    }
    if (has_forbidden_url_byte(url)) {
        return error.InvalidRelayUrl;
    }

    const origin = relay_origin.parse_websocket_origin(url) orelse {
        return error.InvalidRelayUrl;
    };
    if (origin.port == 0) {
        return error.InvalidRelayUrl;
    }
    return origin;
}

fn has_forbidden_url_byte(url: []const u8) bool {
    std.debug.assert(url.len <= limits.nip65_relay_url_bytes_max);
    std.debug.assert(url.len >= 0);

    for (url) |byte| {
        if (byte <= 0x20) {
            return true;
        }
        if (byte == '\\') {
            return true;
        }
    }
    return false;
}

fn build_event(kind: u32, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
    std.debug.assert(tags.len <= std.math.maxInt(u16));

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 0,
        .content = "",
        .tags = tags,
    };
}

test "relay marker parse accepts valid tokens" {
    try std.testing.expectEqual(RelayMarker.both, try relay_marker_parse(""));
    try std.testing.expectEqual(RelayMarker.read, try relay_marker_parse("read"));
    try std.testing.expectEqual(RelayMarker.write, try relay_marker_parse("write"));
}

test "relay list extract valid vectors and deterministic dedupe merge" {
    const tag_a = [_][]const u8{ "r", "wss://relay.one" };
    const tag_b = [_][]const u8{ "r", "wss://relay.two", "read" };
    const tag_c = [_][]const u8{ "r", "ws://relay.three:80/path", "write" };
    const tags_valid = [_]nip01_event.EventTag{
        .{ .items = tag_a[0..] },
        .{ .items = tag_b[0..] },
        .{ .items = tag_c[0..] },
    };
    const event_valid = build_event(10002, tags_valid[0..]);

    var out_valid: [3]RelayPermission = undefined;
    const count_valid = try relay_list_extract(&event_valid, out_valid[0..]);
    try std.testing.expectEqual(@as(u16, 3), count_valid);
    try std.testing.expectEqualStrings("wss://relay.one", out_valid[0].relay_url);
    try std.testing.expectEqual(RelayMarker.both, out_valid[0].marker);
    try std.testing.expectEqual(RelayMarker.read, out_valid[1].marker);
    try std.testing.expectEqual(RelayMarker.write, out_valid[2].marker);

    const tag_d1 = [_][]const u8{ "r", "wss://relay.alpha", "read" };
    const tag_d2 = [_][]const u8{ "r", "wss://relay.beta", "write" };
    const tag_d3 = [_][]const u8{ "r", "wss://relay.beta", "read" };
    const tag_d4 = [_][]const u8{ "r", "wss://relay.alpha", "write" };
    const tags_dedupe = [_]nip01_event.EventTag{
        .{ .items = tag_d1[0..] },
        .{ .items = tag_d2[0..] },
        .{ .items = tag_d3[0..] },
        .{ .items = tag_d4[0..] },
    };
    const event_dedupe = build_event(10002, tags_dedupe[0..]);

    var out_dedupe: [2]RelayPermission = undefined;
    const count_dedupe = try relay_list_extract(&event_dedupe, out_dedupe[0..]);
    try std.testing.expectEqual(@as(u16, 2), count_dedupe);
    try std.testing.expectEqualStrings("wss://relay.alpha", out_dedupe[0].relay_url);
    try std.testing.expectEqualStrings("wss://relay.beta", out_dedupe[1].relay_url);
    try std.testing.expectEqual(RelayMarker.both, out_dedupe[0].marker);
    try std.testing.expectEqual(RelayMarker.both, out_dedupe[1].marker);

    const tag_n1 = [_][]const u8{ "r", "wss://relay.norm", "read" };
    const tag_n2 = [_][]const u8{ "r", "WSS://RELAY.NORM:443/?x=1#f", "write" };
    const tag_n3 = [_][]const u8{ "r", "ws://[2001:db8::7]", "read" };
    const tag_n4 = [_][]const u8{ "r", "ws://[2001:db8::7]:80/#q", "write" };
    const tags_normalized = [_]nip01_event.EventTag{
        .{ .items = tag_n1[0..] },
        .{ .items = tag_n2[0..] },
        .{ .items = tag_n3[0..] },
        .{ .items = tag_n4[0..] },
    };
    const event_normalized = build_event(10002, tags_normalized[0..]);

    var out_normalized: [2]RelayPermission = undefined;
    const count_normalized = try relay_list_extract(&event_normalized, out_normalized[0..]);
    try std.testing.expectEqual(@as(u16, 2), count_normalized);
    try std.testing.expectEqualStrings("wss://relay.norm", out_normalized[0].relay_url);
    try std.testing.expectEqualStrings("ws://[2001:db8::7]", out_normalized[1].relay_url);
    try std.testing.expectEqual(RelayMarker.both, out_normalized[0].marker);
    try std.testing.expectEqual(RelayMarker.both, out_normalized[1].marker);
}

test "relay list extract invalid vectors reject unknown marker malformed url and wrong kind" {
    const tag_unknown_marker_items = [_][]const u8{ "r", "wss://relay.one", "both" };
    const tags_unknown_marker = [_]nip01_event.EventTag{
        .{ .items = tag_unknown_marker_items[0..] },
    };
    const event_unknown_marker = build_event(10002, tags_unknown_marker[0..]);
    var out_single: [1]RelayPermission = undefined;
    try std.testing.expectError(
        error.InvalidMarker,
        relay_list_extract(&event_unknown_marker, out_single[0..]),
    );

    const tag_bad_url_items = [_][]const u8{ "r", "wss://:443" };
    const tags_bad_url = [_]nip01_event.EventTag{.{ .items = tag_bad_url_items[0..] }};
    const event_bad_url = build_event(10002, tags_bad_url[0..]);
    try std.testing.expectError(
        error.InvalidRelayUrl,
        relay_list_extract(&event_bad_url, out_single[0..]),
    );

    const tag_zero_port_items = [_][]const u8{ "r", "wss://relay.zero:0" };
    const tags_zero_port = [_]nip01_event.EventTag{.{ .items = tag_zero_port_items[0..] }};
    const event_zero_port = build_event(10002, tags_zero_port[0..]);
    try std.testing.expectError(
        error.InvalidRelayUrl,
        relay_list_extract(&event_zero_port, out_single[0..]),
    );

    var too_long_url: [limits.nip65_relay_url_bytes_max + 1]u8 = undefined;
    @memset(too_long_url[0..], 'a');
    too_long_url[0] = 'w';
    too_long_url[1] = 's';
    too_long_url[2] = 's';
    too_long_url[3] = ':';
    too_long_url[4] = '/';
    too_long_url[5] = '/';
    const tag_long_url_items = [_][]const u8{ "r", too_long_url[0..] };
    const tags_long_url = [_]nip01_event.EventTag{.{ .items = tag_long_url_items[0..] }};
    const event_long_url = build_event(10002, tags_long_url[0..]);
    try std.testing.expectError(
        error.InvalidRelayUrl,
        relay_list_extract(&event_long_url, out_single[0..]),
    );

    const tag_valid_items = [_][]const u8{ "r", "wss://relay.valid" };
    const tags_wrong_kind = [_]nip01_event.EventTag{.{ .items = tag_valid_items[0..] }};
    const event_wrong_kind = build_event(1, tags_wrong_kind[0..]);
    try std.testing.expectError(
        error.InvalidEventKind,
        relay_list_extract(&event_wrong_kind, out_single[0..]),
    );
}

test "relay url validation matches shared websocket origin parsing" {
    const validated = try relay_url_validate("WSS://RELAY.EXAMPLE.COM:443/path?x=1#f");
    const parsed = relay_origin.parse_websocket_origin("wss://relay.example.com/path") orelse {
        return error.TestUnexpectedResult;
    };
    try std.testing.expect(relay_origin.websocket_origins_equal(validated, parsed));

    try std.testing.expectError(error.InvalidRelayUrl, relay_url_validate("ws://2001:db8::1"));
    try std.testing.expectError(error.InvalidRelayUrl, relay_url_validate("https://relay.example"));
}

test "relay list extract invalid vectors reject non-r tag and buffer overflow" {
    const tag_non_r_items = [_][]const u8{ "p", "abcdef" };
    const tags_non_r = [_]nip01_event.EventTag{.{ .items = tag_non_r_items[0..] }};
    const event_non_r = build_event(10002, tags_non_r[0..]);
    var out_single: [1]RelayPermission = undefined;
    try std.testing.expectError(
        error.InvalidRelayTag,
        relay_list_extract(&event_non_r, out_single[0..]),
    );

    const tag_overflow_a = [_][]const u8{ "r", "wss://relay.one" };
    const tag_overflow_b = [_][]const u8{ "r", "wss://relay.two" };
    const tags_overflow = [_]nip01_event.EventTag{
        .{ .items = tag_overflow_a[0..] },
        .{ .items = tag_overflow_b[0..] },
    };
    const event_overflow = build_event(10002, tags_overflow[0..]);
    try std.testing.expectError(
        error.BufferTooSmall,
        relay_list_extract(&event_overflow, out_single[0..]),
    );

    const malformed_tag_items = [_][]const u8{"r"};
    const tags_malformed = [_]nip01_event.EventTag{.{ .items = malformed_tag_items[0..] }};
    const event_malformed = build_event(10002, tags_malformed[0..]);
    try std.testing.expectError(
        error.InvalidRelayTag,
        relay_list_extract(&event_malformed, out_single[0..]),
    );
}
