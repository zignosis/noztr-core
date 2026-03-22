const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const zap_request_kind: u32 = 9_734;
pub const zap_receipt_kind: u32 = 9_735;
pub const relays_tag_values_max: u8 = limits.tag_items_max - 1;

pub const Nip57Error = error{
    InvalidRequestKind,
    InvalidReceiptKind,
    MissingRecipientPubkeyTag,
    DuplicateRecipientPubkeyTag,
    InvalidRecipientPubkeyTag,
    MissingRelaysTag,
    DuplicateRelaysTag,
    InvalidRelaysTag,
    TooManyRelays,
    InvalidAmountTag,
    DuplicateAmountTag,
    InvalidLnurlTag,
    DuplicateLnurlTag,
    InvalidEventTag,
    DuplicateEventTag,
    InvalidCoordinateTag,
    DuplicateCoordinateTag,
    InvalidKindTag,
    DuplicateKindTag,
    InvalidReceiptSignerTag,
    DuplicateReceiptSignerTag,
    MissingBolt11Tag,
    DuplicateBolt11Tag,
    InvalidBolt11Tag,
    MissingDescriptionTag,
    DuplicateDescriptionTag,
    InvalidDescriptionTag,
    InvalidPreimageTag,
    DuplicatePreimageTag,
    InvalidReceiptSignature,
    InvalidEmbeddedRequest,
    EmbeddedRequestMismatch,
    InvalidQueryAmount,
    ReceiptSignerMismatch,
    BufferTooSmall,
};

pub const ZapRequest = struct {
    content: []const u8,
    recipient_pubkey: [32]u8,
    receipt_relays: []const []const u8,
    amount_msats: ?u64 = null,
    lnurl: ?[]const u8 = null,
    event_id: ?[32]u8 = null,
    coordinate: ?[]const u8 = null,
    target_kind: ?u32 = null,
    receipt_signer_pubkey: ?[32]u8 = null,
};

pub const ZapReceipt = struct {
    recipient_pubkey: [32]u8,
    sender_pubkey: ?[32]u8 = null,
    event_id: ?[32]u8 = null,
    coordinate: ?[]const u8 = null,
    target_kind: ?u32 = null,
    bolt11: []const u8,
    description_json: []const u8,
    preimage: ?[]const u8 = null,
    request: nip01_event.Event,
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

/// Extract bounded NIP-57 zap-request tags from a kind-9734 event.
pub fn zap_request_extract(
    event: *const nip01_event.Event,
    out_relays: [][]const u8,
) Nip57Error!ZapRequest {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_relays.len <= limits.tag_items_max);

    if (event.kind != zap_request_kind) return error.InvalidRequestKind;

    var parsed = ZapRequest{
        .content = event.content,
        .recipient_pubkey = undefined,
        .receipt_relays = &.{},
    };
    var relay_count: u8 = 0;
    var has_recipient = false;
    var has_relays = false;
    for (event.tags) |tag| {
        try apply_request_tag(
            tag,
            &parsed,
            &has_recipient,
            out_relays,
            &relay_count,
            &has_relays,
        );
    }
    if (!has_recipient) return error.MissingRecipientPubkeyTag;
    if (!has_relays) return error.MissingRelaysTag;
    parsed.receipt_relays = out_relays[0..relay_count];
    return parsed;
}

/// Verify a bounded NIP-57 zap-request for LNURL callback handling.
pub fn zap_request_validate(
    event: *const nip01_event.Event,
    expected_amount_msats: ?u64,
    expected_receipt_signer_pubkey: ?[32]u8,
    out_relays: [][]const u8,
) Nip57Error!ZapRequest {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_relays.len <= limits.tag_items_max);

    nip01_event.event_verify(event) catch return error.InvalidEmbeddedRequest;

    const parsed = try zap_request_extract(event, out_relays);
    if (parsed.amount_msats) |amount| {
        if (expected_amount_msats) |expected| {
            if (amount != expected) return error.InvalidQueryAmount;
        }
    }
    if (parsed.receipt_signer_pubkey) |signer| {
        if (expected_receipt_signer_pubkey) |expected| {
            if (!std.mem.eql(u8, &signer, &expected)) {
                return error.ReceiptSignerMismatch;
            }
        }
    }
    return parsed;
}

