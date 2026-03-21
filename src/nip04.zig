const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const secp256k1_backend = @import("crypto/secp256k1_backend.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_host = @import("internal/url_with_host.zig");

const Aes256 = std.crypto.core.aes.Aes256;
const base64_standard = std.base64.standard;

pub const dm_kind: u32 = 4;

/// Typed failures for strict NIP-04 encrypt/decrypt and event-shape boundaries.
pub const Nip04Error = error{
    InvalidPrivateKey,
    InvalidPublicKey,
    InvalidPlaintextLength,
    InvalidPayloadFormat,
    InvalidBase64,
    InvalidIvLength,
    InvalidCiphertextLength,
    InvalidMessageKind,
    InvalidRecipientTag,
    MissingRecipientTag,
    DuplicateRecipientTag,
    InvalidReplyTag,
    DuplicateReplyTag,
    BufferTooSmall,
    InvalidPadding,
    BackendUnavailable,
    EntropyUnavailable,
};

/// Callback type for caller-provided IV generation.
pub const Nip04IvProvider = *const fn (
    ctx: ?*anyopaque,
    out_iv: *[limits.nip04_iv_bytes]u8,
) Nip04Error!void;

/// Parsed legacy NIP-04 wire payload slices.
pub const Nip04Payload = struct {
    ciphertext_base64: []const u8,
    iv_base64: []const u8,
};

pub const Nip04ReplyRef = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const Nip04MessageInfo = struct {
    recipient_pubkey: [32]u8,
    recipient_relay_hint: ?[]const u8 = null,
    reply_to: ?Nip04ReplyRef = null,
    content: []const u8,
};

pub const BuiltTag = struct {
    items: [2][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count == 2);
        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Derive the NIP-04 shared secret from secp256k1 key agreement.
pub fn nip04_get_shared_secret(
    private_key: *const [32]u8,
    public_key: *const [32]u8,
) Nip04Error![32]u8 {
    std.debug.assert(@intFromPtr(private_key) != 0);
    std.debug.assert(@intFromPtr(public_key) != 0);

    var shared_secret: [32]u8 = undefined;
    secp256k1_backend.derive_shared_secret_x(private_key, public_key, &shared_secret) catch |err| {
        return map_shared_secret_error(err);
    };
    return shared_secret;
}

/// Encrypt plaintext using a caller-provided IV provider and local secp256k1 key material.
pub fn nip04_encrypt(
    output: []u8,
    private_key: *const [32]u8,
    public_key: *const [32]u8,
    plaintext: []const u8,
    iv_ctx: ?*anyopaque,
    iv_provider: Nip04IvProvider,
) Nip04Error![]const u8 {
    std.debug.assert(@intFromPtr(iv_provider) != 0);

    var iv: [limits.nip04_iv_bytes]u8 = undefined;
    defer wipe_bytes(iv[0..]);
    try iv_provider(iv_ctx, &iv);
    return nip04_encrypt_with_iv(output, private_key, public_key, plaintext, &iv);
}

/// Encrypt plaintext using local secp256k1 key material and a fixed caller-provided IV.
pub fn nip04_encrypt_with_iv(
    output: []u8,
    private_key: *const [32]u8,
    public_key: *const [32]u8,
    plaintext: []const u8,
    iv: *const [limits.nip04_iv_bytes]u8,
) Nip04Error![]const u8 {
    var shared_secret = try nip04_get_shared_secret(private_key, public_key);
    defer wipe_bytes(shared_secret[0..]);
    return nip04_encrypt_with_shared_secret_and_iv(output, &shared_secret, plaintext, iv);
}

/// Encrypt plaintext using an explicit caller-provided NIP-04 shared secret and fixed IV.
pub fn nip04_encrypt_with_shared_secret_and_iv(
    output: []u8,
    shared_secret: *const [32]u8,
    plaintext: []const u8,
    iv: *const [limits.nip04_iv_bytes]u8,
) Nip04Error![]const u8 {
    std.debug.assert(@intFromPtr(shared_secret) != 0);
    std.debug.assert(@intFromPtr(iv) != 0);

    const ciphertext_len = try nip04_calc_ciphertext_len(plaintext.len);
    const encoded_ciphertext_len = base64_standard.Encoder.calcSize(ciphertext_len);
    const payload_len = encoded_ciphertext_len + "?iv=".len + limits.nip04_iv_base64_bytes;
    if (output.len < payload_len) return error.BufferTooSmall;

    var padded_plaintext: [limits.nip04_ciphertext_max_bytes]u8 = undefined;
    defer wipe_bytes(padded_plaintext[0..]);
    write_pkcs7_padded_plaintext(padded_plaintext[0..ciphertext_len], plaintext);

    var ciphertext: [limits.nip04_ciphertext_max_bytes]u8 = undefined;
    defer wipe_bytes(ciphertext[0..]);
    aes256_cbc_encrypt(
        ciphertext[0..ciphertext_len],
        padded_plaintext[0..ciphertext_len],
        shared_secret.*,
        iv.*,
    );

    const ciphertext_base64 = base64_standard.Encoder.encode(
        output[0..encoded_ciphertext_len],
        ciphertext[0..ciphertext_len],
    );
    var iv_base64_storage: [limits.nip04_iv_base64_bytes]u8 = undefined;
    const iv_base64 = base64_standard.Encoder.encode(iv_base64_storage[0..], iv[0..]);
    return nip04_payload_serialize(output, ciphertext_base64, iv_base64);
}

/// Parse and validate the legacy NIP-04 `ciphertext?iv=...` wire format.
pub fn nip04_payload_parse(payload: []const u8) Nip04Error!Nip04Payload {
    if (payload.len < limits.nip04_payload_min_bytes) return error.InvalidPayloadFormat;
    if (payload.len > limits.nip04_payload_max_bytes) return error.InvalidPayloadFormat;

    const separator_index = std.mem.indexOf(u8, payload, "?iv=") orelse return error.InvalidPayloadFormat;
    const separator_end = separator_index + "?iv=".len;
    if (separator_index == 0 or separator_end >= payload.len) return error.InvalidPayloadFormat;
    if (std.mem.indexOfPos(u8, payload, separator_end, "?")) |_| return error.InvalidPayloadFormat;

    const parsed = Nip04Payload{
        .ciphertext_base64 = payload[0..separator_index],
        .iv_base64 = payload[separator_end..],
    };
    try validate_base64_and_lengths(parsed.ciphertext_base64, parsed.iv_base64);
    return parsed;
}

/// Serialize one canonical legacy NIP-04 wire payload.
pub fn nip04_payload_serialize(
    output: []u8,
    ciphertext_base64: []const u8,
    iv_base64: []const u8,
) Nip04Error![]const u8 {
    try validate_base64_and_lengths(ciphertext_base64, iv_base64);

    const total_len = ciphertext_base64.len + "?iv=".len + iv_base64.len;
    if (output.len < total_len) return error.BufferTooSmall;

    std.mem.copyForwards(u8, output[0..ciphertext_base64.len], ciphertext_base64);
    std.mem.copyForwards(
        u8,
        output[ciphertext_base64.len .. ciphertext_base64.len + "?iv=".len],
        "?iv=",
    );
    std.mem.copyForwards(u8, output[ciphertext_base64.len + "?iv=".len .. total_len], iv_base64);
    return output[0..total_len];
}

/// Decrypt one legacy NIP-04 payload using local secp256k1 key material.
pub fn nip04_decrypt(
    output_plaintext: []u8,
    private_key: *const [32]u8,
    public_key: *const [32]u8,
    payload: []const u8,
) Nip04Error![]const u8 {
    var shared_secret = try nip04_get_shared_secret(private_key, public_key);
    defer wipe_bytes(shared_secret[0..]);
    return nip04_decrypt_with_shared_secret(output_plaintext, &shared_secret, payload);
}

/// Decrypt one legacy NIP-04 payload using an explicit caller-provided shared secret.
pub fn nip04_decrypt_with_shared_secret(
    output_plaintext: []u8,
    shared_secret: *const [32]u8,
    payload: []const u8,
) Nip04Error![]const u8 {
    std.debug.assert(@intFromPtr(shared_secret) != 0);

    var ciphertext: [limits.nip04_ciphertext_max_bytes]u8 = undefined;
    defer wipe_bytes(ciphertext[0..]);
    var iv: [limits.nip04_iv_bytes]u8 = undefined;
    defer wipe_bytes(iv[0..]);

    const ciphertext_slice = try decode_payload(ciphertext[0..], &iv, payload);

    var padded_plaintext: [limits.nip04_ciphertext_max_bytes]u8 = undefined;
    defer wipe_bytes(padded_plaintext[0..]);
    aes256_cbc_decrypt(padded_plaintext[0..ciphertext_slice.len], ciphertext_slice, shared_secret.*, iv);
    const plaintext = try remove_pkcs7_padding(
        output_plaintext,
        padded_plaintext[0..ciphertext_slice.len],
    );
    if (!std.unicode.utf8ValidateSlice(plaintext)) return error.InvalidPadding;
    return plaintext;
}

/// Parse a strict `kind:4` DM event shape.
pub fn nip04_message_parse(event: *const nip01_event.Event) Nip04Error!Nip04MessageInfo {
    std.debug.assert(@intFromPtr(event) != 0);

    if (event.kind != dm_kind) return error.InvalidMessageKind;
    _ = try nip04_payload_parse(event.content);

    var info = Nip04MessageInfo{
        .recipient_pubkey = undefined,
        .content = event.content,
    };
    var saw_recipient = false;
    for (event.tags) |tag| {
        try parse_message_tag(tag, &info, &saw_recipient);
    }
    if (!saw_recipient) return error.MissingRecipientTag;
    return info;
}

/// Build a canonical `p` tag for one legacy NIP-04 recipient.
pub fn nip04_build_recipient_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
) Nip04Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    _ = parse_lower_hex_32(pubkey_hex) catch return error.InvalidRecipientTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    return output.as_event_tag();
}

