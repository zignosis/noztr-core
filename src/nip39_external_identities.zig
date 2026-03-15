const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip19_bech32 = @import("nip19_bech32.zig");

pub const identity_kind: u32 = 10011;

pub const Nip39Error = error{
    InvalidIdentityKind,
    InvalidIdentityTag,
    InvalidProvider,
    InvalidIdentity,
    InvalidProof,
    BufferTooSmall,
};

pub const IdentityProvider = enum {
    github,
    twitter,
    mastodon,
    telegram,

    pub fn as_text(self: IdentityProvider) []const u8 {
        std.debug.assert(@intFromEnum(self) <= std.math.maxInt(u8));
        std.debug.assert(@typeInfo(IdentityProvider).@"enum".fields.len == 4);

        return switch (self) {
            .github => "github",
            .twitter => "twitter",
            .mastodon => "mastodon",
            .telegram => "telegram",
        };
    }
};

pub const IdentityClaim = struct {
    provider: IdentityProvider,
    identity: []const u8,
    proof: []const u8,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    item_count: u8 = 0,
    platform_identity: [limits.tag_item_bytes_max]u8 = undefined,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts ordered NIP-39 identity claims from a kind-10011 event.
pub fn identity_claims_extract(
    event: *const nip01_event.Event,
    out: []IdentityClaim,
) Nip39Error!u16 {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out.len <= limits.tags_max);

    if (event.kind != identity_kind) return error.InvalidIdentityKind;

    var count: u16 = 0;
    for (event.tags) |tag| {
        if (!is_identity_tag(tag)) continue;
        if (count == out.len) return error.BufferTooSmall;
        out[count] = try parse_identity_tag(tag);
        count += 1;
    }
    return count;
}

/// Builds a canonical NIP-39 `i` tag.
pub fn identity_claim_build_tag(
    output: *BuiltTag,
    claim: *const IdentityClaim,
) Nip39Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(claim) != 0);

    try validate_claim(claim);
    output.items[0] = "i";
    output.items[1] = try build_platform_identity(output.platform_identity[0..], claim);
    output.items[2] = claim.proof;
    output.item_count = 3;
    return output.as_event_tag();
}

/// Builds the deterministic proof URL for a validated claim.
/// See `examples/nip39_example.zig` and `examples/identity_proof_recipe.zig`.
pub fn identity_claim_build_proof_url(
    output: []u8,
    claim: *const IdentityClaim,
) Nip39Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(claim) != 0);

    try validate_claim(claim);
    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();
    switch (claim.provider) {
        .github => try write_github_url(writer, claim),
        .twitter => try write_twitter_url(writer, claim),
        .mastodon => try write_mastodon_url(writer, claim),
        .telegram => try write_telegram_url(writer, claim),
    }
    return stream.getWritten();
}

/// Builds the deterministic proof text for a validated claim and public key.
/// See `examples/nip39_example.zig` and `examples/identity_proof_recipe.zig`.
pub fn identity_claim_build_expected_text(
    output: []u8,
    claim: *const IdentityClaim,
    pubkey: *const [32]u8,
) Nip39Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(claim) != 0);
    std.debug.assert(@intFromPtr(pubkey) != 0);

    try validate_claim(claim);
    var npub_buffer: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    const npub = nip19_bech32.nip19_encode(npub_buffer[0..], .{ .npub = pubkey.* }) catch {
        return error.BufferTooSmall;
    };
    return build_expected_text(output, claim.provider, npub);
}

fn is_identity_tag(tag: nip01_event.EventTag) bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 3);

    return tag.items.len > 0 and std.mem.eql(u8, tag.items[0], "i");
}

fn parse_identity_tag(tag: nip01_event.EventTag) Nip39Error!IdentityClaim {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 3);

    if (tag.items.len < 3) return error.InvalidIdentityTag;
    return parse_platform_identity(tag.items[1], tag.items[2]);
}

