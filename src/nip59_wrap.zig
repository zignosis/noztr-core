const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip44 = @import("nip44.zig");
const nostr_keys = @import("nostr_keys.zig");
const secp256k1_backend = @import("crypto/secp256k1_backend.zig");

const Event = nip01_event.Event;

const wrap_event_kind: u32 = 1059;
const seal_event_kind: u32 = 13;

/// Typed failures for staged NIP-59 unwrap boundaries.
pub const WrapError = error{
    InvalidWrapEvent,
    InvalidSealEvent,
    InvalidRumorEvent,
    InvalidWrapKind,
    InvalidSealKind,
    InvalidSealSignature,
    SenderMismatch,
    DecryptFailed,
    OutOfMemory,
};

pub const WrapBuildError = nip44.ConversationEncryptionError || nostr_keys.NostrKeysError || error{
    InvalidRumorEvent,
    InvalidSealEvent,
    InvalidWrapEvent,
    BufferTooSmall,
};

pub const BuiltOutboundTranscript = struct {
    rumor_json: []const u8,
    seal_json: []const u8,
    seal_payload: []const u8,
    wrap_payload: []const u8,
};

pub const BuiltWrapEvent = struct {
    /// Semantic output event for the minimal one-recipient wrap layer.
    event: Event = undefined,
    /// Caller-owned storage backing the canonical single `p` tag.
    tags_storage: [1]nip01_event.EventTag = undefined,
    /// Caller-owned storage for the canonical single `p` tag items.
    tag_items: [2][]const u8 = undefined,
    /// Caller-owned lowercase recipient hex backing the canonical single `p` tag.
    recipient_hex: [limits.pubkey_hex_length]u8 = undefined,
};

/// Validate kind and cryptographic structure for an outer NIP-59 wrap event.
pub fn nip59_validate_wrap_structure(wrap_event: *const Event) WrapError!void {
    std.debug.assert(@intFromPtr(wrap_event) != 0);
    std.debug.assert(wrap_event.kind <= std.math.maxInt(u32));

    if (wrap_event.kind != wrap_event_kind) {
        return error.InvalidWrapKind;
    }

    nip01_event.event_verify(wrap_event) catch {
        return error.InvalidWrapEvent;
    };
}

/// Build one minimal deterministic `rumor -> seal -> wrap` transcript for one recipient.
pub fn nip59_build_outbound_for_recipient(
    output_seal: *Event,
    output_wrap: *BuiltWrapEvent,
    sender_secret: *const [32]u8,
    wrap_secret: *const [32]u8,
    recipient_pubkey: *const [32]u8,
    rumor_event: *const Event,
    rumor_json_output: []u8,
    seal_json_output: []u8,
    seal_payload_output: []u8,
    wrap_payload_output: []u8,
    seal_created_at: u64,
    wrap_created_at: u64,
    seal_nonce: *const [32]u8,
    wrap_nonce: *const [32]u8,
) WrapBuildError!BuiltOutboundTranscript {
    std.debug.assert(@intFromPtr(output_seal) != 0);
    std.debug.assert(@intFromPtr(output_wrap) != 0);

    try validate_unsigned_rumor_event(rumor_event, sender_secret);
    const rumor_json = try serialize_rumor_json(rumor_json_output, rumor_event);
    const seal_payload = try encrypt_payload_for_recipient(
        seal_payload_output,
        sender_secret,
        recipient_pubkey,
        rumor_json,
        seal_nonce,
    );
    try build_seal_event(output_seal, sender_secret, seal_created_at, seal_payload);
    const seal_json = nip01_event.event_serialize_json_object(seal_json_output, output_seal) catch {
        return error.BufferTooSmall;
    };
    const wrap_payload = try encrypt_payload_for_recipient(
        wrap_payload_output,
        wrap_secret,
        recipient_pubkey,
        seal_json,
        wrap_nonce,
    );
    try build_wrap_event(output_wrap, wrap_secret, recipient_pubkey, wrap_created_at, wrap_payload);
    return .{
        .rumor_json = rumor_json,
        .seal_json = seal_json,
        .seal_payload = seal_payload,
        .wrap_payload = wrap_payload,
    };
}

/// Unwrap staged layers in fixed order: wrap -> seal -> rumor.
///
/// `recipient_private_key_material` is interpreted as recipient private key
/// material. Per-layer NIP-44 conversation keys are derived internally against
/// the layer signer pubkeys.
///
/// Lifetime: `output_rumor.content` and `output_rumor.tags` (including nested
/// tag item slices) borrow allocations from caller-provided `scratch`.
/// Callers must keep `scratch` allocations alive for as long as those slices
/// are observed.
pub fn nip59_unwrap(
    output_rumor: *Event,
    recipient_private_key_material: *const [32]u8,
    wrap_event: *const Event,
    scratch: std.mem.Allocator,
) WrapError!void {
    std.debug.assert(@intFromPtr(output_rumor) != 0);
    std.debug.assert(@intFromPtr(recipient_private_key_material) != 0);

    try nip59_validate_wrap_structure(wrap_event);

    var wrap_conversation_key = nip44.nip44_get_conversation_key(
        recipient_private_key_material,
        &wrap_event.pubkey,
    ) catch {
        return error.DecryptFailed;
    };
    defer wipe_bytes(wrap_conversation_key[0..]);

    var seal_plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    defer wipe_bytes(seal_plaintext[0..]);
    const seal_json = nip44.nip44_decrypt_from_base64(
        seal_plaintext[0..],
        &wrap_conversation_key,
        wrap_event.content,
    ) catch {
        return error.DecryptFailed;
    };

    const seal_event = nip01_event.event_parse_json(seal_json, scratch) catch |parse_error| {
        return map_seal_parse_error(parse_error);
    };
    try validate_seal_event(&seal_event);

    var seal_conversation_key = nip44.nip44_get_conversation_key(
        recipient_private_key_material,
        &seal_event.pubkey,
    ) catch {
        return error.DecryptFailed;
    };
    defer wipe_bytes(seal_conversation_key[0..]);

    var rumor_plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    defer wipe_bytes(rumor_plaintext[0..]);
    const rumor_json = nip44.nip44_decrypt_from_base64(
        rumor_plaintext[0..],
        &seal_conversation_key,
        seal_event.content,
    ) catch {
        return error.DecryptFailed;
    };

    const rumor_event = try parse_unsigned_rumor_event(rumor_json, scratch);
    if (!std.mem.eql(u8, &seal_event.pubkey, &rumor_event.pubkey)) {
        return error.SenderMismatch;
    }

    output_rumor.* = rumor_event;
}