/// Compute the AES-CBC ciphertext length after PKCS#7 padding.
pub fn nip04_calc_ciphertext_len(plaintext_len: usize) Nip04Error!usize {
    if (plaintext_len > limits.nip04_plaintext_max_bytes) return error.InvalidPlaintextLength;
    const blocks = @divFloor(plaintext_len, limits.nip04_iv_bytes) + 1;
    return blocks * limits.nip04_iv_bytes;
}

fn decode_payload(
    ciphertext_output: []u8,
    out_iv: *[limits.nip04_iv_bytes]u8,
    payload: []const u8,
) Nip04Error![]const u8 {
    const parsed = try nip04_payload_parse(payload);
    const ciphertext_len = try decode_base64_into(ciphertext_output, parsed.ciphertext_base64);
    if (ciphertext_len == 0 or ciphertext_len % limits.nip04_iv_bytes != 0) {
        return error.InvalidCiphertextLength;
    }
    _ = try decode_base64_fixed(out_iv[0..], parsed.iv_base64, error.InvalidIvLength);
    return ciphertext_output[0..ciphertext_len];
}

fn validate_base64_and_lengths(ciphertext_base64: []const u8, iv_base64: []const u8) Nip04Error!void {
    if (iv_base64.len != limits.nip04_iv_base64_bytes) return error.InvalidIvLength;

    var iv: [limits.nip04_iv_bytes]u8 = undefined;
    defer wipe_bytes(iv[0..]);
    _ = try decode_base64_fixed(iv[0..], iv_base64, error.InvalidIvLength);

    var ciphertext: [limits.nip04_ciphertext_max_bytes]u8 = undefined;
    defer wipe_bytes(ciphertext[0..]);
    const ciphertext_len = decode_base64_into(ciphertext[0..], ciphertext_base64) catch |err| {
        return switch (err) {
            error.BufferTooSmall => error.InvalidCiphertextLength,
            else => err,
        };
    };
    if (ciphertext_len == 0 or ciphertext_len % limits.nip04_iv_bytes != 0) {
        return error.InvalidCiphertextLength;
    }
}

