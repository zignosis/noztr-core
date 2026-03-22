const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const repost_event_kind: u32 = 6;
pub const generic_repost_event_kind: u32 = 16;

pub const RepostError = error{
    InvalidRepostKind,
    MissingEventTag,
    DuplicateEventTag,
    MissingRelayHint,
    MissingEmbeddedEvent,
    InvalidETag,
    InvalidEventId,
    DuplicatePubkeyTag,
    InvalidPubkeyTag,
    InvalidPubkey,
    DuplicateKindTag,
    InvalidKindTag,
    DuplicateCoordinateTag,
    InvalidCoordinate,
    InvalidEmbeddedEvent,
    EmbeddedEventIdMismatch,
    EmbeddedEventKindMismatch,
    EmbeddedEventPubkeyMismatch,
    EmbeddedCoordinateMismatch,
};

pub const RepostCoordinate = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
};

pub const RepostTarget = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
    author_pubkey: ?[32]u8 = null,
    reposted_kind: ?u32 = null,
    coordinate: ?RepostCoordinate = null,
    embedded_event_json: ?[]const u8 = null,
};

/// Returns whether the event is a kind-6 repost.
pub fn repost_is_repost(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= std.math.maxInt(u32));

    return event.kind == repost_event_kind;
}

/// Returns whether the event is a kind-16 generic repost.
pub fn repost_is_generic_repost(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= std.math.maxInt(u32));

    return event.kind == generic_repost_event_kind;
}

/// Parses strict NIP-18 repost semantics from a kind-6 or kind-16 event.
pub fn repost_parse(event: *const nip01_event.Event) RepostError!RepostTarget {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (!repost_is_repost(event) and !repost_is_generic_repost(event)) {
        return error.InvalidRepostKind;
    }

    var parsed = RepostTarget{
        .event_id = undefined,
        .embedded_event_json = try parse_embedded_event_json(event.content),
    };
    var found_event_tag = false;

    for (event.tags) |tag| {
        try parse_repost_tag(tag, &parsed, &found_event_tag);
    }

    if (!found_event_tag) {
        return error.MissingEventTag;
    }
    if (event.kind == repost_event_kind and parsed.relay_hint == null) {
        return error.MissingRelayHint;
    }
    if (event.kind == generic_repost_event_kind) {
        if (parsed.coordinate == null and parsed.embedded_event_json == null) {
            return error.MissingEmbeddedEvent;
        }
    }
    try validate_target_metadata(event.kind, &parsed);
    try validate_embedded_event_consistency(event.kind, &parsed);
    return parsed;
}

fn parse_repost_tag(
    tag: nip01_event.EventTag,
    parsed: *RepostTarget,
    found_event_tag: *bool,
) RepostError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (tag.items.len == 0) {
        return error.InvalidETag;
    }

    const tag_name = tag.items[0];
    if (std.mem.eql(u8, tag_name, "e")) {
        if (found_event_tag.*) {
            return error.DuplicateEventTag;
        }
        try parse_event_tag(tag, parsed);
        found_event_tag.* = true;
        return;
    }
    if (std.mem.eql(u8, tag_name, "p")) {
        if (parsed.author_pubkey != null) {
            return error.DuplicatePubkeyTag;
        }
        parsed.author_pubkey = try parse_pubkey_tag(tag);
        return;
    }
    if (std.mem.eql(u8, tag_name, "k")) {
        if (parsed.reposted_kind != null) {
            return error.DuplicateKindTag;
        }
        parsed.reposted_kind = try parse_kind_tag(tag);
        return;
    }
    if (std.mem.eql(u8, tag_name, "a")) {
        if (parsed.coordinate != null) {
            return error.DuplicateCoordinateTag;
        }
        parsed.coordinate = try parse_coordinate_tag(tag);
    }
}

fn parse_event_tag(tag: nip01_event.EventTag, parsed: *RepostTarget) RepostError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (tag.items.len < 2) {
        return error.InvalidETag;
    }

    parsed.event_id = parse_lower_hex_32(tag.items[1]) catch {
        return error.InvalidEventId;
    };
    parsed.relay_hint = null;
    if (tag.items.len >= 3) {
        parsed.relay_hint = parse_optional_hint(tag.items[2]) catch {
            return error.InvalidETag;
        };
    }
}

fn parse_pubkey_tag(tag: nip01_event.EventTag) RepostError![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (tag.items.len < 2) {
        return error.InvalidPubkeyTag;
    }
    return parse_lower_hex_32(tag.items[1]) catch {
        return error.InvalidPubkey;
    };
}

