const std = @import("std");
const limits = @import("limits.zig");
const nip21_uri = @import("nip21_uri.zig");

pub const ReferencesError = error{
    BufferTooSmall,
    ScratchTooSmall,
};

pub const ContentReference = struct {
    start: u32,
    end: u32,
    uri: []const u8,
    reference: nip21_uri.Nip21Reference,
};

/// Extracts strict inline `nostr:` URI references from readable event content.
///
/// Lifetime and ownership:
/// - `ContentReference.uri` borrows from `content`.
/// - `ContentReference.reference` borrows from `content` and from the per-reference slot inside
///   `tlv_scratch`.
/// - Keep both `content` and `tlv_scratch` alive and unmodified while using extracted references.
pub fn reference_extract(
    content: []const u8,
    references_out: []ContentReference,
    tlv_scratch: []u8,
) ReferencesError!u16 {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(references_out.len <= std.math.maxInt(u16));

    if (required_scratch_len(references_out.len) > tlv_scratch.len) {
        return error.ScratchTooSmall;
    }

    var count: u16 = 0;
    var index: usize = 0;
    while (index < content.len) {
        const end_index = detect_reference_end(content, index) orelse {
            index += next_char_len(content[index..]);
            continue;
        };
        if (count == references_out.len) {
            return error.BufferTooSmall;
        }

        const uri = content[index..end_index];
        const scratch = scratch_slot(tlv_scratch, count);
        const parsed = nip21_uri.nip21_parse(uri, scratch) catch {
            index += next_char_len(content[index..]);
            continue;
        };
        references_out[count] = .{
            .start = @intCast(index),
            .end = @intCast(end_index),
            .uri = uri,
            .reference = parsed,
        };
        count += 1;
        index = end_index;
    }
    return count;
}

fn detect_reference_end(content: []const u8, start: usize) ?usize {
    std.debug.assert(start <= content.len);
    std.debug.assert(content.len <= limits.content_bytes_max);

    if (!std.mem.startsWith(u8, content[start..], "nostr:")) {
        return null;
    }

    const identifier_start = start + limits.nip21_scheme_prefix_bytes;
    const prefix_len = detect_prefix_len(content[identifier_start..]) orelse return null;
    var end = identifier_start + prefix_len;
    if (end >= content.len or content[end] != '1') {
        return null;
    }
    end += 1;

    const data_start = end;
    while (end < content.len and is_bech32_char(content[end])) : (end += 1) {}
    if (end == data_start) {
        return null;
    }
    return end;
}

fn detect_prefix_len(text: []const u8) ?usize {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.nip21_scheme_prefix_bytes == 6);

    if (std.mem.startsWith(u8, text, "nprofile")) return "nprofile".len;
    if (std.mem.startsWith(u8, text, "nevent")) return "nevent".len;
    if (std.mem.startsWith(u8, text, "naddr")) return "naddr".len;
    if (std.mem.startsWith(u8, text, "npub")) return "npub".len;
    if (std.mem.startsWith(u8, text, "note")) return "note".len;
    return null;
}

fn is_bech32_char(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(!@inComptime());

    return switch (byte) {
        'q',
        'p',
        'z',
        'r',
        'y',
        '9',
        'x',
        '8',
        'g',
        'f',
        '2',
        't',
        'v',
        'd',
        'w',
        '0',
        's',
        '3',
        'j',
        'n',
        '5',
        '4',
        'k',
        'h',
        'c',
        'e',
        '6',
        'm',
        'u',
        'a',
        '7',
        'l',
        => true,
        else => false,
    };
}

fn required_scratch_len(reference_count: usize) usize {
    std.debug.assert(reference_count <= std.math.maxInt(u16));
    std.debug.assert(limits.nip19_tlv_scratch_bytes_max > 0);

    return reference_count * limits.nip19_tlv_scratch_bytes_max;
}

fn scratch_slot(tlv_scratch: []u8, index: u16) []u8 {
    std.debug.assert(tlv_scratch.len % limits.nip19_tlv_scratch_bytes_max == 0);
    std.debug.assert(index <= std.math.maxInt(u16));

    const start = @as(usize, index) * limits.nip19_tlv_scratch_bytes_max;
    const end = start + limits.nip19_tlv_scratch_bytes_max;
    return tlv_scratch[start..end];
}

fn next_char_len(content: []const u8) usize {
    std.debug.assert(content.len > 0);
    std.debug.assert(content.len <= limits.content_bytes_max);

    if (std.ascii.isAscii(content[0])) {
        return 1;
    }
    return std.unicode.utf8ByteSequenceLength(content[0]) catch 1;
}

