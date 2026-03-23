const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_scheme = @import("internal/url_with_scheme.zig");

pub const informational_kind: u32 = 10019;
pub const nutzap_kind: u32 = 9321;
pub const redemption_kind: u32 = 7376;

pub const NutzapError = error{
    InvalidInformationalKind,
    InvalidNutzapKind,
    InvalidRedemptionKind,
    MissingPubkeyTag,
    DuplicatePubkeyTag,
    InvalidPubkeyTag,
    MissingRelayTag,
    InvalidRelayTag,
    MissingMintTag,
    InvalidMintTag,
    MissingProofTag,
    InvalidProofTag,
    DuplicateUnitTag,
    InvalidUnitTag,
    MissingMintUrlTag,
    DuplicateMintUrlTag,
    InvalidMintUrlTag,
    MissingRecipientTag,
    DuplicateRecipientTag,
    InvalidRecipientTag,
    DuplicateTargetEventTag,
    InvalidTargetEventTag,
    DuplicateTargetKindTag,
    InvalidTargetKindTag,
    TargetKindWithoutEvent,
    MissingRedeemedTag,
    InvalidRedeemedTag,
    MissingSenderTag,
    DuplicateSenderTag,
    InvalidSenderTag,
    BufferTooSmall,
};

pub const MintPreference = struct {
    url: []const u8,
    unit_count: u8 = 0,
    units: [limits.tag_items_max - 2][]const u8 = undefined,
};

pub const Informational = struct {
    relay_count: u16 = 0,
    mint_count: u16 = 0,
    locking_pubkey: [32]u8,
};

pub const TargetEvent = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const Nutzap = struct {
    content: []const u8,
    unit: []const u8,
    mint_url: []const u8,
    recipient_pubkey: [32]u8,
    proof_count: u16 = 0,
    target_event: ?TargetEvent = null,
    target_kind: ?u32 = null,
};

pub const Redemption = struct {
    content: []const u8,
    redeemed_count: u16 = 0,
    sender_pubkey: [32]u8,
};

pub const BuiltTag = struct {
    items: [limits.tag_items_max][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts bounded nutzap informational metadata from a kind-10019 event.
pub fn informational_extract(
    event: *const nip01_event.Event,
    out_relays: [][]const u8,
    out_mints: []MintPreference,
) NutzapError!Informational {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_relays.len <= limits.tags_max);

    if (event.kind != informational_kind) return error.InvalidInformationalKind;

    var info = Informational{ .locking_pubkey = undefined };
    var pubkey: ?[32]u8 = null;
    for (event.tags) |tag| try apply_informational_tag(tag, &info, &pubkey, out_relays, out_mints);
    if (info.relay_count == 0) return error.MissingRelayTag;
    if (info.mint_count == 0) return error.MissingMintTag;
    info.locking_pubkey = pubkey orelse return error.MissingPubkeyTag;
    return info;
}

/// Extracts bounded nutzap contract data from a kind-9321 event.
pub fn nutzap_extract(
    event: *const nip01_event.Event,
    out_proofs: [][]const u8,
) NutzapError!Nutzap {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_proofs.len <= limits.tags_max);

    if (event.kind != nutzap_kind) return error.InvalidNutzapKind;

    var info = Nutzap{
        .content = event.content,
        .unit = "sat",
        .mint_url = undefined,
        .recipient_pubkey = undefined,
    };
    var saw_mint = false;
    var saw_recipient = false;
    for (event.tags) |tag| try apply_nutzap_tag(tag, &info, &saw_mint, &saw_recipient, out_proofs);
    if (info.proof_count == 0) return error.MissingProofTag;
    if (!saw_mint) return error.MissingMintUrlTag;
    if (!saw_recipient) return error.MissingRecipientTag;
    if (info.target_kind != null and info.target_event == null) return error.TargetKindWithoutEvent;
    return info;
}

/// Extracts bounded redemption-marker linkage from a kind-7376 event.
pub fn redemption_extract(
    event: *const nip01_event.Event,
    out_redeemed: []TargetEvent,
) NutzapError!Redemption {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_redeemed.len <= limits.tags_max);

    if (event.kind != redemption_kind) return error.InvalidRedemptionKind;

    var sender: ?[32]u8 = null;
    var info = Redemption{ .content = event.content, .sender_pubkey = undefined };
    for (event.tags) |tag| try apply_redemption_tag(tag, &info, &sender, out_redeemed);
    if (info.redeemed_count == 0) return error.MissingRedeemedTag;
    info.sender_pubkey = sender orelse return error.MissingSenderTag;
    return info;
}