fn parse_kind_tag(tag: nip01_event.EventTag) RepostError!u32 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    if (tag.items.len < 2) {
        return error.InvalidKindTag;
    }

    const kind = std.fmt.parseUnsigned(u32, tag.items[1], 10) catch {
        return error.InvalidKindTag;
    };
    if (kind > limits.kind_max) {
        return error.InvalidKindTag;
    }
    return kind;
}

fn parse_coordinate_tag(tag: nip01_event.EventTag) RepostError!RepostCoordinate {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (tag.items.len < 2) {
        return error.InvalidCoordinate;
    }
    return parse_address_coordinate(tag.items[1]) catch {
        return error.InvalidCoordinate;
    };
}

fn parse_embedded_event_json(content: []const u8) RepostError!?[]const u8 {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(std.unicode.utf8ValidateSlice(content));

    if (content.len == 0) {
        return null;
    }
    if (content[0] != '{') {
        return error.InvalidEmbeddedEvent;
    }
    return content;
}

fn validate_target_metadata(
    repost_kind: u32,
    parsed: *const RepostTarget,
) RepostError!void {
    std.debug.assert(repost_kind <= std.math.maxInt(u32));
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (repost_kind == repost_event_kind) {
        if (parsed.reposted_kind) |tag_kind| {
            if (tag_kind != 1) {
                return error.InvalidKindTag;
            }
        }
        if (parsed.coordinate != null) {
            return error.InvalidCoordinate;
        }
        return;
    }
    if (parsed.reposted_kind) |tag_kind| {
        if (tag_kind == 1) {
            return error.InvalidKindTag;
        }
    }
    if (parsed.coordinate) |coordinate| {
        if (!coordinate_kind_supports_a_tag(coordinate.kind)) {
            return error.InvalidCoordinate;
        }
        if (parsed.reposted_kind) |tag_kind| {
            if (coordinate.kind != tag_kind) {
                return error.InvalidKindTag;
            }
        }
        if (parsed.author_pubkey) |pubkey| {
            if (!std.mem.eql(u8, &coordinate.pubkey, &pubkey)) {
                return error.InvalidPubkey;
            }
        }
    }
}

fn coordinate_kind_supports_a_tag(kind: u32) bool {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    if (kind == 0 or kind == 3) {
        return true;
    }
    if (kind >= 10000 and kind < 20000) {
        return true;
    }
    if (kind >= 30000 and kind < 40000) {
        return true;
    }
    return false;
}

fn validate_embedded_event_consistency(
    repost_kind: u32,
    parsed: *const RepostTarget,
) RepostError!void {
    std.debug.assert(repost_kind <= std.math.maxInt(u32));
    std.debug.assert(@intFromPtr(parsed) != 0);

    const content = parsed.embedded_event_json orelse return;
    var scratch: [limits.content_bytes_max]u8 = undefined;
    var scratch_fba = std.heap.FixedBufferAllocator.init(scratch[0..]);
    const embedded = nip01_event.event_parse_json(content, scratch_fba.allocator()) catch {
        return error.InvalidEmbeddedEvent;
    };

    try validate_embedded_event_id(parsed, &embedded);
    try validate_embedded_event_kind(repost_kind, parsed, &embedded);
    try validate_embedded_event_pubkey(parsed, &embedded);
    try validate_embedded_event_coordinate(parsed, &embedded);
}

fn validate_embedded_event_id(
    parsed: *const RepostTarget,
    embedded: *const nip01_event.Event,
) RepostError!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(@intFromPtr(embedded) != 0);

    if (!std.mem.eql(u8, &parsed.event_id, &embedded.id)) {
        return error.EmbeddedEventIdMismatch;
    }
}

fn validate_embedded_event_kind(
    repost_kind: u32,
    parsed: *const RepostTarget,
    embedded: *const nip01_event.Event,
) RepostError!void {
    std.debug.assert(repost_kind <= std.math.maxInt(u32));
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(@intFromPtr(embedded) != 0);

    if (repost_kind == repost_event_kind and embedded.kind != 1) {
        return error.EmbeddedEventKindMismatch;
    }
    if (repost_kind == generic_repost_event_kind and embedded.kind == 1) {
        return error.EmbeddedEventKindMismatch;
    }
    if (parsed.reposted_kind) |tag_kind| {
        if (tag_kind != embedded.kind) {
            return error.EmbeddedEventKindMismatch;
        }
    }
}