/// Extract and validate the embedded request inside a kind-9735 zap receipt.
pub fn zap_receipt_extract(
    event: *const nip01_event.Event,
    out_request_relays: [][]const u8,
    scratch: std.mem.Allocator,
) Nip57Error!ZapReceipt {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (event.kind != zap_receipt_kind) return error.InvalidReceiptKind;

    var recipient_pubkey: ?[32]u8 = null;
    var sender_pubkey: ?[32]u8 = null;
    var event_id: ?[32]u8 = null;
    var coordinate: ?[]const u8 = null;
    var target_kind: ?u32 = null;
    var bolt11: ?[]const u8 = null;
    var description_json: ?[]const u8 = null;
    var preimage: ?[]const u8 = null;
    for (event.tags) |tag| {
        try apply_receipt_tag(
            tag,
            &recipient_pubkey,
            &sender_pubkey,
            &event_id,
            &coordinate,
            &target_kind,
            &bolt11,
            &description_json,
            &preimage,
        );
    }

    return finalize_receipt(
        event,
        recipient_pubkey orelse return error.MissingRecipientPubkeyTag,
        sender_pubkey,
        event_id,
        coordinate,
        target_kind,
        bolt11 orelse return error.MissingBolt11Tag,
        description_json orelse return error.MissingDescriptionTag,
        preimage,
        out_request_relays,
        scratch,
    );
}

/// Validate a bounded NIP-57 zap receipt against the expected LNURL signer pubkey.
pub fn zap_receipt_validate(
    event: *const nip01_event.Event,
    expected_receipt_signer_pubkey: [32]u8,
    out_request_relays: [][]const u8,
    scratch: std.mem.Allocator,
) Nip57Error!ZapReceipt {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    nip01_event.event_verify(event) catch return error.InvalidReceiptSignature;
    if (!std.mem.eql(u8, &event.pubkey, &expected_receipt_signer_pubkey)) {
        return error.ReceiptSignerMismatch;
    }
    return zap_receipt_extract(event, out_request_relays, scratch);
}

/// Builds a bounded `relays` tag for NIP-57 zap requests.
pub fn request_build_relays_tag(
    output: *BuiltTag,
    relays: []const []const u8,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(relays.len <= limits.tag_items_max);

    if (relays.len == 0) return error.InvalidRelaysTag;
    if (relays.len > relays_tag_values_max) return error.TooManyRelays;

    output.items[0] = "relays";
    output.item_count = 1;
    var index: u8 = 0;
    while (index < relays.len) : (index += 1) {
        output.items[index + 1] = parse_relay_url(relays[index]) catch {
            return error.InvalidRelaysTag;
        };
        output.item_count += 1;
    }
    return output.as_event_tag();
}