fn parse_platform_identity(platform_identity: []const u8, proof: []const u8) Nip39Error!IdentityClaim {
    std.debug.assert(platform_identity.len <= limits.tag_item_bytes_max);
    std.debug.assert(proof.len <= limits.tag_item_bytes_max);

    const separator = std.mem.indexOfScalar(u8, platform_identity, ':') orelse {
        return error.InvalidIdentityTag;
    };
    if (separator == 0 or separator + 1 >= platform_identity.len) return error.InvalidIdentityTag;

    const provider = try parse_provider(platform_identity[0..separator]);
    const identity = platform_identity[separator + 1 ..];
    const claim = IdentityClaim{
        .provider = provider,
        .identity = identity,
        .proof = proof,
    };
    try validate_claim(&claim);
    return claim;
}

fn parse_provider(text: []const u8) Nip39Error!IdentityProvider {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (std.mem.eql(u8, text, "github")) return .github;
    if (std.mem.eql(u8, text, "twitter")) return .twitter;
    if (std.mem.eql(u8, text, "mastodon")) return .mastodon;
    if (std.mem.eql(u8, text, "telegram")) return .telegram;
    return error.InvalidProvider;
}

fn validate_claim(claim: *const IdentityClaim) Nip39Error!void {
    std.debug.assert(@intFromPtr(claim) != 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    try validate_identity(claim.provider, claim.identity);
    try validate_proof(claim.provider, claim.proof);
}

fn validate_identity(provider: IdentityProvider, identity: []const u8) Nip39Error!void {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (identity.len > limits.tag_item_bytes_max) return error.InvalidIdentity;
    if (!std.unicode.utf8ValidateSlice(identity)) return error.InvalidIdentity;
    if (identity.len == 0) return error.InvalidIdentity;
    if (std.mem.indexOfScalar(u8, identity, ':') != null) return error.InvalidIdentity;
    if (contains_ascii_space(identity)) return error.InvalidIdentity;
    switch (provider) {
        .github, .twitter => if (!is_simple_identity(identity)) return error.InvalidIdentity,
        .mastodon => try validate_mastodon_identity(identity),
        .telegram => if (!is_decimal(identity)) return error.InvalidIdentity,
    }
}

fn validate_proof(provider: IdentityProvider, proof: []const u8) Nip39Error!void {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (proof.len > limits.tag_item_bytes_max) return error.InvalidProof;
    if (!std.unicode.utf8ValidateSlice(proof)) return error.InvalidProof;
    if (proof.len == 0) return error.InvalidProof;
    if (contains_ascii_space(proof)) return error.InvalidProof;
    switch (provider) {
        .github => if (std.mem.indexOfScalar(u8, proof, '/') != null) return error.InvalidProof,
        .twitter => if (!is_decimal(proof)) return error.InvalidProof,
        .mastodon => if (std.mem.indexOfScalar(u8, proof, '/') != null) return error.InvalidProof,
        .telegram => try validate_telegram_proof(proof),
    }
}

fn validate_mastodon_identity(identity: []const u8) Nip39Error!void {
    std.debug.assert(identity.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    const marker = std.mem.indexOf(u8, identity, "/@") orelse return error.InvalidIdentity;
    if (marker == 0) return error.InvalidIdentity;
    if (marker + 2 >= identity.len) return error.InvalidIdentity;
}

fn validate_telegram_proof(proof: []const u8) Nip39Error!void {
    std.debug.assert(proof.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    const separator = std.mem.indexOfScalar(u8, proof, '/') orelse return error.InvalidProof;
    if (separator == 0) return error.InvalidProof;
    if (separator + 1 >= proof.len) return error.InvalidProof;
    if (std.mem.indexOfScalarPos(u8, proof, separator + 1, '/') != null) return error.InvalidProof;
    if (!is_simple_identity(proof[0..separator])) return error.InvalidProof;
    if (!is_decimal(proof[separator + 1 ..])) return error.InvalidProof;
}

fn build_platform_identity(output: []u8, claim: *const IdentityClaim) Nip39Error![]const u8 {
    std.debug.assert(output.len <= limits.tag_item_bytes_max);
    std.debug.assert(@intFromPtr(claim) != 0);

    const provider_text = claim.provider.as_text();
    if (provider_text.len + 1 + claim.identity.len > output.len) {
        return error.InvalidIdentity;
    }
    var stream = std.io.fixedBufferStream(output);
    const writer = stream.writer();
    writer.print("{s}:{s}", .{ provider_text, claim.identity }) catch {
        return error.BufferTooSmall;
    };
    return stream.getWritten();
}

fn build_expected_text(
    output: []u8,
    provider: IdentityProvider,
    npub: []const u8,
) Nip39Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(npub.len <= limits.nip19_bech32_identifier_bytes_max);

    return switch (provider) {
        .github => std.fmt.bufPrint(
            output,
            "Verifying that I control the following Nostr public key: {s}",
            .{npub},
        ) catch return error.BufferTooSmall,
        .twitter => std.fmt.bufPrint(
            output,
            "Verifying my account on nostr My Public Key: \"{s}\"",
            .{npub},
        ) catch return error.BufferTooSmall,
        .mastodon, .telegram => std.fmt.bufPrint(
            output,
            "Verifying that I control the following Nostr public key: \"{s}\"",
            .{npub},
        ) catch return error.BufferTooSmall,
    };
}

fn write_github_url(writer: anytype, claim: *const IdentityClaim) Nip39Error!void {
    std.debug.assert(@intFromPtr(claim) != 0);
    std.debug.assert(claim.identity.len > 0);

    writer.print("https://gist.github.com/{s}/{s}", .{ claim.identity, claim.proof }) catch {
        return error.BufferTooSmall;
    };
}

fn write_twitter_url(writer: anytype, claim: *const IdentityClaim) Nip39Error!void {
    std.debug.assert(@intFromPtr(claim) != 0);
    std.debug.assert(claim.proof.len > 0);

    writer.print("https://twitter.com/{s}/status/{s}", .{ claim.identity, claim.proof }) catch {
        return error.BufferTooSmall;
    };
}

fn write_mastodon_url(writer: anytype, claim: *const IdentityClaim) Nip39Error!void {
    std.debug.assert(@intFromPtr(claim) != 0);
    std.debug.assert(claim.identity.len > 0);

    writer.print("https://{s}/{s}", .{ claim.identity, claim.proof }) catch {
        return error.BufferTooSmall;
    };
}

fn write_telegram_url(writer: anytype, claim: *const IdentityClaim) Nip39Error!void {
    std.debug.assert(@intFromPtr(claim) != 0);
    std.debug.assert(claim.proof.len > 0);

    writer.print("https://t.me/{s}", .{claim.proof}) catch return error.BufferTooSmall;
}

fn contains_ascii_space(text: []const u8) bool {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max >= limits.tag_item_bytes_max);

    for (text) |byte| {
        if (std.ascii.isWhitespace(byte)) return true;
    }
    return false;
}

fn is_decimal(text: []const u8) bool {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return false;
    for (text) |byte| {
        if (byte < '0' or byte > '9') return false;
    }
    return true;
}

fn is_simple_identity(text: []const u8) bool {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return false;
    for (text) |byte| {
        if (std.ascii.isAlphanumeric(byte)) continue;
        if (byte == '.' or byte == '_' or byte == '-') continue;
        return false;
    }
    return true;
}

fn test_event(tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(identity_kind <= std.math.maxInt(u32));

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = identity_kind,
        .tags = tags,
        .content = "",
        .sig = [_]u8{0} ** 64,
    };
}