fn decode_base64_fixed(
    output: []u8,
    input: []const u8,
    invalid_length_error: Nip04Error,
) Nip04Error![]const u8 {
    const decoded_len = base64_standard.Decoder.calcSizeForSlice(input) catch return error.InvalidBase64;
    if (decoded_len != output.len) return invalid_length_error;
    base64_standard.Decoder.decode(output, input) catch return error.InvalidBase64;
    return output;
}

fn decode_base64_into(output: []u8, input: []const u8) Nip04Error!usize {
    const decoded_len = base64_standard.Decoder.calcSizeForSlice(input) catch return error.InvalidBase64;
    if (decoded_len > output.len) return error.BufferTooSmall;
    base64_standard.Decoder.decode(output[0..decoded_len], input) catch return error.InvalidBase64;
    return decoded_len;
}

fn aes256_cbc_encrypt(
    output: []u8,
    plaintext: []const u8,
    shared_secret: [32]u8,
    iv: [limits.nip04_iv_bytes]u8,
) void {
    std.debug.assert(output.len == plaintext.len);
    std.debug.assert(output.len % limits.nip04_iv_bytes == 0);

    var ctx = Aes256.initEnc(shared_secret);
    var previous = iv;
    var block_input: [limits.nip04_iv_bytes]u8 = undefined;

    var index: usize = 0;
    while (index < plaintext.len) : (index += limits.nip04_iv_bytes) {
        xor_block(block_input[0..], plaintext[index .. index + limits.nip04_iv_bytes], previous[0..]);
        ctx.encrypt(
            output[index .. index + limits.nip04_iv_bytes][0..limits.nip04_iv_bytes],
            block_input[0..limits.nip04_iv_bytes],
        );
        @memcpy(previous[0..], output[index .. index + limits.nip04_iv_bytes]);
    }

    wipe_bytes(previous[0..]);
    wipe_bytes(block_input[0..]);
}