fn validate_unsigned_rumor_event(
    rumor_event: *const Event,
    sender_secret: *const [32]u8,
) WrapBuildError!void {
    std.debug.assert(@intFromPtr(rumor_event) != 0);
    std.debug.assert(@intFromPtr(sender_secret) != 0);
    std.debug.assert(rumor_event.kind <= std.math.maxInt(u32));

    nip01_event.event_verify_id_checked(rumor_event) catch return error.InvalidRumorEvent;
    for (rumor_event.sig) |byte| {
        if (byte != 0) return error.InvalidRumorEvent;
    }
    const sender_pubkey = try nostr_keys.nostr_derive_public_key(sender_secret);
    if (!std.mem.eql(u8, &sender_pubkey, &rumor_event.pubkey)) {
        return error.InvalidRumorEvent;
    }
}

fn serialize_rumor_json(output: []u8, rumor_event: *const Event) WrapBuildError![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(usize));
    std.debug.assert(@intFromPtr(rumor_event) != 0);

    return nip01_event.event_serialize_json_object_unsigned(output, rumor_event) catch |err| {
        return switch (err) {
            error.BufferTooSmall => error.BufferTooSmall,
            else => error.InvalidRumorEvent,
        };
    };
}

fn encrypt_payload_for_recipient(
    output: []u8,
    sender_secret: *const [32]u8,
    recipient_pubkey: *const [32]u8,
    plaintext: []const u8,
    nonce: *const [32]u8,
) WrapBuildError![]const u8 {
    std.debug.assert(@intFromPtr(sender_secret) != 0);
    std.debug.assert(@intFromPtr(recipient_pubkey) != 0);

    var conversation_key = try nip44.nip44_get_conversation_key(sender_secret, recipient_pubkey);
    defer wipe_bytes(conversation_key[0..]);

    return nip44.nip44_encrypt_with_nonce_to_base64(output, &conversation_key, plaintext, nonce);
}

fn build_seal_event(
    output_seal: *Event,
    sender_secret: *const [32]u8,
    created_at: u64,
    payload: []const u8,
) WrapBuildError!void {
    std.debug.assert(@intFromPtr(output_seal) != 0);
    std.debug.assert(@intFromPtr(sender_secret) != 0);

    const sender_pubkey = try nostr_keys.nostr_derive_public_key(sender_secret);
    output_seal.* = .{
        .id = [_]u8{0} ** 32,
        .pubkey = sender_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = seal_event_kind,
        .created_at = created_at,
        .content = payload,
        .tags = &.{},
    };
    nostr_keys.nostr_sign_event(sender_secret, output_seal) catch |err| {
        return switch (err) {
            error.InvalidEvent => error.InvalidSealEvent,
            else => err,
        };
    };
}

fn build_wrap_event(
    output_wrap: *BuiltWrapEvent,
    wrap_secret: *const [32]u8,
    recipient_pubkey: *const [32]u8,
    created_at: u64,
    payload: []const u8,
) WrapBuildError!void {
    std.debug.assert(@intFromPtr(output_wrap) != 0);
    std.debug.assert(@intFromPtr(wrap_secret) != 0);

    const wrap_pubkey = try nostr_keys.nostr_derive_public_key(wrap_secret);
    const tags = init_wrap_tags(output_wrap, recipient_pubkey);
    output_wrap.event = .{
        .id = [_]u8{0} ** 32,
        .pubkey = wrap_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = wrap_event_kind,
        .created_at = created_at,
        .content = payload,
        .tags = tags,
    };
    nostr_keys.nostr_sign_event(wrap_secret, &output_wrap.event) catch |err| {
        return switch (err) {
            error.InvalidEvent => error.InvalidWrapEvent,
            else => err,
        };
    };
}

fn init_wrap_tags(
    output_wrap: *BuiltWrapEvent,
    recipient_pubkey: *const [32]u8,
) []const nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output_wrap) != 0);
    std.debug.assert(@intFromPtr(recipient_pubkey) != 0);

    const recipient_hex = std.fmt.bytesToHex(recipient_pubkey, .lower);
    @memcpy(output_wrap.recipient_hex[0..], recipient_hex[0..]);
    output_wrap.tag_items[0] = "p";
    output_wrap.tag_items[1] = output_wrap.recipient_hex[0..];
    output_wrap.tags_storage[0] = .{ .items = output_wrap.tag_items[0..2] };
    return output_wrap.tags_storage[0..1];
}

fn validate_seal_event(seal_event: *const Event) WrapError!void {
    std.debug.assert(@intFromPtr(seal_event) != 0);
    std.debug.assert(seal_event.kind <= std.math.maxInt(u32));

    if (seal_event.kind != seal_event_kind) {
        return error.InvalidSealKind;
    }
    if (seal_event.tags.len != 0) {
        return error.InvalidSealEvent;
    }

    nip01_event.event_verify(seal_event) catch {
        return error.InvalidSealSignature;
    };
}