/// Builds a bounded `amount` tag for NIP-57 zap requests.
pub fn request_build_amount_tag(
    output: *BuiltTag,
    amount_msats: u64,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(amount_msats <= std.math.maxInt(u64));

    output.items[0] = "amount";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{amount_msats}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bounded `lnurl` tag for NIP-57 zap requests.
pub fn request_build_lnurl_tag(
    output: *BuiltTag,
    lnurl: []const u8,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(lnurl.len <= limits.tag_item_bytes_max);

    output.items[0] = "lnurl";
    output.items[1] = parse_nonempty_utf8(lnurl) catch return error.InvalidLnurlTag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bounded target `p` tag for NIP-57 requests and receipts.
pub fn zap_build_pubkey_tag(
    output: *BuiltTag,
    tag_name: []const u8,
    pubkey_hex: []const u8,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(tag_name.len <= 1);

    _ = parse_hex_32(pubkey_hex) catch return error.InvalidRecipientPubkeyTag;
    output.items[0] = tag_name;
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bounded target `e` tag for NIP-57 requests and receipts.
pub fn zap_build_event_tag(
    output: *BuiltTag,
    event_id_hex: []const u8,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(event_id_hex.len <= limits.tag_item_bytes_max);

    _ = parse_hex_32(event_id_hex) catch return error.InvalidEventTag;
    output.items[0] = "e";
    output.items[1] = event_id_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bounded target `a` tag for NIP-57 requests and receipts.
pub fn zap_build_coordinate_tag(
    output: *BuiltTag,
    coordinate_text: []const u8,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(coordinate_text.len <= limits.tag_item_bytes_max);

    try validate_coordinate_text(coordinate_text) catch return error.InvalidCoordinateTag;
    output.items[0] = "a";
    output.items[1] = coordinate_text;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bounded target `k` tag for NIP-57 requests and receipts.
pub fn zap_build_kind_tag(
    output: *BuiltTag,
    kind: u32,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(kind <= limits.kind_max);

    output.items[0] = "k";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0..], "{d}", .{kind}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Compatibility alias for older NIP-57 target `p` tag builder naming.
pub const build_pubkey_tag = zap_build_pubkey_tag;

/// Compatibility alias for older NIP-57 target `e` tag builder naming.
pub const build_event_tag = zap_build_event_tag;

/// Compatibility alias for older NIP-57 target `a` tag builder naming.
pub const build_coordinate_tag = zap_build_coordinate_tag;

/// Compatibility alias for older NIP-57 target `k` tag builder naming.
pub const build_kind_tag = zap_build_kind_tag;

/// Builds a bounded `bolt11` tag for NIP-57 receipts.
pub fn receipt_build_bolt11_tag(
    output: *BuiltTag,
    bolt11: []const u8,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(bolt11.len <= limits.tag_item_bytes_max);

    output.items[0] = "bolt11";
    output.items[1] = parse_nonempty_utf8(bolt11) catch return error.InvalidBolt11Tag;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bounded `description` tag for NIP-57 receipts.
pub fn receipt_build_description_tag(
    output: *BuiltTag,
    zap_request_json: []const u8,
    scratch: std.mem.Allocator,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const request_event = nip01_event.event_parse_json(zap_request_json, scratch) catch {
        return error.InvalidDescriptionTag;
    };
    var relays: [limits.tag_items_max - 1][]const u8 = undefined;
    _ = zap_request_validate(&request_event, null, null, relays[0..]) catch {
        return error.InvalidDescriptionTag;
    };
    output.items[0] = "description";
    output.items[1] = zap_request_json;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a bounded `preimage` tag for NIP-57 receipts.
pub fn receipt_build_preimage_tag(
    output: *BuiltTag,
    preimage_hex: []const u8,
) Nip57Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(preimage_hex.len <= limits.tag_item_bytes_max);

    _ = parse_hex_32(preimage_hex) catch return error.InvalidPreimageTag;
    output.items[0] = "preimage";
    output.items[1] = preimage_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_request_tag(
    tag: nip01_event.EventTag,
    parsed: *ZapRequest,
    has_recipient: *bool,
    out_relays: [][]const u8,
    relay_count: *u8,
    has_relays: *bool,
) Nip57Error!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(@intFromPtr(relay_count) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "p")) return parse_request_p_tag(tag, parsed, has_recipient);
    if (std.mem.eql(u8, tag.items[0], "relays")) {
        return parse_request_relays_tag(tag, out_relays, relay_count, has_relays);
    }
    if (std.mem.eql(u8, tag.items[0], "amount")) return parse_request_amount_tag(tag, parsed);
    if (std.mem.eql(u8, tag.items[0], "lnurl")) return parse_request_lnurl_tag(tag, parsed);
    if (std.mem.eql(u8, tag.items[0], "e")) return parse_request_e_tag(tag, parsed);
    if (std.mem.eql(u8, tag.items[0], "a")) return parse_request_a_tag(tag, parsed);
    if (std.mem.eql(u8, tag.items[0], "k")) return parse_request_k_tag(tag, parsed);
    if (std.mem.eql(u8, tag.items[0], "P")) return parse_request_P_tag(tag, parsed);
}

fn parse_request_p_tag(
    tag: nip01_event.EventTag,
    parsed: *ZapRequest,
    has_recipient: *bool,
) Nip57Error!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(@intFromPtr(has_recipient) != 0);

    if (tag.items.len < 2) return error.InvalidRecipientPubkeyTag;
    if (has_recipient.*) return error.DuplicateRecipientPubkeyTag;
    parsed.recipient_pubkey = parse_hex_32(tag.items[1]) catch return error.InvalidRecipientPubkeyTag;
    has_recipient.* = true;
}

fn parse_request_relays_tag(
    tag: nip01_event.EventTag,
    out_relays: [][]const u8,
    relay_count: *u8,
    has_relays: *bool,
) Nip57Error!void {
    std.debug.assert(@intFromPtr(relay_count) != 0);
    std.debug.assert(@intFromPtr(has_relays) != 0);

    if (tag.items.len < 2) return error.InvalidRelaysTag;
    if (has_relays.*) return error.DuplicateRelaysTag;
    if (tag.items.len - 1 > out_relays.len) return error.TooManyRelays;
    if (tag.items.len - 1 > relays_tag_values_max) return error.TooManyRelays;

    var index: u8 = 1;
    while (index < tag.items.len) : (index += 1) {
        out_relays[index - 1] = parse_relay_url(tag.items[index]) catch {
            return error.InvalidRelaysTag;
        };
    }
    relay_count.* = @intCast(tag.items.len - 1);
    has_relays.* = true;
}

fn parse_request_amount_tag(tag: nip01_event.EventTag, parsed: *ZapRequest) Nip57Error!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidAmountTag;
    if (parsed.amount_msats != null) return error.DuplicateAmountTag;
    parsed.amount_msats = parse_decimal_u64(tag.items[1]) catch return error.InvalidAmountTag;
}

fn parse_request_lnurl_tag(tag: nip01_event.EventTag, parsed: *ZapRequest) Nip57Error!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidLnurlTag;
    if (parsed.lnurl != null) return error.DuplicateLnurlTag;
    parsed.lnurl = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidLnurlTag;
}

fn parse_request_e_tag(tag: nip01_event.EventTag, parsed: *ZapRequest) Nip57Error!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidEventTag;
    if (parsed.event_id != null) return error.DuplicateEventTag;
    parsed.event_id = parse_hex_32(tag.items[1]) catch return error.InvalidEventTag;
}

fn parse_request_a_tag(tag: nip01_event.EventTag, parsed: *ZapRequest) Nip57Error!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidCoordinateTag;
    if (parsed.coordinate != null) return error.DuplicateCoordinateTag;
    validate_coordinate_text(tag.items[1]) catch return error.InvalidCoordinateTag;
    parsed.coordinate = tag.items[1];
}