test "identity claims extract ordered claims and ignore future extra items" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "i", "github:semisol", "9721ce4ee4fceb91c9711ca2a6c9a5ab" } },
        .{ .items = &.{ "title", "ignored" } },
        .{ .items = &.{ "i", "telegram:1087295469", "nostrdirectory/770", "future" } },
    };
    var claims: [2]IdentityClaim = undefined;

    const count = try identity_claims_extract(&test_event(tags[0..]), claims[0..]);

    try std.testing.expectEqual(@as(u16, 2), count);
    try std.testing.expect(claims[0].provider == .github);
    try std.testing.expectEqualStrings("semisol", claims[0].identity);
    try std.testing.expect(claims[1].provider == .telegram);
    try std.testing.expectEqualStrings("nostrdirectory/770", claims[1].proof);
}

test "identity claims extract rejects malformed tags and invalid kind" {
    const bad_provider = [_]nip01_event.EventTag{
        .{ .items = &.{ "i", "unknown:semisol", "proof" } },
    };
    const bad_proof = [_]nip01_event.EventTag{
        .{ .items = &.{ "i", "telegram:1087295469", "nostrdirectory/not-a-number" } },
    };
    const wrong_kind_event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = 0,
        .tags = bad_provider[0..],
        .content = "",
        .sig = [_]u8{0} ** 64,
    };
    var claims: [1]IdentityClaim = undefined;

    try std.testing.expectError(
        error.InvalidProvider,
        identity_claims_extract(&test_event(bad_provider[0..]), claims[0..]),
    );
    try std.testing.expectError(
        error.InvalidProof,
        identity_claims_extract(&test_event(bad_proof[0..]), claims[0..]),
    );
    try std.testing.expectError(
        error.InvalidIdentityKind,
        identity_claims_extract(&wrong_kind_event, claims[0..]),
    );
}