fn parse_unsigned_rumor_event(input: []const u8, scratch: std.mem.Allocator) WrapError!Event {
    std.debug.assert(input.len <= limits.event_json_max + 1);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (input.len == 0) {
        return error.InvalidRumorEvent;
    }
    if (input.len > limits.event_json_max) {
        return error.InvalidRumorEvent;
    }
    if (!std.unicode.utf8ValidateSlice(input)) {
        return error.InvalidRumorEvent;
    }

    var parse_arena = std.heap.ArenaAllocator.init(scratch);
    defer parse_arena.deinit();

    const root = std.json.parseFromSliceLeaky(
        std.json.Value,
        parse_arena.allocator(),
        input,
        .{},
    ) catch |parse_error| {
        return map_rumor_json_parse_error(parse_error);
    };
    if (root != .object) {
        return error.InvalidRumorEvent;
    }
    return parse_unsigned_rumor_object(root.object, scratch);
}

const RumorFieldState = struct {
    has_id: bool = false,
    has_pubkey: bool = false,
    has_sig: bool = false,
    has_kind: bool = false,
    has_created_at: bool = false,
    has_content: bool = false,
    has_tags: bool = false,
};

fn parse_unsigned_rumor_object(
    object: std.json.ObjectMap,
    scratch: std.mem.Allocator,
) WrapError!Event {
    std.debug.assert(@sizeOf(std.json.ObjectMap) > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    var parsed = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 0,
        .created_at = 0,
        .content = "",
        .tags = &.{},
    };
    var fields = RumorFieldState{};

    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        try parse_unsigned_rumor_field(
            &parsed,
            &fields,
            entry.key_ptr.*,
            entry.value_ptr.*,
            scratch,
        );
    }

    if (fields.has_sig) {
        return error.InvalidRumorEvent;
    }
    if (!fields.has_id) {
        return error.InvalidRumorEvent;
    }
    if (!fields.has_pubkey) {
        return error.InvalidRumorEvent;
    }
    if (!fields.has_kind) {
        return error.InvalidRumorEvent;
    }
    if (!fields.has_created_at) {
        return error.InvalidRumorEvent;
    }
    if (!fields.has_content) {
        return error.InvalidRumorEvent;
    }
    if (!fields.has_tags) {
        return error.InvalidRumorEvent;
    }

    try validate_rumor_id_matches(&parsed);
    return parsed;
}

fn validate_rumor_id_matches(rumor_event: *const Event) WrapError!void {
    std.debug.assert(@intFromPtr(rumor_event) != 0);
    std.debug.assert(rumor_event.kind <= std.math.maxInt(u32));

    const computed_id = nip01_event.event_compute_id_checked(rumor_event) catch {
        return error.InvalidRumorEvent;
    };
    if (!std.mem.eql(u8, &computed_id, &rumor_event.id)) {
        return error.InvalidRumorEvent;
    }
}

fn parse_unsigned_rumor_field(
    parsed: *Event,
    fields: *RumorFieldState,
    key: []const u8,
    value: std.json.Value,
    scratch: std.mem.Allocator,
) WrapError!void {
    std.debug.assert(@intFromPtr(parsed) != 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (std.mem.eql(u8, key, "id")) {
        if (fields.has_id) return error.InvalidRumorEvent;
        parsed.id = try parse_rumor_hex_32(value);
        fields.has_id = true;
        return;
    }
    if (std.mem.eql(u8, key, "pubkey")) {
        if (fields.has_pubkey) return error.InvalidRumorEvent;
        parsed.pubkey = try parse_rumor_hex_32(value);
        fields.has_pubkey = true;
        return;
    }
    if (std.mem.eql(u8, key, "sig")) {
        fields.has_sig = true;
        return error.InvalidRumorEvent;
    }
    if (std.mem.eql(u8, key, "kind")) {
        if (fields.has_kind) return error.InvalidRumorEvent;
        parsed.kind = try parse_rumor_json_u32(value);
        fields.has_kind = true;
        return;
    }
    if (std.mem.eql(u8, key, "created_at")) {
        if (fields.has_created_at) return error.InvalidRumorEvent;
        parsed.created_at = try parse_rumor_json_u64(value);
        fields.has_created_at = true;
        return;
    }
    if (std.mem.eql(u8, key, "content")) {
        if (fields.has_content) return error.InvalidRumorEvent;
        parsed.content = try parse_rumor_content_owned(value, scratch);
        fields.has_content = true;
        return;
    }
    if (std.mem.eql(u8, key, "tags")) {
        if (fields.has_tags) return error.InvalidRumorEvent;
        parsed.tags = try parse_rumor_tags(value, scratch);
        fields.has_tags = true;
    }
}

fn parse_rumor_hex_32(value: std.json.Value) WrapError![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const source = if (value == .string) value.string else return error.InvalidRumorEvent;
    try validate_lower_hex(source, limits.id_hex_length);

    var output: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&output, source) catch {
        return error.InvalidRumorEvent;
    };
    return output;
}

fn parse_rumor_json_u32(value: std.json.Value) WrapError!u32 {
    std.debug.assert(@sizeOf(u32) == 4);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .integer) {
        return error.InvalidRumorEvent;
    }
    if (value.integer < 0) {
        return error.InvalidRumorEvent;
    }
    return std.math.cast(u32, value.integer) orelse error.InvalidRumorEvent;
}

fn parse_rumor_json_u64(value: std.json.Value) WrapError!u64 {
    std.debug.assert(@sizeOf(u64) == 8);
    std.debug.assert(@sizeOf(std.json.Value) > 0);

    if (value != .integer) {
        return error.InvalidRumorEvent;
    }
    if (value.integer < 0) {
        return error.InvalidRumorEvent;
    }
    return std.math.cast(u64, value.integer) orelse error.InvalidRumorEvent;
}