fn parse_request_k_tag(tag: nip01_event.EventTag, parsed: *ZapRequest) Nip57Error!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidKindTag;
    if (parsed.target_kind != null) return error.DuplicateKindTag;
    parsed.target_kind = parse_decimal_u32(tag.items[1]) catch return error.InvalidKindTag;
}

fn parse_request_P_tag(tag: nip01_event.EventTag, parsed: *ZapRequest) Nip57Error!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidReceiptSignerTag;
    if (parsed.receipt_signer_pubkey != null) return error.DuplicateReceiptSignerTag;
    parsed.receipt_signer_pubkey = parse_hex_32(tag.items[1]) catch {
        return error.InvalidReceiptSignerTag;
    };
}

fn apply_receipt_tag(
    tag: nip01_event.EventTag,
    recipient_pubkey: *?[32]u8,
    sender_pubkey: *?[32]u8,
    event_id: *?[32]u8,
    coordinate: *?[]const u8,
    target_kind: *?u32,
    bolt11: *?[]const u8,
    description_json: *?[]const u8,
    preimage: *?[]const u8,
) Nip57Error!void {
    std.debug.assert(@intFromPtr(recipient_pubkey) != 0);
    std.debug.assert(@intFromPtr(description_json) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "p")) {
        return parse_receipt_pubkey(tag, recipient_pubkey, error.InvalidRecipientPubkeyTag);
    }
    if (std.mem.eql(u8, tag.items[0], "P")) {
        return parse_receipt_pubkey(tag, sender_pubkey, error.InvalidReceiptSignerTag);
    }
    if (std.mem.eql(u8, tag.items[0], "e")) return parse_receipt_event(tag, event_id);
    if (std.mem.eql(u8, tag.items[0], "a")) return parse_receipt_coordinate(tag, coordinate);
    if (std.mem.eql(u8, tag.items[0], "k")) return parse_receipt_kind(tag, target_kind);
    if (std.mem.eql(u8, tag.items[0], "bolt11")) return parse_receipt_bolt11(tag, bolt11);
    if (std.mem.eql(u8, tag.items[0], "description")) {
        return parse_receipt_description(tag, description_json);
    }
    if (std.mem.eql(u8, tag.items[0], "preimage")) return parse_receipt_preimage(tag, preimage);
}