test "identity claim builders produce canonical tags urls and texts" {
    const claim = IdentityClaim{
        .provider = .github,
        .identity = "semisol",
        .proof = "9721ce4ee4fceb91c9711ca2a6c9a5ab",
    };
    const mastodon = IdentityClaim{
        .provider = .mastodon,
        .identity = "bitcoinhackers.org/@semisol",
        .proof = "109775066355589974",
    };
    const telegram = IdentityClaim{
        .provider = .telegram,
        .identity = "1087295469",
        .proof = "nostrdirectory/770",
    };
    var built_tag: BuiltTag = .{};
    var url_buffer: [256]u8 = undefined;
    var text_buffer: [256]u8 = undefined;
    var npub_buffer: [limits.nip19_bech32_identifier_bytes_max]u8 = undefined;
    const pubkey = [_]u8{0x22} ** 32;

    const tag = try identity_claim_build_tag(&built_tag, &claim);
    const github_url = try identity_claim_build_proof_url(url_buffer[0..], &claim);
    const github_text = try identity_claim_build_expected_text(text_buffer[0..], &claim, &pubkey);
    const npub = try nip19_bech32.nip19_encode(npub_buffer[0..], .{ .npub = pubkey });

    try std.testing.expectEqualStrings("i", tag.items[0]);
    try std.testing.expectEqualStrings("github:semisol", tag.items[1]);
    try std.testing.expectEqualStrings(
        "https://gist.github.com/semisol/9721ce4ee4fceb91c9711ca2a6c9a5ab",
        github_url,
    );
    try std.testing.expectEqualStrings(
        try std.fmt.bufPrint(url_buffer[0..], "Verifying that I control the following Nostr public key: {s}", .{npub}),
        github_text,
    );
    try std.testing.expectEqualStrings(
        "https://bitcoinhackers.org/@semisol/109775066355589974",
        try identity_claim_build_proof_url(url_buffer[0..], &mastodon),
    );
    try std.testing.expectEqualStrings(
        "https://t.me/nostrdirectory/770",
        try identity_claim_build_proof_url(url_buffer[0..], &telegram),
    );
}

test "identity claim builders reject overlong identity and proof on typed paths" {
    var built_tag: BuiltTag = .{};
    var long_identity: [limits.tag_item_bytes_max + 1]u8 = undefined;
    var long_proof: [limits.tag_item_bytes_max + 1]u8 = undefined;
    var edge_identity: [limits.tag_item_bytes_max]u8 = undefined;
    @memset(long_identity[0..], 'a');
    @memset(long_proof[0..], '1');
    @memset(edge_identity[0..], 'a');

    const invalid_identity = IdentityClaim{
        .provider = .github,
        .identity = long_identity[0..],
        .proof = "9721ce4ee4fceb91c9711ca2a6c9a5ab",
    };
    const invalid_proof = IdentityClaim{
        .provider = .twitter,
        .identity = "semisol",
        .proof = long_proof[0..],
    };
    const overflow_identity = IdentityClaim{
        .provider = .github,
        .identity = edge_identity[0..],
        .proof = "9721ce4ee4fceb91c9711ca2a6c9a5ab",
    };

    try std.testing.expectError(
        error.InvalidIdentity,
        identity_claim_build_tag(&built_tag, &invalid_identity),
    );
    try std.testing.expectError(
        error.InvalidProof,
        identity_claim_build_tag(&built_tag, &invalid_proof),
    );
    try std.testing.expectError(
        error.InvalidIdentity,
        identity_claim_build_tag(&built_tag, &overflow_identity),
    );
}
