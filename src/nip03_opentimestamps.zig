const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_host = @import("internal/url_with_host.zig");

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
    InvalidProofHeader,
    UnsupportedProofVersion,
    InvalidProofOperation,
    InvalidProofStructure,
    MissingBitcoinAttestation,
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

const ots_header_magic = [_]u8{
    0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65,
    0x73, 0x74, 0x61, 0x6d, 0x70, 0x73, 0x00, 0x00, 0x50,
    0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, 0x89, 0xe2, 0xe8,
    0x84, 0xe8, 0x92, 0x94,
};
const ots_major_version: u32 = 1;
const ots_op_sha256: u8 = 0x08;
const ots_op_append: u8 = 0xf0;
const ots_op_prepend: u8 = 0xf1;
const ots_op_reverse: u8 = 0xf2;
const ots_op_hexlify: u8 = 0xf3;
const ots_op_sha1: u8 = 0x02;
const ots_op_ripemd160: u8 = 0x03;
const ots_op_keccak256: u8 = 0x67;
const ots_tag_separator: u8 = 0xff;
const ots_tag_attestation: u8 = 0x00;
const ots_attestation_tag_len: u8 = 8;
const ots_attestation_payload_max: u16 = 8192;
const ots_pending_uri_max: u16 = 1000;
const ots_proof_stack_max: u8 = 64;
const ots_pending_tag = [_]u8{ 0x83, 0xdf, 0xe3, 0x0d, 0x2e, 0xf9, 0x0c, 0x8e };
const ots_bitcoin_tag = [_]u8{ 0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01 };

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

/// Validate the bounded local OpenTimestamps proof floor for one attestation.
pub fn opentimestamps_validate_local_proof(
    attestation: *const OpenTimestampsAttestation,
    proof: []const u8,
) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(attestation) != 0);
    std.debug.assert(proof.len <= limits.content_bytes_max);

    if (proof.len == 0) return error.EmptyProof;

    var cursor = ProofCursor{ .bytes = proof };
    try proof_expect_magic(&cursor, ots_header_magic[0..]);
    if (try proof_read_varuint(&cursor) != ots_major_version) {
        return error.UnsupportedProofVersion;
    }
    if (try proof_read_byte(&cursor) != ots_op_sha256) {
        return error.InvalidProofOperation;
    }
    if (!std.mem.eql(u8, try proof_read_bytes(&cursor, 32), &attestation.target_event_id)) {
        return error.TargetMismatch;
    }
    var scan = ProofScanState{};
    try proof_parse_timestamp(&cursor, &scan);
    if (!scan.saw_bitcoin) return error.MissingBitcoinAttestation;
    if (cursor.index != cursor.bytes.len) return error.InvalidProofStructure;
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

const ProofCursor = struct {
    bytes: []const u8,
    index: usize = 0,
};

const ProofScanState = struct {
    saw_bitcoin: bool = false,
};

fn proof_expect_magic(cursor: *ProofCursor, magic: []const u8) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(magic.len <= limits.content_bytes_max);

    if (!std.mem.eql(u8, try proof_read_bytes(cursor, magic.len), magic)) {
        return error.InvalidProofHeader;
    }
}

fn proof_read_byte(cursor: *ProofCursor) OpenTimestampsError!u8 {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(cursor.bytes.len <= limits.content_bytes_max);

    if (cursor.index >= cursor.bytes.len) return error.InvalidProofStructure;
    const value = cursor.bytes[cursor.index];
    cursor.index += 1;
    return value;
}

fn proof_read_bytes(cursor: *ProofCursor, len: usize) OpenTimestampsError![]const u8 {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(len <= limits.content_bytes_max);

    if (len > cursor.bytes.len - cursor.index) return error.InvalidProofStructure;
    const bytes = cursor.bytes[cursor.index .. cursor.index + len];
    cursor.index += len;
    return bytes;
}

fn proof_read_varuint(cursor: *ProofCursor) OpenTimestampsError!u32 {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(cursor.bytes.len <= limits.content_bytes_max);

    var shift: u5 = 0;
    var value: u32 = 0;
    while (true) {
        const byte = try proof_read_byte(cursor);
        value |= @as(u32, byte & 0x7f) << shift;
        if ((byte & 0x80) == 0) return value;
        if (shift >= 28) return error.InvalidProofStructure;
        shift += 7;
    }
}