fn parse_rumor_content_owned(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) WrapError![]const u8 {
    std.debug.assert(limits.content_bytes_max > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .string) {
        return error.InvalidRumorEvent;
    }
    if (!std.unicode.utf8ValidateSlice(value.string)) {
        return error.InvalidRumorEvent;
    }
    if (value.string.len > limits.content_bytes_max) {
        return error.InvalidRumorEvent;
    }

    const owned = scratch.alloc(u8, value.string.len) catch {
        return error.OutOfMemory;
    };
    if (value.string.len > 0) {
        @memcpy(owned, value.string);
    }
    return owned;
}

fn parse_rumor_tags(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) WrapError![]const nip01_event.EventTag {
    std.debug.assert(limits.tags_max > 0);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    if (value != .array) {
        return error.InvalidRumorEvent;
    }
    if (value.array.items.len > limits.tags_max) {
        return error.InvalidRumorEvent;
    }

    const tags = scratch.alloc(nip01_event.EventTag, value.array.items.len) catch {
        return error.OutOfMemory;
    };
    var tag_index: u32 = 0;
    while (tag_index < value.array.items.len) : (tag_index += 1) {
        const tag_value = value.array.items[tag_index];
        if (tag_value != .array) {
            return error.InvalidRumorEvent;
        }
        if (tag_value.array.items.len == 0) {
            return error.InvalidRumorEvent;
        }
        if (tag_value.array.items.len > limits.tag_items_max) {
            return error.InvalidRumorEvent;
        }

        const items = scratch.alloc([]const u8, tag_value.array.items.len) catch {
            return error.OutOfMemory;
        };
        var item_index: u32 = 0;
        while (item_index < tag_value.array.items.len) : (item_index += 1) {
            items[item_index] = try parse_rumor_tag_item_owned(
                tag_value.array.items[item_index],
                scratch,
            );
        }
        tags[tag_index] = .{ .items = items };
    }
    return tags;
}

fn parse_rumor_tag_item_owned(
    value: std.json.Value,
    scratch: std.mem.Allocator,
) WrapError![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);
    std.debug.assert(@intFromPtr(scratch.ptr) != 0);

    const item = try parse_rumor_tag_item(value);
    const owned = scratch.alloc(u8, item.len) catch {
        return error.OutOfMemory;
    };
    if (item.len > 0) {
        @memcpy(owned, item);
    }
    return owned;
}

fn parse_rumor_tag_item(value: std.json.Value) WrapError![]const u8 {
    std.debug.assert(@sizeOf(std.json.Value) > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (value != .string) {
        return error.InvalidRumorEvent;
    }
    if (!std.unicode.utf8ValidateSlice(value.string)) {
        return error.InvalidRumorEvent;
    }
    if (value.string.len > limits.tag_item_bytes_max) {
        return error.InvalidRumorEvent;
    }
    return value.string;
}

fn validate_lower_hex(source: []const u8, expected_length: u8) WrapError!void {
    std.debug.assert(expected_length > 0);
    std.debug.assert(expected_length <= 128);

    if (source.len != expected_length) {
        return error.InvalidRumorEvent;
    }

    var index: u32 = 0;
    while (index < source.len) : (index += 1) {
        const byte = source[index];
        const is_digit = byte >= '0' and byte <= '9';
        if (is_digit) {
            continue;
        }
        const is_lower_hex = byte >= 'a' and byte <= 'f';
        if (!is_lower_hex) {
            return error.InvalidRumorEvent;
        }
    }
}

fn wipe_bytes(bytes: []u8) void {
    std.debug.assert(bytes.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u8) == 1);

    std.crypto.secureZero(u8, bytes);
}

