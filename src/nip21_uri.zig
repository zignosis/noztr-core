const std = @import("std");
const limits = @import("limits.zig");
const nip19_bech32 = @import("nip19_bech32.zig");

pub const Nip21Error = error{ InvalidUri, InvalidScheme, ForbiddenEntity, InvalidEntityEncoding };

pub const Nip21Reference = struct {
    identifier: []const u8,
    entity: nip19_bech32.Nip19Entity,
};

/// Parses a strict `nostr:` URI containing exactly one NIP-19 entity identifier.
///
/// Lifetime and ownership:
/// - `Nip21Reference.identifier` always borrows from `input`.
/// - `Nip21Reference.entity` may borrow from `tlv_scratch` for TLV-backed fields
///   (for example `nprofile.relays`, `nevent.relays`, `naddr.identifier`,
///   `naddr.relays`, `nrelay.relay`).
/// - Keep both `input` and `tlv_scratch` alive and unmodified while using borrowed fields.
pub fn uri_parse(input: []const u8, tlv_scratch: []u8) Nip21Error!Nip21Reference {
    std.debug.assert(input.len <= std.math.maxInt(usize));
    std.debug.assert(tlv_scratch.len <= limits.nip19_tlv_scratch_bytes_max);

    if (input.len > limits.nip21_uri_bytes_max) {
        return error.InvalidUri;
    }
    if (!std.mem.startsWith(u8, input, "nostr:")) {
        return error.InvalidScheme;
    }

    const identifier = input[limits.nip21_scheme_prefix_bytes..];
    if (identifier.len == 0) {
        return error.InvalidUri;
    }
    if (has_forbidden_separator(identifier)) {
        return error.InvalidUri;
    }

    const entity = nip19_bech32.nip19_decode(identifier, tlv_scratch) catch |decode_error| {
        return map_nip19_decode_error(decode_error);
    };
    if (entity == .nsec) {
        return error.ForbiddenEntity;
    }

    return .{
        .identifier = identifier,
        .entity = entity,
    };
}

fn map_nip19_decode_error(decode_error: nip19_bech32.Nip19Error) Nip21Error {
    std.debug.assert(@typeInfo(nip19_bech32.Nip19Error) == .error_set);
    std.debug.assert(@typeInfo(Nip21Error) == .error_set);

    return switch (decode_error) {
        error.InvalidBech32,
        error.InvalidChecksum,
        error.MixedCase,
        error.InvalidPrefix,
        error.InvalidPayload,
        error.MissingRequiredTlv,
        error.MalformedKnownOptionalTlv,
        error.BufferTooSmall,
        error.ValueOutOfRange,
        => error.InvalidEntityEncoding,
    };
}

/// Returns true only when `input` is a strict and allowed NIP-21 URI.
pub fn uri_is_valid(input: []const u8, tlv_scratch: []u8) bool {
    std.debug.assert(input.len <= std.math.maxInt(usize));
    std.debug.assert(tlv_scratch.len <= limits.nip19_tlv_scratch_bytes_max);

    _ = uri_parse(input, tlv_scratch) catch {
        return false;
    };
    return true;
}

/// Compatibility alias for older NIP-21 parser naming.
pub const nip21_parse = uri_parse;

/// Compatibility alias for older NIP-21 validator naming.
pub const nip21_is_valid = uri_is_valid;

fn has_forbidden_separator(identifier: []const u8) bool {
    std.debug.assert(identifier.len <= limits.nip19_bech32_identifier_bytes_max);
    std.debug.assert(limits.nip21_scheme_prefix_bytes == 6);

    for (identifier) |char| {
        switch (char) {
            ':', '/', '?', '#', '%', ' ', '\t', '\r', '\n' => return true,
            else => {},
        }
    }
    return false;
}

fn to_nostr_uri(output: []u8, identifier: []const u8) Nip21Error![]const u8 {
    std.debug.assert(output.len <= limits.nip21_uri_bytes_max);
    std.debug.assert(identifier.len <= limits.nip19_bech32_identifier_bytes_max);

    const needed = @as(usize, limits.nip21_scheme_prefix_bytes) + identifier.len;
    if (needed > output.len) {
        return error.InvalidUri;
    }

    @memcpy(output[0..limits.nip21_scheme_prefix_bytes], "nostr:");
    @memcpy(output[limits.nip21_scheme_prefix_bytes..needed], identifier);
    return output[0..needed];
}