fn aes256_cbc_decrypt(
    output: []u8,
    ciphertext: []const u8,
    shared_secret: [32]u8,
    iv: [limits.nip04_iv_bytes]u8,
) void {
    std.debug.assert(output.len == ciphertext.len);
    std.debug.assert(output.len % limits.nip04_iv_bytes == 0);

    var ctx = Aes256.initDec(shared_secret);
    var previous = iv;
    var decrypted_block: [limits.nip04_iv_bytes]u8 = undefined;

    var index: usize = 0;
    while (index < ciphertext.len) : (index += limits.nip04_iv_bytes) {
        ctx.decrypt(
            decrypted_block[0..limits.nip04_iv_bytes],
            ciphertext[index .. index + limits.nip04_iv_bytes][0..limits.nip04_iv_bytes],
        );
        xor_block(
            output[index .. index + limits.nip04_iv_bytes],
            decrypted_block[0..],
            previous[0..],
        );
        @memcpy(previous[0..], ciphertext[index .. index + limits.nip04_iv_bytes]);
    }

    wipe_bytes(previous[0..]);
    wipe_bytes(decrypted_block[0..]);
}

fn write_pkcs7_padded_plaintext(output: []u8, plaintext: []const u8) void {
    std.debug.assert(output.len >= plaintext.len + 1);
    std.debug.assert(output.len % limits.nip04_iv_bytes == 0);

    @memcpy(output[0..plaintext.len], plaintext);
    const pad_len: u8 = @intCast(output.len - plaintext.len);
    @memset(output[plaintext.len..], pad_len);
}