fn validate_embedded_event_pubkey(
    parsed: *const RepostTarget,
    embedded: *const nip01_event.Event,
) RepostError!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(@intFromPtr(embedded) != 0);

    if (parsed.author_pubkey) |pubkey| {
        if (!std.mem.eql(u8, &pubkey, &embedded.pubkey)) {
            return error.EmbeddedEventPubkeyMismatch;
        }
    }
}

fn validate_embedded_event_coordinate(
    parsed: *const RepostTarget,
    embedded: *const nip01_event.Event,
) RepostError!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(@intFromPtr(embedded) != 0);

    const coordinate = parsed.coordinate orelse return;
    if (!coordinate_matches_event(coordinate, embedded)) {
        return error.EmbeddedCoordinateMismatch;
    }
}

fn coordinate_matches_event(
    coordinate: RepostCoordinate,
    event: *const nip01_event.Event,
) bool {
    std.debug.assert(coordinate.kind <= std.math.maxInt(u32));
    std.debug.assert(@intFromPtr(event) != 0);

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
        if (!std.mem.eql(u8, tag.items[0], "d")) {
            continue;
        }
        if (found_d) {
            return null;
        }
        found_d = true;
        found_value = tag.items[1];
    }
    if (found_d) {
        return found_value;
    }
    return null;
}

fn parse_address_coordinate(text: []const u8) error{InvalidCoordinate}!RepostCoordinate {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse {
        return error.InvalidCoordinate;
    };
    if (first_colon == 0) {
        return error.InvalidCoordinate;
    }

    const second_rel = std.mem.indexOfScalar(u8, text[first_colon + 1 ..], ':') orelse {
        return error.InvalidCoordinate;
    };
    const second_colon = first_colon + second_rel + 1;
    if (second_colon == first_colon + 1) {
        return error.InvalidCoordinate;
    }

    const kind = std.fmt.parseUnsigned(u32, text[0..first_colon], 10) catch {
        return error.InvalidCoordinate;
    };
    if (kind > limits.kind_max) {
        return error.InvalidCoordinate;
    }

    const pubkey = parse_lower_hex_32(text[first_colon + 1 .. second_colon]) catch {
        return error.InvalidCoordinate;
    };
    const identifier = text[second_colon + 1 ..];
    return .{
        .kind = kind,
        .pubkey = pubkey,
        .identifier = identifier,
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

fn repost_event(
    kind: u32,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= std.math.maxInt(u32));
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

fn embedded_event_json(
    output: []u8,
    id_hex: []const u8,
    pubkey_hex: []const u8,
    kind: u32,
    d_tag: ?[]const u8,
) ![]const u8 {
    std.debug.assert(output.len >= 0);
    std.debug.assert(id_hex.len == limits.id_hex_length);

    var tags_buffer: [128]u8 = undefined;
    const tags_json = if (d_tag) |identifier|
        try std.fmt.bufPrint(tags_buffer[0..], "[[\"d\",\"{s}\"]]", .{identifier})
    else
        "[]";
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":0,\"kind\":{},\"tags\":{s},\"content\":\"\",\"sig\":\"{s}\"}}",
        .{
            id_hex,
            pubkey_hex,
            kind,
            tags_json,
            "00000000000000000000000000000000" ++
                "00000000000000000000000000000000" ++
                "00000000000000000000000000000000" ++
                "00000000000000000000000000000000",
        },
    );
}

test "repost kind helpers detect kind 6 and kind 16" {
    const repost = repost_event(6, "", &.{});
    const generic = repost_event(16, "", &.{});

    try std.testing.expect(repost_is_repost(&repost));
    try std.testing.expect(!repost_is_generic_repost(&repost));
    try std.testing.expect(!repost_is_repost(&generic));
    try std.testing.expect(repost_is_generic_repost(&generic));
}

test "repost parse valid kind 6 uses strict relay and target tags" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "wss://relay.one",
    };
    const p_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = p_tag[0..] },
    };
    const event = repost_event(6, "", tags[0..]);

    const parsed = try repost_parse(&event);

    try std.testing.expect(parsed.event_id[0] == 0x11);
    try std.testing.expectEqualStrings("wss://relay.one", parsed.relay_hint.?);
    try std.testing.expect(parsed.author_pubkey.?[0] == 0xaa);
    try std.testing.expect(parsed.reposted_kind == null);
    try std.testing.expect(parsed.coordinate == null);
}