fn map_seal_parse_error(parse_error: nip01_event.EventParseError) WrapError {
    std.debug.assert(@intFromError(parse_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (parse_error) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidSealEvent,
    };
}

fn map_rumor_json_parse_error(parse_error: anyerror) WrapError {
    std.debug.assert(@intFromError(parse_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (parse_error) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidRumorEvent,
    };
}

const SignedEventFixture = struct {
    event: Event,
    json_storage: [2048]u8,
    json: []const u8,
};

const RumorFixture = struct {
    event: Event,
    json_storage: [2048]u8,
    json: []const u8,
};

const WrapFixture = struct {
    rumor: RumorFixture,
    seal: SignedEventFixture,
    wrap: SignedEventFixture,
    seal_payload_storage: [4096]u8,
    wrap_payload_storage: [8192]u8,
    seal_payload: []const u8,
    wrap_payload: []const u8,
};

fn build_valid_wrap_fixture(
    output_fixture: *WrapFixture,
    sender_pubkey: *const [32]u8,
    wrap_pubkey: *const [32]u8,
    sender_secret: *const [32]u8,
    wrap_secret: *const [32]u8,
    recipient_private_key: *const [32]u8,
    rumor_content: []const u8,
    rumor_pubkey_override: ?*const [32]u8,
) !void {
    std.debug.assert(@intFromPtr(output_fixture) != 0);
    std.debug.assert(@intFromPtr(sender_pubkey) != 0);
    std.debug.assert(@intFromPtr(recipient_private_key) != 0);

    try build_rumor_fixture(
        &output_fixture.rumor,
        sender_pubkey,
        rumor_content,
        rumor_pubkey_override,
    );

    var seal_conversation_key = try nip44.nip44_get_conversation_key(
        recipient_private_key,
        sender_pubkey,
    );
    defer wipe_bytes(seal_conversation_key[0..]);

    const seal_payload = try nip44.nip44_encrypt_with_nonce_to_base64(
        output_fixture.seal_payload_storage[0..],
        &seal_conversation_key,
        output_fixture.rumor.json,
        &fixed_nonce_a,
    );
    output_fixture.seal_payload = seal_payload;
    try build_signed_event_fixture(
        &output_fixture.seal,
        sender_pubkey,
        sender_secret,
        seal_event_kind,
        1_710_000_010,
        output_fixture.seal_payload,
    );

    var wrap_conversation_key = try nip44.nip44_get_conversation_key(
        recipient_private_key,
        wrap_pubkey,
    );
    defer wipe_bytes(wrap_conversation_key[0..]);

    const wrap_payload = try nip44.nip44_encrypt_with_nonce_to_base64(
        output_fixture.wrap_payload_storage[0..],
        &wrap_conversation_key,
        output_fixture.seal.json,
        &fixed_nonce_b,
    );
    output_fixture.wrap_payload = wrap_payload;
    try build_signed_event_fixture(
        &output_fixture.wrap,
        wrap_pubkey,
        wrap_secret,
        wrap_event_kind,
        1_710_000_020,
        output_fixture.wrap_payload,
    );
}

fn build_rumor_fixture(
    output_fixture: *RumorFixture,
    sender_pubkey: *const [32]u8,
    rumor_content: []const u8,
    rumor_pubkey_override: ?*const [32]u8,
) !void {
    std.debug.assert(@intFromPtr(output_fixture) != 0);
    std.debug.assert(@intFromPtr(sender_pubkey) != 0);
    std.debug.assert(rumor_content.len <= limits.content_bytes_max);

    const rumor_pubkey = rumor_pubkey_override orelse sender_pubkey;
    output_fixture.* = .{
        .event = .{
            .id = [_]u8{0} ** 32,
            .pubkey = rumor_pubkey.*,
            .sig = [_]u8{0} ** 64,
            .kind = 14,
            .created_at = 1_710_000_000,
            .content = rumor_content,
            .tags = &.{},
        },
        .json_storage = undefined,
        .json = undefined,
    };
    output_fixture.event.id = try nip01_event.event_compute_id(&output_fixture.event);
    output_fixture.json = try event_to_unsigned_json(
        output_fixture.json_storage[0..],
        &output_fixture.event,
    );
}

fn build_signed_event_fixture(
    output_fixture: *SignedEventFixture,
    pubkey: *const [32]u8,
    secret: *const [32]u8,
    kind: u32,
    created_at: u64,
    content: []const u8,
) !void {
    std.debug.assert(@intFromPtr(output_fixture) != 0);
    std.debug.assert(@intFromPtr(pubkey) != 0);
    std.debug.assert(@intFromPtr(secret) != 0);

    output_fixture.* = .{
        .event = .{
            .id = [_]u8{0} ** 32,
            .pubkey = pubkey.*,
            .sig = [_]u8{0} ** 64,
            .kind = kind,
            .created_at = created_at,
            .content = content,
            .tags = &.{},
        },
        .json_storage = undefined,
        .json = undefined,
    };
    output_fixture.event.id = try nip01_event.event_compute_id(&output_fixture.event);
    try secp256k1_backend.sign_schnorr_signature(
        secret,
        &output_fixture.event.id,
        &output_fixture.event.sig,
    );
    output_fixture.json = try event_to_json(
        output_fixture.json_storage[0..],
        &output_fixture.event,
    );
}

fn rebuild_seal_after_rumor_mutation(
    fixture: *WrapFixture,
    recipient_private_key: *const [32]u8,
    sender_pubkey: *const [32]u8,
    sender_secret: *const [32]u8,
) !void {
    std.debug.assert(@intFromPtr(fixture) != 0);
    std.debug.assert(@intFromPtr(recipient_private_key) != 0);
    std.debug.assert(@intFromPtr(sender_pubkey) != 0);
    std.debug.assert(@intFromPtr(sender_secret) != 0);

    var seal_conversation_key = try nip44.nip44_get_conversation_key(
        recipient_private_key,
        sender_pubkey,
    );
    defer wipe_bytes(seal_conversation_key[0..]);

    fixture.seal_payload = try nip44.nip44_encrypt_with_nonce_to_base64(
        fixture.seal_payload_storage[0..],
        &seal_conversation_key,
        fixture.rumor.json,
        &fixed_nonce_a,
    );
    fixture.seal.event.content = fixture.seal_payload;
    fixture.seal.event.id = try nip01_event.event_compute_id(&fixture.seal.event);
    try secp256k1_backend.sign_schnorr_signature(
        sender_secret,
        &fixture.seal.event.id,
        &fixture.seal.event.sig,
    );
    fixture.seal.json = try event_to_json(fixture.seal.json_storage[0..], &fixture.seal.event);
}

fn rebuild_wrap_after_seal_mutation(
    fixture: *WrapFixture,
    recipient_private_key: *const [32]u8,
    wrap_pubkey: *const [32]u8,
    wrap_secret: *const [32]u8,
) !void {
    std.debug.assert(@intFromPtr(fixture) != 0);
    std.debug.assert(@intFromPtr(recipient_private_key) != 0);
    std.debug.assert(@intFromPtr(wrap_pubkey) != 0);
    std.debug.assert(@intFromPtr(wrap_secret) != 0);

    var wrap_conversation_key = try nip44.nip44_get_conversation_key(
        recipient_private_key,
        wrap_pubkey,
    );
    defer wipe_bytes(wrap_conversation_key[0..]);

    fixture.wrap_payload = try nip44.nip44_encrypt_with_nonce_to_base64(
        fixture.wrap_payload_storage[0..],
        &wrap_conversation_key,
        fixture.seal.json,
        &fixed_nonce_b,
    );
    fixture.wrap.event.content = fixture.wrap_payload;
    fixture.wrap.event.id = try nip01_event.event_compute_id(&fixture.wrap.event);
    try secp256k1_backend.sign_schnorr_signature(
        wrap_secret,
        &fixture.wrap.event.id,
        &fixture.wrap.event.sig,
    );
}

fn event_to_unsigned_json(
    output: []u8,
    event: *const Event,
) error{BufferTooSmall}![]const u8 {
    std.debug.assert(output.len >= 256);
    std.debug.assert(@intFromPtr(event) != 0);

    const id_hex = std.fmt.bytesToHex(event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"kind\":{d}," ++
            "\"created_at\":{d},\"tags\":[],\"content\":\"{s}\"}}",
        .{ id_hex[0..], pubkey_hex[0..], event.kind, event.created_at, event.content },
    ) catch {
        return error.BufferTooSmall;
    };
}

fn event_to_json(output: []u8, event: *const Event) error{BufferTooSmall}![]const u8 {
    std.debug.assert(output.len >= 256);
    std.debug.assert(@intFromPtr(event) != 0);

    const id_hex = std.fmt.bytesToHex(event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    const sig_hex = std.fmt.bytesToHex(event.sig, .lower);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"sig\":\"{s}\",\"kind\":{d}," ++
            "\"created_at\":{d},\"tags\":[],\"content\":\"{s}\"}}",
        .{
            id_hex[0..],
            pubkey_hex[0..],
            sig_hex[0..],
            event.kind,
            event.created_at,
            event.content,
        },
    ) catch {
        return error.BufferTooSmall;
    };
}

fn event_to_json_with_single_tag(
    output: []u8,
    event: *const Event,
    tag_name: []const u8,
    tag_value: []const u8,
) error{BufferTooSmall}![]const u8 {
    std.debug.assert(output.len >= 256);
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(tag_name.len > 0);

    const id_hex = std.fmt.bytesToHex(event.id, .lower);
    const pubkey_hex = std.fmt.bytesToHex(event.pubkey, .lower);
    const sig_hex = std.fmt.bytesToHex(event.sig, .lower);
    return std.fmt.bufPrint(
        output,
        "{{\"id\":\"{s}\",\"pubkey\":\"{s}\",\"sig\":\"{s}\",\"kind\":{d}," ++
            "\"created_at\":{d},\"tags\":[[\"{s}\",\"{s}\"]],\"content\":\"{s}\"}}",
        .{
            id_hex[0..],
            pubkey_hex[0..],
            sig_hex[0..],
            event.kind,
            event.created_at,
            tag_name,
            tag_value,
            event.content,
        },
    ) catch {
        return error.BufferTooSmall;
    };
}

fn parse_hex_32(hex: []const u8) ![32]u8 {
    std.debug.assert(hex.len <= 64);
    std.debug.assert(@sizeOf(u8) == 1);

    if (hex.len != 64) {
        return error.InvalidCharacter;
    }
    var out: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&out, hex);
    return out;
}

const sender_pubkey_hex = "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9";
const impersonated_pubkey_hex = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798";
const fixed_nonce_a = [_]u8{0} ** 31 ++ [_]u8{1};
const fixed_nonce_b = [_]u8{0} ** 31 ++ [_]u8{2};

fn sender_secret_key() [32]u8 {
    std.debug.assert(@sizeOf([32]u8) == 32);
    std.debug.assert(!@inComptime());

    var secret: [32]u8 = [_]u8{0} ** 32;
    secret[31] = 3;
    return secret;
}

fn wrap_secret_key() [32]u8 {
    std.debug.assert(@sizeOf([32]u8) == 32);
    std.debug.assert(!@inComptime());

    var secret: [32]u8 = [_]u8{0} ** 32;
    secret[31] = 3;
    return secret;
}

fn wrap_secret_key_alt() [32]u8 {
    std.debug.assert(@sizeOf([32]u8) == 32);
    std.debug.assert(!@inComptime());

    var secret: [32]u8 = [_]u8{0} ** 32;
    secret[31] = 1;
    return secret;
}

test "nip59 outbound builder produces one-recipient transcript that unwraps symmetrically" {
    const sender_secret = [_]u8{0} ** 31 ++ [_]u8{3};
    const wrap_secret = [_]u8{0} ** 31 ++ [_]u8{4};
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    const sender_pubkey = try nostr_keys.nostr_derive_public_key(&sender_secret);
    const recipient_pubkey = try nostr_keys.nostr_derive_public_key(&recipient_private_key);
    var rumor = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = sender_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 14,
        .created_at = 1_710_000_000,
        .content = "hello-outbound-builder",
        .tags = &.{},
    };
    var seal: Event = undefined;
    var wrap: BuiltWrapEvent = .{};
    var rumor_json_storage: [512]u8 = undefined;
    var seal_json_storage: [1024]u8 = undefined;
    var seal_payload_storage: [2048]u8 = undefined;
    var wrap_payload_storage: [4096]u8 = undefined;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    rumor.id = try nip01_event.event_compute_id_checked(&rumor);
    const built = try nip59_build_outbound_for_recipient(
        &seal,
        &wrap,
        &sender_secret,
        &wrap_secret,
        &recipient_pubkey,
        &rumor,
        rumor_json_storage[0..],
        seal_json_storage[0..],
        seal_payload_storage[0..],
        wrap_payload_storage[0..],
        1_710_000_001,
        1_710_000_002,
        &fixed_nonce_a,
        &fixed_nonce_b,
    );

    try std.testing.expectEqual(@as(u32, 13), seal.kind);
    try std.testing.expectEqual(@as(u32, 1059), wrap.event.kind);
    try std.testing.expectEqualStrings("p", wrap.event.tags[0].items[0]);
    try std.testing.expectEqualStrings(built.wrap_payload, wrap.event.content);

    var output_rumor: Event = undefined;
    try nip59_unwrap(&output_rumor, &recipient_private_key, &wrap.event, arena.allocator());
    try std.testing.expectEqualStrings("hello-outbound-builder", output_rumor.content);
    try std.testing.expect(std.mem.eql(u8, &output_rumor.id, &rumor.id));
    try std.testing.expectEqualStrings(
        built.rumor_json,
        try nip01_event.event_serialize_json_object_unsigned(rumor_json_storage[0..], &rumor),
    );
}