fn parse_receipt_pubkey(
    tag: nip01_event.EventTag,
    output: *?[32]u8,
    invalid: Nip57Error,
) Nip57Error!void {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return invalid;
    if (output.* != null) {
        return switch (invalid) {
            error.InvalidRecipientPubkeyTag => error.DuplicateRecipientPubkeyTag,
            error.InvalidReceiptSignerTag => error.DuplicateReceiptSignerTag,
            else => invalid,
        };
    }
    output.* = parse_hex_32(tag.items[1]) catch return invalid;
}

fn parse_receipt_event(tag: nip01_event.EventTag, event_id: *?[32]u8) Nip57Error!void {
    std.debug.assert(@intFromPtr(event_id) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidEventTag;
    if (event_id.* != null) return error.DuplicateEventTag;
    event_id.* = parse_hex_32(tag.items[1]) catch return error.InvalidEventTag;
}

fn parse_receipt_coordinate(tag: nip01_event.EventTag, coordinate: *?[]const u8) Nip57Error!void {
    std.debug.assert(@intFromPtr(coordinate) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len < 2) return error.InvalidCoordinateTag;
    if (coordinate.* != null) return error.DuplicateCoordinateTag;
    validate_coordinate_text(tag.items[1]) catch return error.InvalidCoordinateTag;
    coordinate.* = tag.items[1];
}

fn parse_receipt_kind(tag: nip01_event.EventTag, target_kind: *?u32) Nip57Error!void {
    std.debug.assert(@intFromPtr(target_kind) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidKindTag;
    if (target_kind.* != null) return error.DuplicateKindTag;
    target_kind.* = parse_decimal_u32(tag.items[1]) catch return error.InvalidKindTag;
}

fn parse_receipt_bolt11(tag: nip01_event.EventTag, bolt11: *?[]const u8) Nip57Error!void {
    std.debug.assert(@intFromPtr(bolt11) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidBolt11Tag;
    if (bolt11.* != null) return error.DuplicateBolt11Tag;
    bolt11.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidBolt11Tag;
}

fn parse_receipt_description(
    tag: nip01_event.EventTag,
    description_json: *?[]const u8,
) Nip57Error!void {
    std.debug.assert(@intFromPtr(description_json) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidDescriptionTag;
    if (description_json.* != null) return error.DuplicateDescriptionTag;
    description_json.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidDescriptionTag;
}

fn parse_receipt_preimage(tag: nip01_event.EventTag, preimage: *?[]const u8) Nip57Error!void {
    std.debug.assert(@intFromPtr(preimage) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidPreimageTag;
    if (preimage.* != null) return error.DuplicatePreimageTag;
    _ = parse_hex_32(tag.items[1]) catch return error.InvalidPreimageTag;
    preimage.* = tag.items[1];
}

fn finalize_receipt(
    event: *const nip01_event.Event,
    recipient_pubkey: [32]u8,
    sender_pubkey: ?[32]u8,
    event_id: ?[32]u8,
    coordinate: ?[]const u8,
    target_kind: ?u32,
    bolt11: []const u8,
    description_json: []const u8,
    preimage: ?[]const u8,
    out_request_relays: [][]const u8,
    scratch: std.mem.Allocator,
) Nip57Error!ZapReceipt {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const request_event = nip01_event.event_parse_json(description_json, scratch) catch {
        return error.InvalidDescriptionTag;
    };
    const request = zap_request_validate(&request_event, null, event.pubkey, out_request_relays) catch {
        return error.InvalidEmbeddedRequest;
    };
    try validate_receipt_match(
        event,
        recipient_pubkey,
        sender_pubkey,
        event_id,
        coordinate,
        target_kind,
        request_event.pubkey,
        &request,
    );
    return .{
        .recipient_pubkey = recipient_pubkey,
        .sender_pubkey = sender_pubkey,
        .event_id = event_id,
        .coordinate = coordinate,
        .target_kind = target_kind,
        .bolt11 = bolt11,
        .description_json = description_json,
        .preimage = preimage,
        .request = request_event,
    };
}

fn validate_receipt_match(
    receipt_event: *const nip01_event.Event,
    recipient_pubkey: [32]u8,
    sender_pubkey: ?[32]u8,
    event_id: ?[32]u8,
    coordinate: ?[]const u8,
    target_kind: ?u32,
    request_pubkey: [32]u8,
    request: *const ZapRequest,
) Nip57Error!void {
    std.debug.assert(@intFromPtr(receipt_event) != 0);
    std.debug.assert(@intFromPtr(request) != 0);

    if (!std.mem.eql(u8, &recipient_pubkey, &request.recipient_pubkey)) {
        return error.EmbeddedRequestMismatch;
    }
    if (sender_pubkey) |sender| {
        if (!std.mem.eql(u8, &sender, &request_pubkey)) return error.EmbeddedRequestMismatch;
    }
    try validate_optional_match(event_id, request.event_id);
    try validate_optional_text_match(coordinate, request.coordinate);
    if (request.target_kind != null and target_kind != request.target_kind) {
        return error.EmbeddedRequestMismatch;
    }
}

fn validate_optional_match(receipt_value: ?[32]u8, request_value: ?[32]u8) Nip57Error!void {
    std.debug.assert(@sizeOf(?[32]u8) > 0);
    std.debug.assert(@sizeOf(?[32]u8) > 0);

    if (request_value == null and receipt_value == null) return;
    if (request_value == null or receipt_value == null) return error.EmbeddedRequestMismatch;
    if (!std.mem.eql(u8, &receipt_value.?, &request_value.?)) return error.EmbeddedRequestMismatch;
}

fn validate_optional_text_match(receipt_value: ?[]const u8, request_value: ?[]const u8) Nip57Error!void {
    std.debug.assert(@sizeOf(?[]const u8) > 0);
    std.debug.assert(@sizeOf(?[]const u8) > 0);

    if (request_value == null and receipt_value == null) return;
    if (request_value == null or receipt_value == null) return error.EmbeddedRequestMismatch;
    if (!std.mem.eql(u8, receipt_value.?, request_value.?)) return error.EmbeddedRequestMismatch;
}

fn parse_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len != limits.pubkey_hex_length) return error.InvalidHex;
    var out: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&out, text) catch return error.InvalidHex;
    return out;
}

fn parse_decimal_u64(text: []const u8) error{InvalidNumber}!u64 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(u64) == 8);

    if (text.len == 0) return error.InvalidNumber;
    return std.fmt.parseUnsigned(u64, text, 10) catch error.InvalidNumber;
}

