const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const opentimestamps_kind: u32 = 1040;

pub const OpenTimestampsError = error{
    InvalidEventKind,
    InvalidEventTag,
    DuplicateEventTag,
    MissingEventTag,
    InvalidKindTag,
    DuplicateKindTag,
    MissingKindTag,
    InvalidEventId,
    InvalidRelayUrl,
    InvalidTargetKind,
    EmptyProof,
    InvalidBase64,
    BufferTooSmall,
    TargetMismatch,
};

pub const OpenTimestampsAttestation = struct {
    target_event_id: [32]u8,
    target_kind: u32,
    relay_url: ?[]const u8 = null,
    proof_base64: []const u8,
    proof_len: u32,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    item_count: u8 = 0,
    kind_text: [10]u8 = undefined,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extract and decode a bounded NIP-03 OpenTimestamps attestation event.
pub fn opentimestamps_extract(
    proof_output: []u8,
    event: *const nip01_event.Event,
) OpenTimestampsError!OpenTimestampsAttestation {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(proof_output.len <= limits.content_bytes_max);

    if (event.kind != opentimestamps_kind) return error.InvalidEventKind;

    var parsed = OpenTimestampsAttestation{
        .target_event_id = undefined,
        .target_kind = 0,
        .proof_base64 = event.content,
        .proof_len = 0,
    };
    try parse_required_tags(event.tags, &parsed);
    parsed.proof_len = try decode_proof(proof_output, event.content);
    return parsed;
}

/// Verify that an attestation references the expected target event id and kind.
pub fn opentimestamps_validate_target_reference(
    attestation: *const OpenTimestampsAttestation,
    target_event: *const nip01_event.Event,
) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(attestation) != 0);
    std.debug.assert(@intFromPtr(target_event) != 0);

    if (!std.mem.eql(u8, &attestation.target_event_id, &target_event.id)) {
        return error.TargetMismatch;
    }
    if (attestation.target_kind != target_event.kind) {
        return error.TargetMismatch;
    }
}

/// Build the required `e` tag for a NIP-03 attestation target.
pub fn opentimestamps_build_event_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_url: ?[]const u8,
) OpenTimestampsError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_id_hex.len <= limits.tag_item_bytes_max);

    _ = parse_lower_hex_32(event_id_hex) catch return error.InvalidEventId;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_url) |parsed| {
        output.items[2] = parse_url(parsed) catch return error.InvalidRelayUrl;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Build the required `k` tag for a NIP-03 attestation target.
pub fn opentimestamps_build_kind_tag(
    output: *BuiltTag,
    target_kind: u32,
) OpenTimestampsError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(target_kind <= limits.kind_max);

    if (target_kind > limits.kind_max) return error.InvalidTargetKind;
    output.items[0] = "k";
    output.items[1] = write_kind_decimal(output.kind_text[0..], target_kind);
    output.item_count = 2;
    return output.as_event_tag();
}

fn parse_required_tags(
    tags: []const nip01_event.EventTag,
    parsed: *OpenTimestampsAttestation,
) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(tags.len <= limits.tags_max);

    var has_event_tag = false;
    var has_kind_tag = false;
    for (tags) |tag| {
        if (tag.items.len == 0) continue;
        if (std.mem.eql(u8, tag.items[0], "e")) {
            if (has_event_tag) return error.DuplicateEventTag;
            try parse_event_tag(tag, parsed);
            has_event_tag = true;
            continue;
        }
        if (std.mem.eql(u8, tag.items[0], "k")) {
            if (has_kind_tag) return error.DuplicateKindTag;
            parsed.target_kind = try parse_kind_tag(tag);
            has_kind_tag = true;
        }
    }
    if (!has_event_tag) return error.MissingEventTag;
    if (!has_kind_tag) return error.MissingKindTag;
}

fn parse_event_tag(
    tag: nip01_event.EventTag,
    parsed: *OpenTimestampsAttestation,
) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2 or tag.items.len > 5) return error.InvalidEventTag;
    parsed.target_event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidEventId;
    if (tag.items.len >= 3) {
        parsed.relay_url = parse_optional_url(tag.items[2]) catch return error.InvalidRelayUrl;
    }
    if (tag.items.len == 4) {
        try validate_event_suffix_item(tag.items[3]);
    }
    if (tag.items.len == 5) {
        if (!is_event_marker(tag.items[3])) return error.InvalidEventTag;
        _ = parse_lower_hex_32(tag.items[4]) catch return error.InvalidEventTag;
    }
}

fn parse_kind_tag(tag: nip01_event.EventTag) OpenTimestampsError!u32 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.kind_max == std.math.maxInt(u16));

    if (tag.items.len != 2) return error.InvalidKindTag;
    const parsed = std.fmt.parseUnsigned(u32, tag.items[1], 10) catch {
        return error.InvalidTargetKind;
    };
    if (parsed > limits.kind_max) return error.InvalidTargetKind;
    return parsed;
}