test "repost parse valid kind 16 accepts k a and embedded event json" {
    const e_tag = [_][]const u8{
        "e",
        "2222222222222222222222222222222222222222222222222222222222222222",
    };
    const p_tag = [_][]const u8{
        "p",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    };
    const k_tag = [_][]const u8{ "k", "30023" };
    const a_tag = [_][]const u8{
        "a",
        "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:article",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = p_tag[0..] },
        .{ .items = k_tag[0..] },
        .{ .items = a_tag[0..] },
    };
    var json_buffer: [512]u8 = undefined;
    const embedded_json = try embedded_event_json(
        json_buffer[0..],
        "2222222222222222222222222222222222222222222222222222222222222222",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        30023,
        "article",
    );
    const event = repost_event(16, embedded_json, tags[0..]);

    const parsed = try repost_parse(&event);

    try std.testing.expect(parsed.event_id[0] == 0x22);
    try std.testing.expect(parsed.author_pubkey.?[0] == 0xbb);
    try std.testing.expectEqual(@as(?u32, 30023), parsed.reposted_kind);
    try std.testing.expectEqual(@as(u32, 30023), parsed.coordinate.?.kind);
    try std.testing.expectEqualStrings("article", parsed.coordinate.?.identifier);
    try std.testing.expectEqualStrings(embedded_json, parsed.embedded_event_json.?);
}

test "repost parse valid generic repost without a requires embedded event" {
    const e_tag = [_][]const u8{
        "e",
        "3333333333333333333333333333333333333333333333333333333333333333",
    };
    const k_tag = [_][]const u8{ "k", "42" };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = k_tag[0..] },
    };
    var json_buffer: [512]u8 = undefined;
    const embedded_json = try embedded_event_json(
        json_buffer[0..],
        "3333333333333333333333333333333333333333333333333333333333333333",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        42,
        null,
    );
    const event = repost_event(16, embedded_json, tags[0..]);

    const parsed = try repost_parse(&event);

    try std.testing.expect(parsed.coordinate == null);
    try std.testing.expectEqual(@as(?u32, 42), parsed.reposted_kind);
    try std.testing.expectEqualStrings(embedded_json, parsed.embedded_event_json.?);
}

test "repost parse valid generic repost with coordinate and empty content is allowed" {
    const e_tag = [_][]const u8{
        "e",
        "4444444444444444444444444444444444444444444444444444444444444444",
    };
    const a_tag = [_][]const u8{
        "a",
        "30023:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc:article",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = a_tag[0..] },
    };

    const parsed = try repost_parse(&repost_event(16, "", tags[0..]));

    try std.testing.expect(parsed.embedded_event_json == null);
    try std.testing.expectEqual(@as(u32, 30023), parsed.coordinate.?.kind);
}

test "repost parse rejects wrong kind and missing required target data" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
    };
    const tags = [_]nip01_event.EventTag{.{ .items = e_tag[0..] }};
    const wrong_kind = repost_event(1, "", tags[0..]);
    const kind6_missing_relay = repost_event(6, "", tags[0..]);
    const generic_missing_content = repost_event(16, "", tags[0..]);

    try std.testing.expectError(error.InvalidRepostKind, repost_parse(&wrong_kind));
    try std.testing.expectError(error.MissingRelayHint, repost_parse(&kind6_missing_relay));
    try std.testing.expectError(error.MissingEmbeddedEvent, repost_parse(&generic_missing_content));
}

test "repost parse rejects duplicate tags and malformed payloads" {
    const e_tag = [_][]const u8{
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "wss://relay",
    };
    const duplicate_e_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = e_tag[0..] },
    };
    const duplicate_p_tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = &[_][]const u8{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };
    const bad_kind_tag = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = &[_][]const u8{ "k", "70000" } },
    };
    const bad_a_tag = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = &[_][]const u8{ "a", "1:bad:coord" } },
    };
    const bad_content = repost_event(16, "not-json", &.{.{ .items = e_tag[0..] }});
    const bad_object = repost_event(16, "{\"kind\":1}", &.{.{ .items = e_tag[0..] }});

    try std.testing.expectError(
        error.DuplicateEventTag,
        repost_parse(&repost_event(6, "", duplicate_e_tags[0..])),
    );
    try std.testing.expectError(
        error.DuplicatePubkeyTag,
        repost_parse(&repost_event(6, "", duplicate_p_tags[0..])),
    );
    try std.testing.expectError(
        error.InvalidKindTag,
        repost_parse(&repost_event(16, "{\"kind\":1}", bad_kind_tag[0..])),
    );
    try std.testing.expectError(
        error.InvalidCoordinate,
        repost_parse(&repost_event(16, "{\"kind\":1}", bad_a_tag[0..])),
    );
    try std.testing.expectError(error.InvalidEmbeddedEvent, repost_parse(&bad_content));
    try std.testing.expectError(error.InvalidEmbeddedEvent, repost_parse(&bad_object));
}