fn proof_read_varbytes(
    cursor: *ProofCursor,
    max_len: u16,
    min_len: u16,
) OpenTimestampsError![]const u8 {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(min_len <= max_len);

    const len = try proof_read_varuint(cursor);
    if (len < min_len or len > max_len) return error.InvalidProofStructure;
    return proof_read_bytes(cursor, len);
}

fn proof_parse_timestamp(
    cursor: *ProofCursor,
    scan: *ProofScanState,
) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(@intFromPtr(scan) != 0);

    var depth: u8 = 1;
    while (depth != 0) {
        const tag = try proof_read_byte(cursor);
        if (tag == ots_tag_separator) {
            try proof_parse_timestamp_item(cursor, scan, try proof_read_byte(cursor), &depth);
            continue;
        }
        depth -= 1;
        try proof_parse_timestamp_item(cursor, scan, tag, &depth);
    }
}

fn proof_parse_timestamp_item(
    cursor: *ProofCursor,
    scan: *ProofScanState,
    tag: u8,
    depth: *u8,
) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(@intFromPtr(depth) != 0);

    if (tag == ots_tag_attestation) return proof_parse_attestation(cursor, scan);
    try proof_parse_operation(cursor, tag);
    if (depth.* == ots_proof_stack_max) return error.InvalidProofStructure;
    depth.* += 1;
}

fn proof_parse_operation(cursor: *ProofCursor, tag: u8) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(cursor.bytes.len <= limits.content_bytes_max);

    switch (tag) {
        ots_op_append, ots_op_prepend => {
            _ = try proof_read_varbytes(cursor, 4096, 1);
        },
        ots_op_reverse, ots_op_hexlify, ots_op_sha1, ots_op_ripemd160, ots_op_sha256,
        ots_op_keccak256 => {},
        else => return error.InvalidProofOperation,
    }
}