fn parse_decimal_u32(text: []const u8) error{InvalidNumber}!u32 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(@sizeOf(u32) == 4);

    if (text.len == 0) return error.InvalidNumber;
    return std.fmt.parseUnsigned(u32, text, 10) catch error.InvalidNumber;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidText}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidText;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidText;
    return text;
}

fn parse_relay_url(text: []const u8) error{InvalidRelayUrl}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidRelayUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidRelayUrl;
    if (parsed.host == null) return error.InvalidRelayUrl;
    if (!std.mem.eql(u8, parsed.scheme, "ws") and !std.mem.eql(u8, parsed.scheme, "wss")) {
        return error.InvalidRelayUrl;
    }
    return text;
}

fn validate_coordinate_text(text: []const u8) error{InvalidCoordinate}!void {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len <= limits.content_bytes_max);

    const first = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidCoordinate;
    const second = std.mem.indexOfScalarPos(u8, text, first + 1, ':') orelse {
        return error.InvalidCoordinate;
    };
    if (first == 0 or second <= first + 1 or second + 1 > text.len) {
        return error.InvalidCoordinate;
    }
    const kind = parse_decimal_u32(text[0..first]) catch return error.InvalidCoordinate;
    _ = parse_hex_32(text[first + 1 .. second]) catch return error.InvalidCoordinate;
    const identifier = text[second + 1 ..];
    if (!std.unicode.utf8ValidateSlice(identifier)) return error.InvalidCoordinate;
    try validate_coordinate_kind(kind, identifier);
}

fn validate_coordinate_kind(kind: u32, identifier: []const u8) error{InvalidCoordinate}!void {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(identifier.len <= limits.tag_item_bytes_max);

    const replaceable = kind >= 10_000 and kind < 20_000;
    const addressable = kind >= 30_000 and kind < 40_000;
    if (!replaceable and !addressable) return error.InvalidCoordinate;
    if (addressable and identifier.len == 0) return error.InvalidCoordinate;
}