test "nip21 valid vectors parse strict nostr entities" {
    var bech32_output: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    var tlv_scratch: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;

    const npub_identifier = try nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{ .npub = [_]u8{0x11} ** 32 },
    );
    const npub_uri = try to_nostr_uri(uri_output[0..], npub_identifier);
    const npub_reference = try uri_parse(npub_uri, tlv_scratch[0..]);
    try std.testing.expect(npub_reference.entity == .npub);
    try std.testing.expectEqualStrings(npub_identifier, npub_reference.identifier);

    const note_identifier = try nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{ .note = [_]u8{0x22} ** 32 },
    );
    const note_uri = try to_nostr_uri(uri_output[0..], note_identifier);
    const note_reference = try uri_parse(note_uri, tlv_scratch[0..]);
    try std.testing.expect(note_reference.entity == .note);
    try std.testing.expectEqualStrings(note_identifier, note_reference.identifier);

    const nprofile_identifier = try nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{
            .nprofile = .{
                .pubkey = [_]u8{0x33} ** 32,
                .relays = .{},
            },
        },
    );
    const nprofile_uri = try to_nostr_uri(uri_output[0..], nprofile_identifier);
    const nprofile_reference = try uri_parse(nprofile_uri, tlv_scratch[0..]);
    try std.testing.expect(nprofile_reference.entity == .nprofile);
    try std.testing.expectEqualStrings(nprofile_identifier, nprofile_reference.identifier);

    const naddr_identifier = try nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{
            .naddr = .{
                .identifier = "",
                .pubkey = [_]u8{0x34} ** 32,
                .kind = 10002,
            },
        },
    );
    const naddr_uri = try to_nostr_uri(uri_output[0..], naddr_identifier);
    const naddr_reference = try uri_parse(naddr_uri, tlv_scratch[0..]);
    try std.testing.expect(naddr_reference.entity == .naddr);
    try std.testing.expectEqualStrings("", naddr_reference.entity.naddr.identifier);
    try std.testing.expectEqualStrings(naddr_identifier, naddr_reference.identifier);
}

test "nip21 invalid vectors reject scheme forbidden entity and malformed encoding" {
    var bech32_output: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    var tlv_scratch: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;

    try std.testing.expectError(
        error.InvalidScheme,
        uri_parse("http://example.com/nostr:npub1test", tlv_scratch[0..]),
    );

    const nsec_identifier = try nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{ .nsec = [_]u8{0x44} ** 32 },
    );
    const nsec_uri = try to_nostr_uri(uri_output[0..], nsec_identifier);
    try std.testing.expectError(error.ForbiddenEntity, uri_parse(nsec_uri, tlv_scratch[0..]));

    try std.testing.expectError(
        error.InvalidEntityEncoding,
        uri_parse("nostr:npub1notvalidchecksum", tlv_scratch[0..]),
    );
    try std.testing.expectError(
        error.InvalidEntityEncoding,
        uri_parse("nostr:Npub1notvalidchecksum", tlv_scratch[0..]),
    );
    try std.testing.expectError(
        error.InvalidEntityEncoding,
        uri_parse("nostr:npub", tlv_scratch[0..]),
    );

    try std.testing.expectError(error.InvalidUri, uri_parse("nostr:", tlv_scratch[0..]));
    const two_entities_uri =
        "nostr:npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq" ++
        "/note";
    try std.testing.expectError(error.InvalidUri, uri_parse(two_entities_uri, tlv_scratch[0..]));
}

test "nip21 maps nip19 decode failure classes deterministically" {
    try std.testing.expectEqual(
        error.InvalidEntityEncoding,
        map_nip19_decode_error(error.InvalidChecksum),
    );
    try std.testing.expectEqual(
        error.InvalidEntityEncoding,
        map_nip19_decode_error(error.MixedCase),
    );
}

test "uri_is_valid returns deterministic true and false" {
    var bech32_output: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    var uri_output: [limits.nip21_uri_bytes_max]u8 = undefined;
    var tlv_scratch: [limits.nip19_tlv_scratch_bytes_max]u8 = undefined;

    const npub_identifier = try nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{ .npub = [_]u8{0x55} ** 32 },
    );
    const valid_uri = try to_nostr_uri(uri_output[0..], npub_identifier);
    try std.testing.expect(uri_is_valid(valid_uri, tlv_scratch[0..]));
    try std.testing.expect(!uri_is_valid("http://example.com", tlv_scratch[0..]));
    try std.testing.expect(!uri_is_valid("nostr:npub1broken", tlv_scratch[0..]));
    try std.testing.expect(!uri_is_valid("nostr:", tlv_scratch[0..]));
}