test "nip59 outbound builder rejects signed rumor input" {
    const sender_secret = [_]u8{0} ** 31 ++ [_]u8{3};
    const wrap_secret = [_]u8{0} ** 31 ++ [_]u8{4};
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    const sender_pubkey = try nostr_keys.nostr_derive_public_key(&sender_secret);
    const recipient_pubkey = try nostr_keys.nostr_derive_public_key(&recipient_private_key);
    var rumor = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = sender_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 14,
        .created_at = 1_710_000_000,
        .content = "hello-signed-rumor",
        .tags = &.{},
    };
    var seal: Event = undefined;
    var wrap: BuiltWrapEvent = .{};
    var rumor_json_storage: [512]u8 = undefined;
    var seal_json_storage: [1024]u8 = undefined;
    var seal_payload_storage: [2048]u8 = undefined;
    var wrap_payload_storage: [4096]u8 = undefined;

    try nostr_keys.nostr_sign_event(&sender_secret, &rumor);
    try std.testing.expectError(
        error.InvalidRumorEvent,
        nip59_build_outbound_for_recipient(
            &seal,
            &wrap,
            &sender_secret,
            &wrap_secret,
            &recipient_pubkey,
            &rumor,
            rumor_json_storage[0..],
            seal_json_storage[0..],
            seal_payload_storage[0..],
            wrap_payload_storage[0..],
            1_710_000_001,
            1_710_000_002,
            &fixed_nonce_a,
            &fixed_nonce_b,
        ),
    );
}