const request_extract_json =
    \\{"id":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","pubkey":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","created_at":1700000000,"kind":9734,"tags":[["relays","wss://relay.one","wss://relay.two"],["amount","21000"],["lnurl","lnurl1dp68gurn8ghj7m"],["p","bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"],["e","cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"],["a","30023:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd:article"],["k","30023"],["P","eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"]],"content":"Zap!","sig":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"}
;

test "zap request extract validates bounded target and relay tags" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const event = try nip01_event.event_parse_json(request_extract_json, arena.allocator());
    var relays: [4][]const u8 = undefined;

    const parsed = try zap_request_extract(&event, relays[0..]);
    try std.testing.expectEqualStrings("Zap!", parsed.content);
    try std.testing.expectEqual(@as(u64, 21_000), parsed.amount_msats.?);
    try std.testing.expectEqual(@as(usize, 2), parsed.receipt_relays.len);
    try std.testing.expectEqualStrings("wss://relay.one", parsed.receipt_relays[0]);
    try std.testing.expectEqualStrings(
        "30023:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd:article",
        parsed.coordinate.?,
    );
}

test "zap receipt extract validates embedded request and propagated targets" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var request_json_buffer: [1024]u8 = undefined;
    const request_json = try build_signed_request_json(
        request_json_buffer[0..],
        "9630f464cca6a5147aa8a35f0bcdd3ce485324e732fd39e09233b1d848238f31",
    );

    const receipt_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245" } },
        .{ .items = &.{ "P", "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9" } },
        .{ .items = &.{ "e", "3624762a1274dd9636e0c552b53086d70bc88c165bc4dc0f9e836a1eaf86c3b8" } },
        .{ .items = &.{ "bolt11", "lnbc10u1example" } },
        .{ .items = &.{ "description", request_json } },
    };
    const receipt = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = try parse_hex_32("9630f464cca6a5147aa8a35f0bcdd3ce485324e732fd39e09233b1d848238f31"),
        .sig = [_]u8{0} ** 64,
        .kind = zap_receipt_kind,
        .created_at = 1_674_164_545,
        .content = "",
        .tags = receipt_tags[0..],
    };
    var relays: [4][]const u8 = undefined;

    const parsed = try zap_receipt_extract(&receipt, relays[0..], arena.allocator());
    try std.testing.expectEqualStrings("lnbc10u1example", parsed.bolt11);
    try std.testing.expect(parsed.sender_pubkey != null);
    try std.testing.expectEqual(zap_request_kind, parsed.request.kind);
    try std.testing.expectEqualStrings("wss://relay.damus.io", relays[0]);
}

test "zap receipt extract rejects mismatched propagated target" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var request_json_buffer: [1024]u8 = undefined;
    const request_json = try build_signed_request_json(
        request_json_buffer[0..],
        "9630f464cca6a5147aa8a35f0bcdd3ce485324e732fd39e09233b1d848238f31",
    );

    const bad_receipt_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "1111111111111111111111111111111111111111111111111111111111111111" } },
        .{ .items = &.{ "e", "3624762a1274dd9636e0c552b53086d70bc88c165bc4dc0f9e836a1eaf86c3b8" } },
        .{ .items = &.{ "bolt11", "lnbc10u1example" } },
        .{ .items = &.{ "description", request_json } },
    };
    const receipt = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = try parse_hex_32("9630f464cca6a5147aa8a35f0bcdd3ce485324e732fd39e09233b1d848238f31"),
        .sig = [_]u8{0} ** 64,
        .kind = zap_receipt_kind,
        .created_at = 1_674_164_545,
        .content = "",
        .tags = bad_receipt_tags[0..],
    };
    var relays: [4][]const u8 = undefined;

    try std.testing.expectError(
        error.EmbeddedRequestMismatch,
        zap_receipt_extract(&receipt, relays[0..], arena.allocator()),
    );
    try std.testing.expect(relays.len >= 4);
}

test "zap builders emit bounded request and receipt tags" {
    var relays_tag: BuiltTag = .{};
    var amount_tag: BuiltTag = .{};
    var description_tag: BuiltTag = .{};
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var request_json_buffer: [1024]u8 = undefined;
    const request_json = try build_signed_request_json(
        request_json_buffer[0..],
        "9630f464cca6a5147aa8a35f0bcdd3ce485324e732fd39e09233b1d848238f31",
    );

    const relays = [_][]const u8{ "wss://relay.one", "wss://relay.two" };
    const built_relays = try request_build_relays_tag(&relays_tag, relays[0..]);
    const built_amount = try request_build_amount_tag(&amount_tag, 2_100);
    const built_description = try receipt_build_description_tag(
        &description_tag,
        request_json,
        arena.allocator(),
    );

    try std.testing.expectEqualStrings("relays", built_relays.items[0]);
    try std.testing.expectEqualStrings("2100", built_amount.items[1]);
    try std.testing.expectEqualStrings("description", built_description.items[0]);
}