/// Builds a canonical informational `relay` tag.
pub fn informational_build_relay_tag(
    output: *BuiltTag,
    relay_url: []const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    output.items[0] = "relay";
    output.items[1] = parse_url(relay_url) catch return error.InvalidRelayTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical informational `mint` tag.
pub fn informational_build_mint_tag(
    output: *BuiltTag,
    mint_url: []const u8,
    units: []const []const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(units.len <= output.items.len - 2);

    output.items[0] = "mint";
    output.items[1] = parse_url(mint_url) catch return error.InvalidMintTag;
    output.item_count = 2;
    for (units) |unit| {
        output.items[output.item_count] = parse_unit(unit) catch return error.InvalidMintTag;
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a canonical informational `pubkey` tag.
pub fn informational_build_pubkey_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    _ = lower_hex_32.parse(pubkey_hex) catch return error.InvalidPubkeyTag;
    output.items[0] = "pubkey";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical nutzap `proof` tag.
pub fn nutzap_build_proof_tag(
    output: *BuiltTag,
    proof_json: []const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    output.items[0] = "proof";
    output.items[1] = parse_nonempty_utf8(proof_json) catch return error.InvalidProofTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical nutzap `unit` tag.
pub fn nutzap_build_unit_tag(
    output: *BuiltTag,
    unit: []const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    output.items[0] = "unit";
    output.items[1] = parse_unit(unit) catch return error.InvalidUnitTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical nutzap mint-URL `u` tag.
pub fn nutzap_build_mint_url_tag(
    output: *BuiltTag,
    mint_url: []const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    output.items[0] = "u";
    output.items[1] = parse_url(mint_url) catch return error.InvalidMintUrlTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical nutzap recipient `p` tag.
pub fn nutzap_build_recipient_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    _ = lower_hex_32.parse(pubkey_hex) catch return error.InvalidRecipientTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical nutzap target-event `e` tag.
pub fn nutzap_build_target_event_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    _ = lower_hex_32.parse(event_id_hex) catch return error.InvalidTargetEventTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidTargetEventTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical nutzap target-kind `k` tag.
pub fn nutzap_build_target_kind_tag(
    output: *BuiltTag,
    event_kind: u32,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_kind <= limits.kind_max);

    output.items[0] = "k";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{event_kind}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical redemption-marker `e` tag for a redeemed nutzap.
pub fn redemption_build_redeemed_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
    relay_hint: ?[]const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    _ = lower_hex_32.parse(event_id_hex) catch return error.InvalidRedeemedTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    if (relay_hint) |value| {
        output.items[2] = parse_url(value) catch return error.InvalidRedeemedTag;
        output.item_count = 3;
    }
    output.items[output.item_count] = "redeemed";
    output.item_count += 1;
    return output.as_event_tag();
}

/// Builds a canonical redemption-marker sender `p` tag.
pub fn redemption_build_sender_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
) NutzapError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == limits.tag_items_max);

    _ = lower_hex_32.parse(pubkey_hex) catch return error.InvalidSenderTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_informational_tag(
    tag: nip01_event.EventTag,
    info: *Informational,
    pubkey: *?[32]u8,
    out_relays: [][]const u8,
    out_mints: []MintPreference,
) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(pubkey) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "relay")) return append_relay(tag, info, out_relays);
    if (std.mem.eql(u8, tag.items[0], "mint")) return append_mint(tag, info, out_mints);
    if (std.mem.eql(u8, tag.items[0], "pubkey")) {
        if (pubkey.* != null) return error.DuplicatePubkeyTag;
        pubkey.* = parse_informational_pubkey(tag) catch return error.InvalidPubkeyTag;
    }
}

fn append_relay(
    tag: nip01_event.EventTag,
    info: *Informational,
    out_relays: [][]const u8,
) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.relay_count <= out_relays.len);

    if (tag.items.len != 2) return error.InvalidRelayTag;
    if (info.relay_count == out_relays.len) return error.BufferTooSmall;
    out_relays[info.relay_count] = parse_url(tag.items[1]) catch return error.InvalidRelayTag;
    info.relay_count += 1;
}