fn remove_pkcs7_padding(output: []u8, padded_plaintext: []const u8) Nip04Error![]const u8 {
    std.debug.assert(padded_plaintext.len % limits.nip04_iv_bytes == 0);

    if (padded_plaintext.len == 0) return error.InvalidPadding;
    const pad_len = padded_plaintext[padded_plaintext.len - 1];
    if (pad_len == 0 or pad_len > limits.nip04_iv_bytes) return error.InvalidPadding;
    if (pad_len > padded_plaintext.len) return error.InvalidPadding;

    const message_len = padded_plaintext.len - pad_len;
    if (output.len < message_len) return error.BufferTooSmall;
    for (padded_plaintext[message_len..]) |byte| {
        if (byte != pad_len) return error.InvalidPadding;
    }
    @memcpy(output[0..message_len], padded_plaintext[0..message_len]);
    return output[0..message_len];
}

fn parse_message_tag(
    tag: nip01_event.EventTag,
    info: *Nip04MessageInfo,
    saw_recipient: *bool,
) Nip04Error!void {
    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "p")) return parse_recipient_tag(tag, info, saw_recipient);
    if (std.mem.eql(u8, tag.items[0], "e")) return parse_reply_tag(tag, info);
}

fn parse_recipient_tag(
    tag: nip01_event.EventTag,
    info: *Nip04MessageInfo,
    saw_recipient: *bool,
) Nip04Error!void {
    if (saw_recipient.*) return error.DuplicateRecipientTag;
    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidRecipientTag;

    info.recipient_pubkey = parse_lower_hex_32(tag.items[1]) catch return error.InvalidRecipientTag;
    info.recipient_relay_hint = null;
    if (tag.items.len == 3) {
        info.recipient_relay_hint = parse_optional_url(tag.items[2]) catch return error.InvalidRecipientTag;
    }
    saw_recipient.* = true;
}

fn parse_reply_tag(tag: nip01_event.EventTag, info: *Nip04MessageInfo) Nip04Error!void {
    if (info.reply_to != null) return error.DuplicateReplyTag;
    if (tag.items.len < 2 or tag.items.len > 5) return error.InvalidReplyTag;

    var reply = Nip04ReplyRef{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return error.InvalidReplyTag,
    };
    if (tag.items.len >= 3) {
        if (std.mem.eql(u8, tag.items[2], "reply")) {
            if (tag.items.len != 3) return error.InvalidReplyTag;
            info.reply_to = reply;
            return;
        }
        reply.relay_hint = parse_optional_url(tag.items[2]) catch return error.InvalidReplyTag;
    }
    if (tag.items.len == 4) {
        try validate_reply_suffix(tag.items[3]);
    }
    if (tag.items.len == 5) {
        if (!std.mem.eql(u8, tag.items[3], "reply")) return error.InvalidReplyTag;
        _ = parse_lower_hex_32(tag.items[4]) catch return error.InvalidReplyTag;
    }
    info.reply_to = reply;
}

fn validate_reply_suffix(text: []const u8) Nip04Error!void {
    if (std.mem.eql(u8, text, "reply")) return;
    return error.InvalidReplyTag;
}

fn parse_optional_url(text: []const u8) error{InvalidUrl}!?[]const u8 {
    if (text.len == 0) return null;
    return try parse_url(text);
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    return url_with_host.parse(text, limits.tag_item_bytes_max);
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    return lower_hex_32.parse(text);
}

fn xor_block(output: []u8, left: []const u8, right: []const u8) void {
    std.debug.assert(output.len == left.len);
    std.debug.assert(output.len == right.len);

    for (output, left, right) |*dst, lhs, rhs| {
        dst.* = lhs ^ rhs;
    }
}

fn wipe_bytes(buffer: []u8) void {
    std.crypto.secureZero(u8, buffer);
}