test "repost parse rejects contradictory target metadata without embedded event" {
    const kind6_bad_k = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "wss://relay",
        })[0..] },
        .{ .items = (&[_][]const u8{ "k", "42" })[0..] },
    };
    const kind6_bad_a = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "wss://relay",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "a",
            "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:article",
        })[0..] },
    };
    const generic_bad_kind = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "2222222222222222222222222222222222222222222222222222222222222222",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "a",
            "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:article",
        })[0..] },
        .{ .items = (&[_][]const u8{ "k", "1" })[0..] },
    };
    const generic_bad_pubkey = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "3333333333333333333333333333333333333333333333333333333333333333",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "a",
            "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:article",
        })[0..] },
    };
    const generic_bad_coordinate_kind = [_]nip01_event.EventTag{
        .{ .items = (&[_][]const u8{
            "e",
            "4444444444444444444444444444444444444444444444444444444444444444",
        })[0..] },
        .{ .items = (&[_][]const u8{
            "a",
            "42:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:note",
        })[0..] },
    };

    try std.testing.expectError(
        error.InvalidKindTag,
        repost_parse(&repost_event(6, "", kind6_bad_k[0..])),
    );
    try std.testing.expectError(
        error.InvalidCoordinate,
        repost_parse(&repost_event(6, "", kind6_bad_a[0..])),
    );
    try std.testing.expectError(
        error.InvalidKindTag,
        repost_parse(&repost_event(16, "", generic_bad_kind[0..])),
    );
    try std.testing.expectError(
        error.InvalidPubkey,
        repost_parse(&repost_event(16, "", generic_bad_pubkey[0..])),
    );
    try std.testing.expectError(
        error.InvalidCoordinate,
        repost_parse(&repost_event(16, "", generic_bad_coordinate_kind[0..])),
    );
}

test "repost parse rejects embedded event mismatches" {
    const e_tag = [_][]const u8{
        "e",
        "5555555555555555555555555555555555555555555555555555555555555555",
        "wss://relay",
    };
    const p_tag = [_][]const u8{
        "p",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    const k_tag = [_][]const u8{ "k", "30023" };
    const a_tag = [_][]const u8{
        "a",
        "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:article",
    };
    const tags = [_]nip01_event.EventTag{
        .{ .items = e_tag[0..] },
        .{ .items = p_tag[0..] },
        .{ .items = k_tag[0..] },
        .{ .items = a_tag[0..] },
    };
    var kind6_buffer: [512]u8 = undefined;
    const kind6_wrong_kind = try embedded_event_json(
        kind6_buffer[0..],
        "5555555555555555555555555555555555555555555555555555555555555555",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        42,
        null,
    );
    var id_buffer: [512]u8 = undefined;
    const mismatched_id = try embedded_event_json(
        id_buffer[0..],
        "6666666666666666666666666666666666666666666666666666666666666666",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        30023,
        "article",
    );
    var pubkey_buffer: [512]u8 = undefined;
    const mismatched_pubkey = try embedded_event_json(
        pubkey_buffer[0..],
        "5555555555555555555555555555555555555555555555555555555555555555",
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
        30023,
        "article",
    );
    var kind_buffer: [512]u8 = undefined;
    const mismatched_kind = try embedded_event_json(
        kind_buffer[0..],
        "5555555555555555555555555555555555555555555555555555555555555555",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        1,
        null,
    );
    var coordinate_buffer: [512]u8 = undefined;
    const mismatched_coordinate = try embedded_event_json(
        coordinate_buffer[0..],
        "5555555555555555555555555555555555555555555555555555555555555555",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        30023,
        "other",
    );

    try std.testing.expectError(
        error.EmbeddedEventKindMismatch,
        repost_parse(&repost_event(6, kind6_wrong_kind, &.{.{ .items = e_tag[0..] }})),
    );
    try std.testing.expectError(
        error.EmbeddedEventIdMismatch,
        repost_parse(&repost_event(16, mismatched_id, tags[0..])),
    );
    try std.testing.expectError(
        error.EmbeddedEventPubkeyMismatch,
        repost_parse(&repost_event(16, mismatched_pubkey, tags[0..])),
    );
    try std.testing.expectError(
        error.EmbeddedEventKindMismatch,
        repost_parse(&repost_event(16, mismatched_kind, tags[0..])),
    );
    try std.testing.expectError(
        error.EmbeddedCoordinateMismatch,
        repost_parse(&repost_event(16, mismatched_coordinate, tags[0..])),
    );
}