fn append_mint(
    tag: nip01_event.EventTag,
    info: *Informational,
    out_mints: []MintPreference,
) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.mint_count <= out_mints.len);

    if (tag.items.len < 2) return error.InvalidMintTag;
    if (info.mint_count == out_mints.len) return error.BufferTooSmall;

    var parsed = MintPreference{
        .url = parse_url(tag.items[1]) catch return error.InvalidMintTag,
    };
    const extra_count = tag.items.len - 2;
    if (extra_count > parsed.units.len) return error.InvalidMintTag;
    for (tag.items[2..], 0..) |unit, index| {
        parsed.units[index] = parse_unit(unit) catch return error.InvalidMintTag;
        parsed.unit_count += 1;
    }
    out_mints[info.mint_count] = parsed;
    info.mint_count += 1;
}

fn parse_informational_pubkey(tag: nip01_event.EventTag) error{InvalidTag}![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return lower_hex_32.parse(tag.items[1]) catch return error.InvalidTag;
}

fn apply_nutzap_tag(
    tag: nip01_event.EventTag,
    info: *Nutzap,
    saw_mint: *bool,
    saw_recipient: *bool,
    out_proofs: [][]const u8,
) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_mint) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "proof")) return append_proof(tag, info, out_proofs);
    if (std.mem.eql(u8, tag.items[0], "unit")) return parse_unit_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "u")) return parse_mint_url_tag(tag, info, saw_mint);
    if (std.mem.eql(u8, tag.items[0], "p")) return parse_recipient_tag(tag, info, saw_recipient);
    if (std.mem.eql(u8, tag.items[0], "e")) return parse_target_event_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "k")) return parse_target_kind_tag(tag, info);
}

fn append_proof(tag: nip01_event.EventTag, info: *Nutzap, out_proofs: [][]const u8) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.proof_count <= out_proofs.len);

    if (tag.items.len != 2) return error.InvalidProofTag;
    if (info.proof_count == out_proofs.len) return error.BufferTooSmall;
    out_proofs[info.proof_count] = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidProofTag;
    info.proof_count += 1;
}

fn parse_unit_tag(tag: nip01_event.EventTag, info: *Nutzap) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (!std.mem.eql(u8, info.unit, "sat")) return error.DuplicateUnitTag;
    if (tag.items.len != 2) return error.InvalidUnitTag;
    info.unit = parse_unit(tag.items[1]) catch return error.InvalidUnitTag;
}

fn parse_mint_url_tag(tag: nip01_event.EventTag, info: *Nutzap, saw_mint: *bool) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_mint) != 0);

    if (saw_mint.*) return error.DuplicateMintUrlTag;
    if (tag.items.len != 2) return error.InvalidMintUrlTag;
    info.mint_url = parse_url(tag.items[1]) catch return error.InvalidMintUrlTag;
    saw_mint.* = true;
}

fn parse_recipient_tag(
    tag: nip01_event.EventTag,
    info: *Nutzap,
    saw_recipient: *bool,
) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(saw_recipient) != 0);

    if (saw_recipient.*) return error.DuplicateRecipientTag;
    if (tag.items.len != 2) return error.InvalidRecipientTag;
    info.recipient_pubkey = lower_hex_32.parse(tag.items[1]) catch return error.InvalidRecipientTag;
    saw_recipient.* = true;
}

fn parse_target_event_tag(tag: nip01_event.EventTag, info: *Nutzap) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (info.target_event != null) return error.DuplicateTargetEventTag;
    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidTargetEventTag;
    info.target_event = .{
        .event_id = lower_hex_32.parse(tag.items[1]) catch return error.InvalidTargetEventTag,
        .relay_hint = if (tag.items.len == 3)
            parse_url(tag.items[2]) catch return error.InvalidTargetEventTag
        else
            null,
    };
}

fn parse_target_kind_tag(tag: nip01_event.EventTag, info: *Nutzap) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (info.target_kind != null) return error.DuplicateTargetKindTag;
    if (tag.items.len != 2) return error.InvalidTargetKindTag;
    info.target_kind = std.fmt.parseUnsigned(u32, tag.items[1], 10) catch {
        return error.InvalidTargetKindTag;
    };
}

fn apply_redemption_tag(
    tag: nip01_event.EventTag,
    info: *Redemption,
    sender: *?[32]u8,
    out_redeemed: []TargetEvent,
) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(sender) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "e")) return append_redeemed(tag, info, out_redeemed);
    if (std.mem.eql(u8, tag.items[0], "p")) {
        if (sender.* != null) return error.DuplicateSenderTag;
        sender.* = parse_redemption_sender(tag) catch return error.InvalidSenderTag;
    }
}