fn map_shared_secret_error(
    err: secp256k1_backend.BackendSharedSecretError,
) Nip04Error {
    return switch (err) {
        error.InvalidPrivateKey => error.InvalidPrivateKey,
        error.InvalidPublicKey => error.InvalidPublicKey,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

fn test_iv_provider(_: ?*anyopaque, out_iv: *[limits.nip04_iv_bytes]u8) Nip04Error!void {
    out_iv.* = [_]u8{0x44} ** limits.nip04_iv_bytes;
}

fn event_for_tags(
    kind: u32,
    tags: []const nip01_event.EventTag,
    content: []const u8,
) nip01_event.Event {
    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x02} ** 32,
        .created_at = 1,
        .kind = kind,
        .tags = tags,
        .content = content,
        .sig = [_]u8{0} ** 64,
    };
}

test "nip04 local encrypt and decrypt roundtrips with fixed IV" {
    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_secret = [_]u8{0x22} ** 32;
    const recipient_pubkey = try secp256k1_test_public_key(&recipient_secret);
    const sender_pubkey = try secp256k1_test_public_key(&sender_secret);

    var encoded: [limits.content_bytes_max]u8 = undefined;
    const payload = try nip04_encrypt(
        encoded[0..],
        &sender_secret,
        &recipient_pubkey,
        "hello nip04",
        null,
        test_iv_provider,
    );
    var plaintext: [limits.nip04_plaintext_max_bytes]u8 = undefined;
    const decrypted = try nip04_decrypt(
        plaintext[0..],
        &recipient_secret,
        &sender_pubkey,
        payload,
    );

    try std.testing.expectEqualStrings("hello nip04", decrypted);
}

test "nip04 payload parse and serialize roundtrip" {
    const payload = "AAAAAAAAAAAAAAAAAAAAAA==?iv=AAAAAAAAAAAAAAAAAAAAAA==";
    const parsed = try nip04_payload_parse(payload);
    var output: [limits.content_bytes_max]u8 = undefined;
    const serialized = try nip04_payload_serialize(
        output[0..],
        parsed.ciphertext_base64,
        parsed.iv_base64,
    );

    try std.testing.expectEqualStrings(payload, serialized);
}

test "nip04 message parse extracts strict recipient and reply tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
        .{ .items = &.{
            "e",
            "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210",
            "wss://relay.example",
        } },
    };
    const event = event_for_tags(4, tags[0..], "AAAAAAAAAAAAAAAAAAAAAA==?iv=AAAAAAAAAAAAAAAAAAAAAA==");

    const parsed = try nip04_message_parse(&event);
    try std.testing.expect(parsed.reply_to != null);
    try std.testing.expectEqualStrings(event.content, parsed.content);
    try std.testing.expectEqualStrings("wss://relay.example", parsed.reply_to.?.relay_hint.?);
}

test "nip04 message parse accepts short and long standard reply tags" {
    const short_reply_tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
        .{ .items = &.{
            "e",
            "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210",
            "reply",
        } },
    };
    const short_reply_event = event_for_tags(
        4,
        short_reply_tags[0..],
        "AAAAAAAAAAAAAAAAAAAAAA==?iv=AAAAAAAAAAAAAAAAAAAAAA==",
    );
    const short_reply = try nip04_message_parse(&short_reply_event);
    try std.testing.expect(short_reply.reply_to != null);
    try std.testing.expect(short_reply.reply_to.?.relay_hint == null);

    const long_reply_tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
        .{ .items = &.{
            "e",
            "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210",
            "wss://relay.example",
            "reply",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
    };
    const long_reply_event = event_for_tags(
        4,
        long_reply_tags[0..],
        "AAAAAAAAAAAAAAAAAAAAAA==?iv=AAAAAAAAAAAAAAAAAAAAAA==",
    );
    const long_reply = try nip04_message_parse(&long_reply_event);
    try std.testing.expect(long_reply.reply_to != null);
    try std.testing.expectEqualStrings("wss://relay.example", long_reply.reply_to.?.relay_hint.?);
}