test "nip59 outbound builder rejects rumor pubkey that does not match sender secret" {
    const sender_secret = [_]u8{0} ** 31 ++ [_]u8{3};
    const wrap_secret = [_]u8{0} ** 31 ++ [_]u8{4};
    const recipient_private_key = [_]u8{0} ** 31 ++ [_]u8{5};
    const wrong_sender_secret = [_]u8{0} ** 31 ++ [_]u8{6};
    const wrong_pubkey = try nostr_keys.nostr_derive_public_key(&wrong_sender_secret);
    const recipient_pubkey = try nostr_keys.nostr_derive_public_key(&recipient_private_key);
    var rumor = Event{
        .id = [_]u8{0} ** 32,
        .pubkey = wrong_pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = 14,
        .created_at = 1_710_000_000,
        .content = "hello-mismatched-pubkey",
        .tags = &.{},
    };
    var seal: Event = undefined;
    var wrap: BuiltWrapEvent = .{};
    var rumor_json_storage: [512]u8 = undefined;
    var seal_json_storage: [1024]u8 = undefined;
    var seal_payload_storage: [2048]u8 = undefined;
    var wrap_payload_storage: [4096]u8 = undefined;

    rumor.id = try nip01_event.event_compute_id_checked(&rumor);
    try std.testing.expectError(
        error.InvalidRumorEvent,
        nip59_build_outbound_for_recipient(
            &seal,
            &wrap,
            &sender_secret,
            &wrap_secret,
            &recipient_pubkey,
            &rumor,
            rumor_json_storage[0..],
            seal_json_storage[0..],
            seal_payload_storage[0..],
            wrap_payload_storage[0..],
            1_710_000_001,
            1_710_000_002,
            &fixed_nonce_a,
            &fixed_nonce_b,
        ),
    );
}

test "nip59 valid structure validation passes for signed wrap" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-valid-1",
        null,
    );

    try nip59_validate_wrap_structure(&fixture.wrap.event);
    try std.testing.expect(fixture.wrap.event.kind == wrap_event_kind);
}

test "nip59 valid unwrap returns expected rumor" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-valid-2",
        null,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try nip59_unwrap(
        &output_rumor,
        &recipient_private_key,
        &fixture.wrap.event,
        arena.allocator(),
    );
    // Borrowed-lifetime context: content/tags slices remain valid while arena lives.
    try std.testing.expectEqualStrings("hello-valid-2", output_rumor.content);
    try std.testing.expect(output_rumor.tags.len == 0);
    try std.testing.expect(output_rumor.kind == 14);
}

test "nip59 valid unwrap accepts unsigned rumor payload" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-valid-unsigned",
        null,
    );
    try std.testing.expect(std.mem.indexOf(u8, fixture.rumor.json, "\"sig\"") == null);

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try nip59_unwrap(
        &output_rumor,
        &recipient_private_key,
        &fixture.wrap.event,
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("hello-valid-unsigned", output_rumor.content);
    try std.testing.expect(output_rumor.kind == 14);
}

test "nip59 valid unwrap derives per-layer keys for different signer pubkeys" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const wrap_pubkey = try parse_hex_32(impersonated_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key_alt();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &wrap_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-valid-per-layer",
        null,
    );
    try std.testing.expect(
        !std.mem.eql(u8, &fixture.wrap.event.pubkey, &fixture.seal.event.pubkey),
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try nip59_unwrap(
        &output_rumor,
        &recipient_private_key,
        &fixture.wrap.event,
        arena.allocator(),
    );
    try std.testing.expectEqualStrings("hello-valid-per-layer", output_rumor.content);
    try std.testing.expect(
        std.mem.eql(u8, &output_rumor.pubkey, &fixture.seal.event.pubkey),
    );
}

test "nip59 valid unwrap deterministic repeated behavior" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-valid-3",
        null,
    );

    var arena_a = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_a.deinit();
    var arena_b = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_b.deinit();

    var rumor_a: Event = undefined;
    var rumor_b: Event = undefined;
    try nip59_unwrap(
        &rumor_a,
        &recipient_private_key,
        &fixture.wrap.event,
        arena_a.allocator(),
    );
    try nip59_unwrap(
        &rumor_b,
        &recipient_private_key,
        &fixture.wrap.event,
        arena_b.allocator(),
    );
    try std.testing.expectEqualStrings(rumor_a.content, rumor_b.content);
    try std.testing.expect(std.mem.eql(u8, &rumor_a.id, &rumor_b.id));
}