test "reference_extract parses valid nostr uris with stable spans" {
    var bech32_output: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    var tlv_scratch: [2 * limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var references: [2]ContentReference = undefined;

    const npub_identifier = try @import("nip19_bech32.zig").nip19_encode(
        bech32_output[0..],
        .{ .npub = [_]u8{0x11} ** 32 },
    );
    const npub_uri = try to_nostr_uri(uri_output[0..], npub_identifier);
    const note_identifier = try @import("nip19_bech32.zig").nip19_encode(
        bech32_output[0..],
        .{ .note = [_]u8{0x22} ** 32 },
    );
    var note_uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    const note_uri = try to_nostr_uri(note_uri_output[0..], note_identifier);
    var text_buffer: [2 * limits.nip21_uri_bytes_max + 32]u8 = undefined;
    const content = try std.fmt.bufPrint(
        text_buffer[0..],
        "Hello {s}, then [{s}].",
        .{ npub_uri, note_uri },
    );

    const count = try reference_extract(content, references[0..], tlv_scratch[0..]);

    try std.testing.expectEqual(@as(u16, 2), count);
    try std.testing.expect(references[0].reference.entity == .npub);
    try std.testing.expectEqualStrings(npub_uri, references[0].uri);
    try std.testing.expectEqualStrings(note_uri, references[1].uri);
    try std.testing.expectEqualStrings(npub_uri, content[references[0].start..references[0].end]);
}

test "reference_extract ignores malformed uppercase forbidden and broken uris" {
    var bech32_output: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    var tlv_scratch: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var references: [1]ContentReference = undefined;

    const npub_identifier = try @import("nip19_bech32.zig").nip19_encode(
        bech32_output[0..],
        .{ .npub = [_]u8{0x33} ** 32 },
    );
    const valid_uri = try to_nostr_uri(uri_output[0..], npub_identifier);
    const bare_identifier = npub_identifier;
    const broken = "nostr:npub1broken";
    const uppercase = "nostr:npub1DRVpZev3";
    const forbidden = "nostr:nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsyqcyq";
    const wrong_scheme = "NOSTR:npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq";
    const no_payload = "nostr:npub1";
    var text_buffer: [4 * limits.nip21_uri_bytes_max]u8 = undefined;
    const content = try std.fmt.bufPrint(
        text_buffer[0..],
        "{s} {s} {s} {s} {s} {s}+.] {s}",
        .{ broken, uppercase, forbidden, wrong_scheme, no_payload, valid_uri, bare_identifier },
    );

    const count = try reference_extract(content, references[0..], tlv_scratch[0..]);

    try std.testing.expectEqual(@as(u16, 1), count);
    try std.testing.expectEqualStrings(valid_uri, references[0].uri);
}

test "reference_extract ignores nrelay content pointers" {
    var bech32_output: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    var tlv_scratch: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var references: [1]ContentReference = undefined;

    const npub_identifier = try @import("nip19_bech32.zig").nip19_encode(
        bech32_output[0..],
        .{ .npub = [_]u8{0x55} ** 32 },
    );
    const valid_uri = try to_nostr_uri(uri_output[0..], npub_identifier);
    const nrelay_identifier = try @import("nip19_bech32.zig").nip19_encode(
        bech32_output[0..],
        .{ .nrelay = .{ .relay = "wss://relay.only" } },
    );
    var relay_uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    const relay_uri = try to_nostr_uri(relay_uri_output[0..], nrelay_identifier);
    var text_buffer: [2 * limits.nip21_uri_bytes_max + 16]u8 = undefined;
    const content = try std.fmt.bufPrint(text_buffer[0..], "{s} {s}", .{ relay_uri, valid_uri });

    const count = try reference_extract(content, references[0..], tlv_scratch[0..]);

    try std.testing.expectEqual(@as(u16, 1), count);
    try std.testing.expectEqualStrings(valid_uri, references[0].uri);
}

test "reference_extract returns typed buffer and scratch errors" {
    var bech32_output: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    var references: [0]ContentReference = undefined;
    var one_reference: [1]ContentReference = undefined;
    var too_small_scratch: [limits.nip19_tlv_scratch_bytes_max - 1]u8 = undefined;
    var empty_scratch: [0]u8 = undefined;

    const npub_identifier = try @import("nip19_bech32.zig").nip19_encode(
        bech32_output[0..],
        .{ .npub = [_]u8{0x44} ** 32 },
    );
    const valid_uri = try to_nostr_uri(uri_output[0..], npub_identifier);

    try std.testing.expectError(
        error.ScratchTooSmall,
        reference_extract(valid_uri, one_reference[0..], too_small_scratch[0..]),
    );
    try std.testing.expectError(
        error.BufferTooSmall,
        reference_extract(valid_uri, references[0..], empty_scratch[0..]),
    );
}

fn to_nostr_uri(output: []u8, identifier: []const u8) ![]const u8 {
    std.debug.assert(output.len <= limits.nip21_uri_bytes_max);
    std.debug.assert(identifier.len <= limits.nip19_bech32_identifier_bytes_max);

    const needed = limits.nip21_scheme_prefix_bytes + identifier.len;
    if (needed > output.len) {
        return error.NoSpaceLeft;
    }

    @memcpy(output[0..limits.nip21_scheme_prefix_bytes], "nostr:");
    @memcpy(output[limits.nip21_scheme_prefix_bytes..needed], identifier);
    return output[0..needed];
}