test "nip04 message parse rejects malformed payloads and duplicate recipients" {
    const malformed_event = event_for_tags(
        4,
        &.{.{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } }},
        "AAAAAAAAAAAAAAAAAAAAAA==?iv=AAAAAAAAAAAAAAAAAAAA%%==",
    );
    try std.testing.expectError(error.InvalidBase64, nip04_message_parse(&malformed_event));

    const duplicate_tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "p",
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        } },
        .{ .items = &.{
            "p",
            "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210",
        } },
    };
    const duplicate_event = event_for_tags(
        4,
        duplicate_tags[0..],
        "AAAAAAAAAAAAAAAAAAAAAA==?iv=AAAAAAAAAAAAAAAAAAAAAA==",
    );
    try std.testing.expectError(error.DuplicateRecipientTag, nip04_message_parse(&duplicate_event));
}

test "nip04 decrypt rejects malformed padding" {
    const shared_secret = [_]u8{0x11} ** 32;
    const iv = [_]u8{0} ** limits.nip04_iv_bytes;
    const ciphertext = [_]u8{0} ** limits.nip04_iv_bytes;
    const ciphertext_base64_len = base64_standard.Encoder.calcSize(ciphertext.len);
    var ciphertext_base64: [24]u8 = undefined;
    const encoded_ciphertext = base64_standard.Encoder.encode(
        ciphertext_base64[0..ciphertext_base64_len],
        ciphertext[0..],
    );
    var iv_base64_storage: [limits.nip04_iv_base64_bytes]u8 = undefined;
    const encoded_iv = base64_standard.Encoder.encode(iv_base64_storage[0..], iv[0..]);
    var payload: [limits.content_bytes_max]u8 = undefined;
    const serialized = try nip04_payload_serialize(payload[0..], encoded_ciphertext, encoded_iv);
    var plaintext: [limits.nip04_plaintext_max_bytes]u8 = undefined;

    try std.testing.expectError(
        error.InvalidPadding,
        nip04_decrypt_with_shared_secret(plaintext[0..], &shared_secret, serialized),
    );
}

test "nip04 payload parse rejects oversized payload as invalid input" {
    var payload: [limits.nip04_payload_max_bytes + 1]u8 = undefined;
    @memset(payload[0..], 'A');

    try std.testing.expectError(error.InvalidPayloadFormat, nip04_payload_parse(payload[0..]));
}

test "nip04 shared secret matches node crypto secp256k1 ecdh output" {
    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_pubkey_hex = "466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f27";
    const expected_shared_secret_hex =
        "77e0510d5042e2f5e9e59c977b81eeed590cf7d20c1c51da451a8eaa9fdc45ff";
    const recipient_pubkey = try parse_lower_hex_32(recipient_pubkey_hex);
    const expected_shared_secret = try parse_lower_hex_32(expected_shared_secret_hex);

    const actual_shared_secret = try nip04_get_shared_secret(&sender_secret, &recipient_pubkey);
    try std.testing.expectEqualSlices(u8, expected_shared_secret[0..], actual_shared_secret[0..]);
}

test "nip04 encrypt with fixed iv matches node crypto aes-256-cbc payload" {
    const sender_secret = [_]u8{0x11} ** 32;
    const recipient_pubkey_hex = "466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f27";
    const expected_payload = "sN1Hm//UOqmtq8V++NVQnA==?iv=RERERERERERERERERERERA==";
    const recipient_pubkey = try parse_lower_hex_32(recipient_pubkey_hex);
    const iv = [_]u8{0x44} ** limits.nip04_iv_bytes;
    var payload: [limits.content_bytes_max]u8 = undefined;

    const actual_payload = try nip04_encrypt_with_iv(
        payload[0..],
        &sender_secret,
        &recipient_pubkey,
        "hello nip04",
        &iv,
    );
    try std.testing.expectEqualStrings(expected_payload, actual_payload);
}