fn append_redeemed(
    tag: nip01_event.EventTag,
    info: *Redemption,
    out_redeemed: []TargetEvent,
) NutzapError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.redeemed_count <= out_redeemed.len);

    if (tag.items.len < 3 or tag.items.len > 4) return error.InvalidRedeemedTag;
    if (info.redeemed_count == out_redeemed.len) return error.BufferTooSmall;
    const relay_hint = if (tag.items.len == 4) tag.items[2] else null;
    const marker = if (tag.items.len == 4) tag.items[3] else tag.items[2];
    if (!std.mem.eql(u8, marker, "redeemed")) return error.InvalidRedeemedTag;
    out_redeemed[info.redeemed_count] = .{
        .event_id = lower_hex_32.parse(tag.items[1]) catch return error.InvalidRedeemedTag,
        .relay_hint = if (relay_hint) |value|
            parse_url(value) catch return error.InvalidRedeemedTag
        else
            null,
    };
    info.redeemed_count += 1;
}

fn parse_redemption_sender(tag: nip01_event.EventTag) error{InvalidTag}![32]u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len != 0);

    if (tag.items.len != 2) return error.InvalidTag;
    return lower_hex_32.parse(tag.items[1]) catch return error.InvalidTag;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_unit(text: []const u8) error{InvalidUnit}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidUnit;
    const unit = parse_nonempty_utf8(text) catch return error.InvalidUnit;
    for (unit) |byte| {
        if (std.ascii.isWhitespace(byte)) return error.InvalidUnit;
    }
    return unit;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return url_with_scheme.parse_utf8(text, limits.tag_item_bytes_max);
}

test "NIP-61 extracts informational metadata" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "relay", "wss://relay.one" } },
        .{ .items = &.{ "mint", "https://mint.example", "sat", "usd" } },
        .{ .items = &.{ "pubkey", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x61} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = informational_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x22} ** 64,
    };
    var relays: [1][]const u8 = undefined;
    var mints: [1]MintPreference = undefined;

    const info = try informational_extract(&event, relays[0..], mints[0..]);

    try std.testing.expectEqual(@as(u16, 1), info.relay_count);
    try std.testing.expectEqual(@as(u16, 1), info.mint_count);
    try std.testing.expectEqualStrings("https://mint.example", mints[0].url);
    try std.testing.expectEqual(@as(u8, 2), mints[0].unit_count);
}

test "NIP-61 extracts nutzaps and redemption markers" {
    const nutzap_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "proof", "{\"amount\":1}" } },
        .{ .items = &.{ "u", "https://mint.example" } },
        .{ .items = &.{ "p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } },
        .{ .items = &.{ "e", "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "wss://relay.one" } },
        .{ .items = &.{ "k", "1" } },
    };
    const nutzap = nip01_event.Event{
        .id = [_]u8{0x62} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = nutzap_kind,
        .tags = nutzap_tags[0..],
        .content = "Thanks",
        .sig = [_]u8{0x23} ** 64,
    };
    var proofs: [1][]const u8 = undefined;
    const info = try nutzap_extract(&nutzap, proofs[0..]);
    try std.testing.expectEqualStrings("sat", info.unit);
    try std.testing.expectEqual(@as(u16, 1), info.proof_count);
    try std.testing.expect(info.target_event != null);

    const redeemed_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd", "redeemed" } },
        .{ .items = &.{ "p", "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" } },
    };
    const redeemed = nip01_event.Event{
        .id = [_]u8{0x63} ** 32,
        .pubkey = [_]u8{0x13} ** 32,
        .created_at = 3,
        .kind = redemption_kind,
        .tags = redeemed_tags[0..],
        .content = "",
        .sig = [_]u8{0x24} ** 64,
    };
    var redeemed_out: [1]TargetEvent = undefined;
    const redeemed_info = try redemption_extract(&redeemed, redeemed_out[0..]);
    try std.testing.expectEqual(@as(u16, 1), redeemed_info.redeemed_count);
}

test "NIP-61 builds canonical tags" {
    var tag: BuiltTag = .{};

    const mint = try informational_build_mint_tag(&tag, "https://mint.example", &.{"sat"});
    try std.testing.expectEqualStrings("mint", mint.items[0]);
    try std.testing.expectEqualStrings("sat", mint.items[2]);

    const redeemed = try redemption_build_redeemed_tag(
        &tag,
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
        null,
    );
    try std.testing.expectEqualStrings("redeemed", redeemed.items[2]);
}

test "NIP-61 rejects overlong recipient builder input with typed error" {
    var built: BuiltTag = .{};
    const overlong = [_]u8{'a'} ** (limits.tag_item_bytes_max + 1);

    try std.testing.expectError(
        error.InvalidRecipientTag,
        nutzap_build_recipient_tag(&built, overlong[0..]),
    );
}