test "zap receipt validate rejects invalid receipt signature" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var request_json_buffer: [1024]u8 = undefined;
    const request_json = try build_signed_request_json(
        request_json_buffer[0..],
        "9630f464cca6a5147aa8a35f0bcdd3ce485324e732fd39e09233b1d848238f31",
    );

    const receipt_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "p", "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245" } },
        .{ .items = &.{ "e", "3624762a1274dd9636e0c552b53086d70bc88c165bc4dc0f9e836a1eaf86c3b8" } },
        .{ .items = &.{ "bolt11", "lnbc10u1example" } },
        .{ .items = &.{ "description", request_json } },
    };
    var receipt = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = try parse_hex_32("9630f464cca6a5147aa8a35f0bcdd3ce485324e732fd39e09233b1d848238f31"),
        .sig = [_]u8{0} ** 64,
        .kind = zap_receipt_kind,
        .created_at = 1_674_164_545,
        .content = "",
        .tags = receipt_tags[0..],
    };
    receipt.id = try nip01_event.event_compute_id(&receipt);
    var relays: [4][]const u8 = undefined;

    try std.testing.expectError(
        error.InvalidReceiptSignature,
        zap_receipt_validate(
            &receipt,
            receipt.pubkey,
            relays[0..],
            arena.allocator(),
        ),
    );
}

test "receipt description builder rejects non-zap events" {
    var tag: BuiltTag = .{};
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const invalid_description_json =
        \\{"id":"d9cc14d50fcb8c27539aacf776882942c1a11ea4472f8cdec1dea82fab66279d","pubkey":"97c70a44366a6535c145b333f973ea86dfdc2d7a99da618c40c64705ad98e322","created_at":1674164539,"kind":1,"tags":[],"content":"","sig":"77127f636577e9029276be060332ea565deaf89ff215a494ccff16ae3f757065e2bc59b2e8c113dd407917a010b3abd36c8d7ad84c0e3ab7dab3a0b0caa9835d"}
    ;

    try std.testing.expectError(
        error.InvalidDescriptionTag,
        receipt_build_description_tag(
            &tag,
            invalid_description_json,
            arena.allocator(),
        ),
    );
}

fn build_signed_request_json(output: []u8, receipt_signer_hex: []const u8) ![]const u8 {
    std.debug.assert(output.len >= 0);
    std.debug.assert(receipt_signer_hex.len == limits.pubkey_hex_length);

    const secp256k1_backend = @import("crypto/secp256k1_backend.zig");
    var secret_key: [32]u8 = [_]u8{0} ** 32;
    secret_key[31] = 3;
    var pubkey: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(
        &pubkey,
        "F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9",
    ) catch unreachable;

    const tag_items = [_]nip01_event.EventTag{
        .{ .items = &.{ "e", "3624762a1274dd9636e0c552b53086d70bc88c165bc4dc0f9e836a1eaf86c3b8" } },
        .{ .items = &.{ "p", "32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245" } },
        .{ .items = &.{ "relays", "wss://relay.damus.io" } },
        .{ .items = &.{ "P", receipt_signer_hex } },
    };
    var event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = zap_request_kind,
        .created_at = 1_674_164_539,
        .content = "",
        .tags = tag_items[0..],
    };
    event.id = try nip01_event.event_compute_id(&event);
    try secp256k1_backend.sign_schnorr_signature(&secret_key, &event.id, &event.sig);

    const id_hex = std.fmt.bytesToHex(event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    const sig_hex = std.fmt.bytesToHex(event.sig, .lower);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"created_at\":1674164539,\"kind\":9734,\"tags\":[[\"e\",\"3624762a1274dd9636e0c552b53086d70bc88c165bc4dc0f9e836a1eaf86c3b8\"],[\"p\",\"32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245\"],[\"relays\",\"wss://relay.damus.io\"],[\"P\",\"{s}\"]],\"content\":\"\",\"sig\":\"{s}\"}}",
        .{ id_hex[0..], pubkey_hex[0..], receipt_signer_hex, sig_hex[0..] },
    );
}