test "nip59 valid unwrap supports different rumor payloads" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-valid-4",
        null,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try nip59_unwrap(
        &output_rumor,
        &recipient_private_key,
        &fixture.wrap.event,
        arena.allocator(),
    );
    try std.testing.expect(output_rumor.created_at == 1_710_000_000);
    try std.testing.expectEqualStrings("hello-valid-4", output_rumor.content);
}

test "nip59 valid unwrap preserves sender continuity" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-valid-5",
        null,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try nip59_unwrap(
        &output_rumor,
        &recipient_private_key,
        &fixture.wrap.event,
        arena.allocator(),
    );
    try std.testing.expect(
        std.mem.eql(u8, &output_rumor.pubkey, &fixture.seal.event.pubkey),
    );
    try std.testing.expect(!std.mem.eql(u8, &output_rumor.pubkey, &fixed_nonce_a));
}

test "nip59 invalid outer kind fails before decrypt" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-1",
        null,
    );
    fixture.wrap.event.kind = 1;
    fixture.wrap.event.content = "not-base64";
    fixture.wrap.event.id = try nip01_event.event_compute_id(&fixture.wrap.event);
    try secp256k1_backend.sign_schnorr_signature(
        &wrap_secret,
        &fixture.wrap.event.id,
        &fixture.wrap.event.sig,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.InvalidWrapKind,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 invalid decrypt failure is typed" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-2",
        null,
    );
    fixture.wrap.event.content = "AQ==";
    fixture.wrap.event.id = try nip01_event.event_compute_id(&fixture.wrap.event);
    try secp256k1_backend.sign_schnorr_signature(
        &wrap_secret,
        &fixture.wrap.event.id,
        &fixture.wrap.event.sig,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.DecryptFailed,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 invalid wrap event signature is typed" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-wrap-event",
        null,
    );

    fixture.wrap.event.sig[0] ^= 0x01;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.InvalidWrapEvent,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 invalid seal signature fails before sender checks" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const impersonated_pubkey = try parse_hex_32(impersonated_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-3",
        &impersonated_pubkey,
    );
    fixture.seal.event.sig[0] ^= 0x01;
    fixture.seal.json = try event_to_json(fixture.seal.json_storage[0..], &fixture.seal.event);
    try rebuild_wrap_after_seal_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &wrap_secret,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.InvalidSealSignature,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 invalid seal kind is typed after valid wrap decrypt" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-seal-kind",
        null,
    );

    fixture.seal.event.kind = 100;
    fixture.seal.event.id = try nip01_event.event_compute_id(&fixture.seal.event);
    try secp256k1_backend.sign_schnorr_signature(
        &sender_secret,
        &fixture.seal.event.id,
        &fixture.seal.event.sig,
    );
    fixture.seal.json = try event_to_json(fixture.seal.json_storage[0..], &fixture.seal.event);
    try rebuild_wrap_after_seal_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &wrap_secret,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.InvalidSealKind,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 invalid seal event tags are typed" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-seal-event",
        null,
    );

    fixture.seal.json = try event_to_json_with_single_tag(
        fixture.seal.json_storage[0..],
        &fixture.seal.event,
        "p",
        sender_pubkey_hex,
    );
    try rebuild_wrap_after_seal_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &wrap_secret,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.InvalidSealEvent,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 invalid sender mismatch caught after parse" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const impersonated_pubkey = try parse_hex_32(impersonated_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-4",
        &impersonated_pubkey,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.SenderMismatch,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 invalid malformed rumor payload is rejected" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-5",
        null,
    );

    fixture.rumor.json = "not-json-rumor";
    try rebuild_seal_after_rumor_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &sender_secret,
    );
    try rebuild_wrap_after_seal_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &wrap_secret,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.InvalidRumorEvent,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 invalid rumor id mismatch is rejected" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-rumor-id",
        null,
    );

    fixture.rumor.event.id[0] ^= 0x01;
    fixture.rumor.json = try event_to_unsigned_json(
        fixture.rumor.json_storage[0..],
        &fixture.rumor.event,
    );
    try rebuild_seal_after_rumor_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &sender_secret,
    );
    try rebuild_wrap_after_seal_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &wrap_secret,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.InvalidRumorEvent,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}

test "nip59 maps parser allocator exhaustion to OutOfMemory" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-oom",
        null,
    );

    var tiny_buffer: [64]u8 = undefined;
    var tiny_allocator = std.heap.FixedBufferAllocator.init(&tiny_buffer);

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.OutOfMemory,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            tiny_allocator.allocator(),
        ),
    );
}

test "nip59 invalid signed rumor payload is rejected" {
    const sender_pubkey = try parse_hex_32(sender_pubkey_hex);
    const sender_secret = sender_secret_key();
    const recipient_private_key = sender_secret;
    const wrap_secret = wrap_secret_key();

    var fixture: WrapFixture = undefined;
    try build_valid_wrap_fixture(
        &fixture,
        &sender_pubkey,
        &sender_pubkey,
        &sender_secret,
        &wrap_secret,
        &recipient_private_key,
        "hello-invalid-rumor-signed",
        null,
    );

    fixture.rumor.json = try event_to_json(fixture.rumor.json_storage[0..], &fixture.rumor.event);
    try std.testing.expect(std.mem.indexOf(u8, fixture.rumor.json, "\"sig\"") != null);
    try rebuild_seal_after_rumor_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &sender_secret,
    );
    try rebuild_wrap_after_seal_mutation(
        &fixture,
        &recipient_private_key,
        &sender_pubkey,
        &wrap_secret,
    );

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var output_rumor: Event = undefined;
    try std.testing.expectError(
        error.InvalidRumorEvent,
        nip59_unwrap(
            &output_rumor,
            &recipient_private_key,
            &fixture.wrap.event,
            arena.allocator(),
        ),
    );
}