fn proof_parse_attestation(
    cursor: *ProofCursor,
    scan: *ProofScanState,
) OpenTimestampsError!void {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(@intFromPtr(scan) != 0);

    const tag = try proof_read_bytes(cursor, ots_attestation_tag_len);
    const payload = try proof_read_varbytes(cursor, ots_attestation_payload_max, 0);
    var payload_cursor = ProofCursor{ .bytes = payload };
    if (std.mem.eql(u8, tag, ots_pending_tag[0..])) {
        _ = try proof_read_varbytes(&payload_cursor, ots_pending_uri_max, 0);
    } else if (std.mem.eql(u8, tag, ots_bitcoin_tag[0..])) {
        _ = try proof_read_varuint(&payload_cursor);
        scan.saw_bitcoin = true;
    }
    if (payload_cursor.index != payload.len) return error.InvalidProofStructure;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.id_hex_length);
    std.debug.assert(limits.id_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return url_with_host.parse(text, limits.tag_item_bytes_max);
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
        opentimestamps_extract(
            proof[0..],
            &test_event(opentimestamps_kind, "AQ==", missing_e[0..]),
        ),
    );
    try std.testing.expectError(
        error.InvalidTargetKind,
        opentimestamps_extract(proof[0..], &test_event(opentimestamps_kind, "AQ==", bad_kind[0..])),
    );
    try std.testing.expectError(
        error.InvalidBase64,
        opentimestamps_extract(
            proof[0..],
            &test_event(opentimestamps_kind, "%%%", valid_tags[0..]),
        ),
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

fn test_local_proof(
    digest: [32]u8,
    attestation_tag: [8]u8,
    payload: []const u8,
) [96]u8 {
    var output: [96]u8 = [_]u8{0} ** 96;
    var index: usize = 0;

    @memcpy(output[index .. index + ots_header_magic.len], ots_header_magic[0..]);
    index += ots_header_magic.len;
    output[index] = 0x01;
    output[index + 1] = ots_op_sha256;
    index += 2;
    @memcpy(output[index .. index + digest.len], digest[0..]);
    index += digest.len;
    output[index] = ots_tag_attestation;
    index += 1;
    @memcpy(output[index .. index + attestation_tag.len], attestation_tag[0..]);
    index += attestation_tag.len;
    output[index] = @intCast(payload.len);
    index += 1;
    @memcpy(output[index .. index + payload.len], payload);
    return output;
}

fn test_local_proof_len(payload_len: usize) usize {
    std.debug.assert(payload_len <= 21);
    std.debug.assert(ots_header_magic.len == 31);

    return ots_header_magic.len + 1 + 1 + 32 + 1 + 8 + 1 + payload_len;
}

fn test_local_proof_with_two_attestations(
    digest: [32]u8,
    first_tag: [8]u8,
    first_payload: []const u8,
    second_tag: [8]u8,
    second_payload: []const u8,
) [128]u8 {
    var output: [128]u8 = [_]u8{0} ** 128;
    var index: usize = 0;

    @memcpy(output[index .. index + ots_header_magic.len], ots_header_magic[0..]);
    index += ots_header_magic.len;
    output[index] = 0x01;
    output[index + 1] = ots_op_sha256;
    index += 2;
    @memcpy(output[index .. index + digest.len], digest[0..]);
    index += digest.len;
    output[index] = ots_tag_separator;
    output[index + 1] = ots_tag_attestation;
    index += 2;
    @memcpy(output[index .. index + first_tag.len], first_tag[0..]);
    index += first_tag.len;
    output[index] = @intCast(first_payload.len);
    index += 1;
    @memcpy(output[index .. index + first_payload.len], first_payload);
    index += first_payload.len;
    output[index] = ots_tag_attestation;
    index += 1;
    @memcpy(output[index .. index + second_tag.len], second_tag[0..]);
    index += second_tag.len;
    output[index] = @intCast(second_payload.len);
    index += 1;
    @memcpy(output[index .. index + second_payload.len], second_payload);
    return output;
}

fn test_local_proof_len_two(first_payload_len: usize, second_payload_len: usize) usize {
    std.debug.assert(first_payload_len <= 21);
    std.debug.assert(second_payload_len <= 21);

    return ots_header_magic.len + 1 + 1 + 32 + 2 + 8 + 1 + first_payload_len + 1 + 8 + 1 +
        second_payload_len;
}

test "opentimestamps local proof validation accepts bitcoin and matching digest" {
    const digest = try parse_lower_hex_32(
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    );
    const attestation = OpenTimestampsAttestation{
        .target_event_id = digest,
        .target_kind = 1,
        .proof_base64 = "",
        .proof_len = 0,
    };
    const proof = test_local_proof(digest, ots_bitcoin_tag, &.{0x2a});
    const wrong = try parse_lower_hex_32(
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    const mismatched = OpenTimestampsAttestation{
        .target_event_id = wrong,
        .target_kind = 1,
        .proof_base64 = "",
        .proof_len = 0,
    };

    try opentimestamps_validate_local_proof(&attestation, proof[0..test_local_proof_len(1)]);
    try std.testing.expectError(
        error.TargetMismatch,
        opentimestamps_validate_local_proof(&mismatched, proof[0..test_local_proof_len(1)]),
    );
}

test "opentimestamps local proof validation tolerates pending and requires bitcoin" {
    const digest = try parse_lower_hex_32(
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    );
    const attestation = OpenTimestampsAttestation{
        .target_event_id = digest,
        .target_kind = 1,
        .proof_base64 = "",
        .proof_len = 0,
    };
    const pending = test_local_proof_with_two_attestations(
        digest,
        ots_pending_tag,
        &.{ 0x03, 'a', 'b', 'c' },
        ots_bitcoin_tag,
        &.{0x2a},
    );
    const unknown = test_local_proof(
        digest,
        .{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08 },
        &.{},
    );

    try opentimestamps_validate_local_proof(
        &attestation,
        pending[0..test_local_proof_len_two(4, 1)],
    );
    try std.testing.expectError(
        error.MissingBitcoinAttestation,
        opentimestamps_validate_local_proof(&attestation, unknown[0..test_local_proof_len(0)]),
    );
}