fn decode_proof(output: []u8, proof_base64: []const u8) OpenTimestampsError!u32 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(proof_base64.len <= limits.content_bytes_max);

    if (proof_base64.len == 0) return error.EmptyProof;
    const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(proof_base64) catch {
        return error.InvalidBase64;
    };
    if (decoded_len == 0) return error.EmptyProof;
    if (decoded_len > output.len) return error.BufferTooSmall;
    std.base64.standard.Decoder.decode(output[0..decoded_len], proof_base64) catch {
        return error.InvalidBase64;
    };
    return std.math.cast(u32, decoded_len) orelse return error.BufferTooSmall;
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

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_optional_url(text: []const u8) error{InvalidUrl}!?[]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return null;
    return try parse_url(text);
}

fn validate_event_suffix_item(text: []const u8) OpenTimestampsError!void {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (is_event_marker(text)) return;
    _ = parse_lower_hex_32(text) catch return error.InvalidEventTag;
}

fn is_event_marker(text: []const u8) bool {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (std.mem.eql(u8, text, "reply")) return true;
    if (std.mem.eql(u8, text, "root")) return true;
    if (std.mem.eql(u8, text, "mention")) return true;
    return false;
}

fn write_kind_decimal(output: []u8, value: u32) []const u8 {
    std.debug.assert(output.len >= 5);
    std.debug.assert(value <= limits.kind_max);

    return std.fmt.bufPrint(output, "{d}", .{value}) catch unreachable;
}

fn test_event(
    kind: u32,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
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

test "opentimestamps extract decodes bounded attestation content" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "e",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "wss://relay.example",
        } },
        .{ .items = &.{ "k", "1" } },
    };
    const event = test_event(opentimestamps_kind, "AQIDBA==", tags[0..]);
    var proof: [16]u8 = undefined;

    const parsed = try opentimestamps_extract(proof[0..], &event);

    try std.testing.expectEqual(@as(u32, 4), parsed.proof_len);
    try std.testing.expectEqual(@as(u32, 1), parsed.target_kind);
    try std.testing.expectEqualStrings("wss://relay.example", parsed.relay_url.?);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, proof[0..4]);
}

test "opentimestamps extract rejects malformed required fields" {
    const missing_e = [_]nip01_event.EventTag{.{ .items = &.{ "k", "1" } }};
    const bad_kind = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" } },
        .{ .items = &.{ "k", "70000" } },
    };
    const valid_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef" } },
        .{ .items = &.{ "k", "1" } },
    };
    var proof: [8]u8 = undefined;

    try std.testing.expectError(
        error.MissingEventTag,
        opentimestamps_extract(proof[0..], &test_event(opentimestamps_kind, "AQ==", missing_e[0..])),
    );
    try std.testing.expectError(
        error.InvalidTargetKind,
        opentimestamps_extract(proof[0..], &test_event(opentimestamps_kind, "AQ==", bad_kind[0..])),
    );
    try std.testing.expectError(
        error.InvalidBase64,
        opentimestamps_extract(proof[0..], &test_event(opentimestamps_kind, "%%%", valid_tags[0..])),
    );
}

test "opentimestamps validate target reference matches id and kind" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "e",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
        .{ .items = &.{ "k", "1" } },
    };
    var target = test_event(1, "", &.{});
    _ = try std.fmt.hexToBytes(
        &target.id,
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    );
    var proof: [8]u8 = undefined;
    const parsed = try opentimestamps_extract(
        proof[0..],
        &test_event(opentimestamps_kind, "AQ==", tags[0..]),
    );

    try opentimestamps_validate_target_reference(&parsed, &target);
    target.kind = 2;
    try std.testing.expectError(
        error.TargetMismatch,
        opentimestamps_validate_target_reference(&parsed, &target),
    );
}

test "opentimestamps extract accepts long-form standard e tag variants" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "e",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            "",
            "reply",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &.{ "k", "1" } },
    };
    var proof: [8]u8 = undefined;

    const parsed = try opentimestamps_extract(
        proof[0..],
        &test_event(opentimestamps_kind, "AQ==", tags[0..]),
    );

    try std.testing.expect(parsed.relay_url == null);
    try std.testing.expectEqual(@as(u32, 1), parsed.target_kind);
    try std.testing.expectEqual(@as(u32, 1), parsed.proof_len);
}

test "opentimestamps builders emit canonical e and k tags" {
    var event_tag: BuiltTag = .{};
    var kind_tag: BuiltTag = .{};

    const built_event = try opentimestamps_build_event_tag(
        &event_tag,
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        "wss://relay.example",
    );
    const built_kind = try opentimestamps_build_kind_tag(&kind_tag, 1040);

    try std.testing.expectEqualStrings("e", built_event.items[0]);
    try std.testing.expectEqualStrings("wss://relay.example", built_event.items[2]);
    try std.testing.expectEqualStrings("k", built_kind.items[0]);
    try std.testing.expectEqualStrings("1040", built_kind.items[1]);
}