test "nip04 decrypt accepts node crypto generated payload" {
    const recipient_secret = [_]u8{0x22} ** 32;
    const sender_pubkey_hex = "4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa";
    const node_payload = "sN1Hm//UOqmtq8V++NVQnA==?iv=RERERERERERERERERERERA==";
    const sender_pubkey = try parse_lower_hex_32(sender_pubkey_hex);
    var plaintext: [limits.nip04_plaintext_max_bytes]u8 = undefined;

    const decrypted = try nip04_decrypt(
        plaintext[0..],
        &recipient_secret,
        &sender_pubkey,
        node_payload,
    );
    try std.testing.expectEqualStrings("hello nip04", decrypted);
}

test "nip04 decrypt matches rust-nostr external vector" {
    const sender_secret_hex =
        "6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e";
    const receiver_secret_hex =
        "7b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e";
    const rust_payload =
        "dJc+WbBgaFCD2/kfg1XCWJParplBDxnZIdJGZ6FCTOg=?iv=M6VxRPkMZu7aIdD+10xPuw==";
    const sender_secret = try parse_lower_hex_32(sender_secret_hex);
    const receiver_secret = try parse_lower_hex_32(receiver_secret_hex);
    const sender_pubkey = try secp256k1_test_public_key(&sender_secret);
    var plaintext: [limits.nip04_plaintext_max_bytes]u8 = undefined;

    const decrypted = try nip04_decrypt(
        plaintext[0..],
        &receiver_secret,
        &sender_pubkey,
        rust_payload,
    );
    try std.testing.expectEqualStrings("Saturn, bringer of old age", decrypted);
}

test "nip04 encrypt with rust-nostr vector iv matches external payload" {
    const sender_secret_hex =
        "6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e";
    const receiver_secret_hex =
        "7b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e";
    const rust_payload =
        "dJc+WbBgaFCD2/kfg1XCWJParplBDxnZIdJGZ6FCTOg=?iv=M6VxRPkMZu7aIdD+10xPuw==";
    const sender_secret = try parse_lower_hex_32(sender_secret_hex);
    const receiver_secret = try parse_lower_hex_32(receiver_secret_hex);
    const receiver_pubkey = try secp256k1_test_public_key(&receiver_secret);
    const parsed = try nip04_payload_parse(rust_payload);
    var iv: [limits.nip04_iv_bytes]u8 = undefined;
    _ = try decode_base64_fixed(iv[0..], parsed.iv_base64, error.InvalidIvLength);
    var payload: [limits.content_bytes_max]u8 = undefined;

    const actual_payload = try nip04_encrypt_with_iv(
        payload[0..],
        &sender_secret,
        &receiver_pubkey,
        "Saturn, bringer of old age",
        &iv,
    );
    try std.testing.expectEqualStrings(rust_payload, actual_payload);
}

test "nip04 decrypt rejects non utf8 plaintext after valid decrypt" {
    const shared_secret = [_]u8{0x11} ** 32;
    const iv = [_]u8{0x22} ** limits.nip04_iv_bytes;
    const invalid_utf8 = [_]u8{0xff};
    var payload: [limits.content_bytes_max]u8 = undefined;
    const serialized = try nip04_encrypt_with_shared_secret_and_iv(
        payload[0..],
        &shared_secret,
        invalid_utf8[0..],
        &iv,
    );
    var plaintext: [limits.nip04_plaintext_max_bytes]u8 = undefined;

    try std.testing.expectError(
        error.InvalidPadding,
        nip04_decrypt_with_shared_secret(plaintext[0..], &shared_secret, serialized),
    );
}

fn secp256k1_test_public_key(secret_key: *const [32]u8) ![32]u8 {
    var public_key: [32]u8 = undefined;
    try secp256k1_backend.derive_xonly_public_key(secret_key, &public_key);
    return public_key;
}
