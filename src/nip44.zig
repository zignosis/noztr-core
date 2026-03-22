const std = @import("std");
const limits = @import("limits.zig");
const secp256k1_backend = @import("crypto/secp256k1_backend.zig");

const HkdfSha256 = std.crypto.kdf.hkdf.HkdfSha256;
const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const ChaCha20Ietf = std.crypto.stream.chacha.ChaCha20IETF;
const base64_standard = std.base64.standard;

const nip44_v2_salt = "nip44-v2";

/// Typed failures for strict NIP-44 v2 encrypt/decrypt boundaries.
pub const ConversationEncryptionError = error{
    InvalidPrivateKey,
    InvalidPublicKey,
    InvalidConversationKeyLength,
    InvalidNonceLength,
    InvalidPlaintextLength,
    InvalidPayloadLength,
    InvalidVersion,
    UnsupportedEncoding,
    InvalidBase64,
    InvalidMac,
    InvalidPadding,
    BufferTooSmall,
    BackendUnavailable,
    EntropyUnavailable,
};

/// Callback type for caller-provided nonce generation.
pub const Nip44NonceProvider = *const fn (
    ctx: ?*anyopaque,
    out_nonce: *[32]u8,
) ConversationEncryptionError!void;

/// Decoded NIP-44 payload frame.
pub const Nip44DecodedPayload = struct {
    version: u8,
    nonce: []const u8,
    ciphertext: []const u8,
    mac: []const u8,
};

/// Derive the NIP-44 conversation key from secp256k1 key agreement.
pub fn nip44_get_conversation_key(
    private_key: *const [32]u8,
    public_key: *const [32]u8,
) ConversationEncryptionError![32]u8 {
    std.debug.assert(@intFromPtr(private_key) != 0);
    std.debug.assert(@intFromPtr(public_key) != 0);

    var shared_x: [32]u8 = undefined;
    defer wipe_bytes(shared_x[0..]);

    secp256k1_backend.derive_shared_secret_x(private_key, public_key, &shared_x) catch |err| {
        return map_shared_secret_error(err);
    };

    const conversation_key = HkdfSha256.extract(nip44_v2_salt, shared_x[0..]);
    std.debug.assert(conversation_key.len == limits.nip44_conversation_key_bytes);
    std.debug.assert(conversation_key[0] <= 255);
    return conversation_key;
}

/// Compute padded plaintext length without the 2-byte prefix.
pub fn nip44_calc_padded_plaintext_len(plaintext_len: u16) ConversationEncryptionError!u32 {
    std.debug.assert(plaintext_len <= limits.nip44_plaintext_max_bytes);
    std.debug.assert(limits.nip44_plaintext_min_bytes > 0);

    if (plaintext_len < limits.nip44_plaintext_min_bytes) {
        return error.InvalidPlaintextLength;
    }
    if (plaintext_len <= 32) {
        return 32;
    }

    const next_power = calc_next_power_of_two(@as(u32, plaintext_len) - 1);
    const chunk = if (next_power <= 256) @as(u32, 32) else @divExact(next_power, 8);
    const multiple = @divFloor(@as(u32, plaintext_len) - 1, chunk) + 1;
    const padded_len_u32 = chunk * multiple;
    if (padded_len_u32 > limits.nip44_ciphertext_max_bytes - 2) {
        return error.InvalidPlaintextLength;
    }

    std.debug.assert(padded_len_u32 >= 32);
    std.debug.assert(padded_len_u32 <= limits.nip44_ciphertext_max_bytes - 2);
    return padded_len_u32;
}

/// Encrypt plaintext with random nonce callback and output base64 payload.
pub fn nip44_encrypt_to_base64(
    output: []u8,
    conversation_key: *const [32]u8,
    plaintext: []const u8,
    nonce_ctx: ?*anyopaque,
    nonce_provider: Nip44NonceProvider,
) ConversationEncryptionError![]const u8 {
    std.debug.assert(@intFromPtr(conversation_key) != 0);
    std.debug.assert(@intFromPtr(nonce_provider) != 0);

    var nonce: [32]u8 = undefined;
    defer wipe_bytes(nonce[0..]);
    try nonce_provider(nonce_ctx, &nonce);
    return nip44_encrypt_with_nonce_to_base64(output, conversation_key, plaintext, &nonce);
}

/// Encrypt plaintext with a fixed caller-provided nonce.
pub fn nip44_encrypt_with_nonce_to_base64(
    output: []u8,
    conversation_key: *const [32]u8,
    plaintext: []const u8,
    nonce: *const [32]u8,
) ConversationEncryptionError![]const u8 {
    std.debug.assert(@intFromPtr(conversation_key) != 0);
    std.debug.assert(@intFromPtr(nonce) != 0);

    try validate_fixed_size_secret(conversation_key[0..], limits.nip44_conversation_key_bytes);
    try validate_fixed_size_secret(nonce[0..], limits.nip44_nonce_bytes);

    const plaintext_len_u16 = try validate_plaintext_len(plaintext.len);
    const padded_len = try nip44_calc_padded_plaintext_len(plaintext_len_u16);
    const ciphertext_len: usize = @as(usize, padded_len) + 2;

    const raw_len = 1 + limits.nip44_nonce_bytes + ciphertext_len + limits.nip44_mac_bytes;
    const encoded_len = base64_standard.Encoder.calcSize(raw_len);
    if (output.len < encoded_len) {
        return error.BufferTooSmall;
    }

    var message_keys: [limits.nip44_message_keys_bytes]u8 = undefined;
    defer wipe_bytes(message_keys[0..]);

    var padded_plaintext: [limits.nip44_ciphertext_max_bytes]u8 = undefined;
    defer wipe_bytes(padded_plaintext[0..]);

    var raw_payload: [limits.nip44_payload_decoded_max_bytes]u8 = undefined;
    defer wipe_bytes(raw_payload[0..]);

    try derive_message_keys(&message_keys, conversation_key[0..], nonce[0..]);
    const padded_total = try write_padded_plaintext(padded_plaintext[0..], plaintext, padded_len);
    try encrypt_raw_payload(
        raw_payload[0..raw_len],
        nonce,
        padded_plaintext[0..padded_total],
        &message_keys,
    );

    const encoded = base64_standard.Encoder.encode(output, raw_payload[0..raw_len]);
    return encoded;
}

/// Decode and split NIP-44 base64 payload into frame components.
pub fn nip44_decode_payload(
    payload_base64: []const u8,
    raw_output: []u8,
) ConversationEncryptionError!Nip44DecodedPayload {
    std.debug.assert(payload_base64.len <= std.math.maxInt(usize));
    std.debug.assert(raw_output.len <= std.math.maxInt(usize));

    try ensure_supported_encoding(payload_base64);
    try ensure_base64_payload_length(payload_base64.len);

    const decoded_len = base64_standard.Decoder.calcSizeForSlice(payload_base64) catch {
        return error.InvalidBase64;
    };
    try ensure_decoded_payload_length(decoded_len);
    if (raw_output.len < decoded_len) {
        return error.BufferTooSmall;
    }

    base64_standard.Decoder.decode(raw_output[0..decoded_len], payload_base64) catch {
        return error.InvalidBase64;
    };

    const raw = raw_output[0..decoded_len];
    const version = raw[0];
    if (version != limits.nip44_version) {
        return error.InvalidVersion;
    }

    const nonce_start: usize = 1;
    const nonce_end: usize = nonce_start + limits.nip44_nonce_bytes;
    const mac_start: usize = raw.len - limits.nip44_mac_bytes;
    return .{
        .version = version,
        .nonce = raw[nonce_start..nonce_end],
        .ciphertext = raw[nonce_end..mac_start],
        .mac = raw[mac_start..],
    };
}

/// Decrypt a NIP-44 base64 payload into caller-provided plaintext buffer.
pub fn nip44_decrypt_from_base64(
    output_plaintext: []u8,
    conversation_key: *const [32]u8,
    payload_base64: []const u8,
) ConversationEncryptionError![]const u8 {
    std.debug.assert(@intFromPtr(conversation_key) != 0);
    std.debug.assert(payload_base64.len <= std.math.maxInt(usize));

    try validate_fixed_size_secret(conversation_key[0..], limits.nip44_conversation_key_bytes);

    var decoded_raw: [limits.nip44_payload_decoded_max_bytes]u8 = undefined;
    defer wipe_bytes(decoded_raw[0..]);

    const decoded = try nip44_decode_payload(payload_base64, decoded_raw[0..]);

    var message_keys: [limits.nip44_message_keys_bytes]u8 = undefined;
    defer wipe_bytes(message_keys[0..]);
    try derive_message_keys(&message_keys, conversation_key[0..], decoded.nonce);

    var expected_mac: [32]u8 = undefined;
    defer wipe_bytes(expected_mac[0..]);
    compute_mac(expected_mac[0..], decoded.nonce, decoded.ciphertext, message_keys[44..76]);
    if (!constant_time_equal(expected_mac[0..], decoded.mac)) {
        return error.InvalidMac;
    }

    var padded_plaintext: [limits.nip44_ciphertext_max_bytes]u8 = undefined;
    defer wipe_bytes(padded_plaintext[0..]);

    decrypt_ciphertext(
        padded_plaintext[0..decoded.ciphertext.len],
        decoded.ciphertext,
        &message_keys,
    );
    const plaintext = try remove_padding(
        output_plaintext,
        padded_plaintext[0..decoded.ciphertext.len],
    );
    if (!std.unicode.utf8ValidateSlice(plaintext)) {
        return error.InvalidPadding;
    }
    return plaintext;
}

fn validate_plaintext_len(plaintext_len: usize) ConversationEncryptionError!u16 {
    std.debug.assert(plaintext_len <= std.math.maxInt(usize));
    std.debug.assert(limits.nip44_plaintext_max_bytes <= std.math.maxInt(u16));

    if (plaintext_len < limits.nip44_plaintext_min_bytes) {
        return error.InvalidPlaintextLength;
    }
    if (plaintext_len > limits.nip44_plaintext_max_bytes) {
        return error.InvalidPlaintextLength;
    }
    return @intCast(plaintext_len);
}

fn validate_fixed_size_secret(secret: []const u8, expected_len: u8) ConversationEncryptionError!void {
    std.debug.assert(secret.len <= std.math.maxInt(usize));
    std.debug.assert(expected_len > 0);

    if (secret.len == expected_len) {
        return;
    }
    if (expected_len == limits.nip44_conversation_key_bytes) {
        return error.InvalidConversationKeyLength;
    }
    return error.InvalidNonceLength;
}

fn calc_next_power_of_two(value: u32) u32 {
    std.debug.assert(value > 0);
    std.debug.assert(value < std.math.maxInt(u32));

    const high = 31 - @clz(value);
    const shift = high + 1;
    const result = @as(u32, 1) << @intCast(shift);
    std.debug.assert(result > value);
    std.debug.assert(result >= 2);
    return result;
}

fn ensure_supported_encoding(payload_base64: []const u8) ConversationEncryptionError!void {
    std.debug.assert(payload_base64.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u8) == 1);

    if (payload_base64.len == 0) {
        return error.InvalidPayloadLength;
    }
    if (payload_base64[0] == '#') {
        return error.UnsupportedEncoding;
    }
}

fn ensure_base64_payload_length(length: usize) ConversationEncryptionError!void {
    std.debug.assert(length <= std.math.maxInt(usize));
    std.debug.assert(limits.nip44_payload_base64_min_bytes > 0);

    if (length < limits.nip44_payload_base64_min_bytes) {
        return error.InvalidPayloadLength;
    }
    if (length > limits.nip44_payload_base64_max_bytes) {
        return error.InvalidPayloadLength;
    }
}

fn ensure_decoded_payload_length(length: usize) ConversationEncryptionError!void {
    std.debug.assert(length <= std.math.maxInt(usize));
    std.debug.assert(limits.nip44_payload_decoded_min_bytes > 0);

    if (length < limits.nip44_payload_decoded_min_bytes) {
        return error.InvalidPayloadLength;
    }
    if (length > limits.nip44_payload_decoded_max_bytes) {
        return error.InvalidPayloadLength;
    }
}

fn derive_message_keys(out: []u8, conversation_key: []const u8, nonce: []const u8) ConversationEncryptionError!void {
    std.debug.assert(out.len >= limits.nip44_message_keys_bytes);
    std.debug.assert(conversation_key.len <= std.math.maxInt(usize));

    try validate_fixed_size_secret(conversation_key, limits.nip44_conversation_key_bytes);
    try validate_fixed_size_secret(nonce, limits.nip44_nonce_bytes);

    var conversation_key_array: [32]u8 = undefined;
    @memcpy(conversation_key_array[0..], conversation_key[0..32]);
    HkdfSha256.expand(out[0..limits.nip44_message_keys_bytes], nonce, conversation_key_array);
    wipe_bytes(conversation_key_array[0..]);
}

fn write_padded_plaintext(
    out: []u8,
    plaintext: []const u8,
    padded_plaintext_len: u32,
) ConversationEncryptionError!usize {
    std.debug.assert(padded_plaintext_len >= 32);
    std.debug.assert(plaintext.len <= limits.nip44_plaintext_max_bytes);

    const total_len: usize = @as(usize, padded_plaintext_len) + 2;
    if (out.len < total_len) {
        return error.BufferTooSmall;
    }

    const plaintext_len_u16 = try validate_plaintext_len(plaintext.len);
    std.mem.writeInt(u16, out[0..2], plaintext_len_u16, .big);
    @memcpy(out[2 .. 2 + plaintext.len], plaintext);
    @memset(out[2 + plaintext.len .. total_len], 0);
    return total_len;
}

fn encrypt_raw_payload(
    raw_payload: []u8,
    nonce: *const [32]u8,
    padded_plaintext: []const u8,
    message_keys: *const [limits.nip44_message_keys_bytes]u8,
) ConversationEncryptionError!void {
    std.debug.assert(raw_payload.len >= limits.nip44_payload_decoded_min_bytes);
    std.debug.assert(padded_plaintext.len >= limits.nip44_ciphertext_min_bytes);

    const ciphertext_start: usize = 1 + limits.nip44_nonce_bytes;
    const mac_start = ciphertext_start + padded_plaintext.len;
    const required_len = mac_start + limits.nip44_mac_bytes;
    if (raw_payload.len < required_len) {
        return error.BufferTooSmall;
    }

    raw_payload[0] = limits.nip44_version;
    @memcpy(raw_payload[1..33], nonce[0..]);
    ChaCha20Ietf.xor(
        raw_payload[ciphertext_start..mac_start],
        padded_plaintext,
        0,
        message_keys[0..32].*,
        message_keys[32..44].*,
    );
    compute_mac(
        raw_payload[mac_start..required_len],
        nonce[0..],
        raw_payload[ciphertext_start..mac_start],
        message_keys[44..76],
    );
}

fn compute_mac(out_mac: []u8, nonce: []const u8, ciphertext: []const u8, key: []const u8) void {
    std.debug.assert(out_mac.len == limits.nip44_mac_bytes);
    std.debug.assert(nonce.len == limits.nip44_nonce_bytes);

    var hmac = HmacSha256.init(key);
    hmac.update(nonce);
    hmac.update(ciphertext);
    hmac.final(out_mac[0..limits.nip44_mac_bytes]);
}

fn decrypt_ciphertext(
    output: []u8,
    ciphertext: []const u8,
    message_keys: *const [limits.nip44_message_keys_bytes]u8,
) void {
    std.debug.assert(output.len == ciphertext.len);
    std.debug.assert(ciphertext.len <= limits.nip44_ciphertext_max_bytes);

    ChaCha20Ietf.xor(
        output,
        ciphertext,
        0,
        message_keys[0..32].*,
        message_keys[32..44].*,
    );
}

fn remove_padding(output_plaintext: []u8, padded_plaintext: []const u8) ConversationEncryptionError![]const u8 {
    std.debug.assert(padded_plaintext.len <= limits.nip44_ciphertext_max_bytes);
    std.debug.assert(padded_plaintext.len >= limits.nip44_ciphertext_min_bytes);

    const plaintext_len = std.mem.readInt(u16, padded_plaintext[0..2], .big);
    if (plaintext_len < limits.nip44_plaintext_min_bytes) {
        return error.InvalidPadding;
    }
    if (plaintext_len > limits.nip44_plaintext_max_bytes) {
        return error.InvalidPadding;
    }

    const expected_padded_len = try nip44_calc_padded_plaintext_len(plaintext_len);
    const expected_total = @as(usize, expected_padded_len) + 2;
    if (padded_plaintext.len != expected_total) {
        return error.InvalidPadding;
    }
    const plaintext_len_usize: usize = plaintext_len;
    if (output_plaintext.len < plaintext_len_usize) {
        return error.BufferTooSmall;
    }

    @memcpy(
        output_plaintext[0..plaintext_len_usize],
        padded_plaintext[2 .. 2 + plaintext_len_usize],
    );
    if (!all_zero(padded_plaintext[2 + plaintext_len_usize ..])) {
        return error.InvalidPadding;
    }
    return output_plaintext[0..plaintext_len_usize];
}

fn all_zero(bytes: []const u8) bool {
    std.debug.assert(bytes.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u8) == 1);

    var index: usize = 0;
    while (index < bytes.len) : (index += 1) {
        if (bytes[index] != 0) {
            return false;
        }
    }
    return true;
}

fn constant_time_equal(left: []const u8, right: []const u8) bool {
    std.debug.assert(left.len <= std.math.maxInt(usize));
    std.debug.assert(right.len <= std.math.maxInt(usize));

    if (left.len != right.len) {
        return false;
    }

    var diff: u8 = 0;
    var index: usize = 0;
    while (index < left.len) : (index += 1) {
        diff |= left[index] ^ right[index];
    }
    return diff == 0;
}

fn wipe_bytes(bytes: []u8) void {
    std.debug.assert(bytes.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u8) == 1);

    std.crypto.secureZero(u8, bytes);
}

fn parse_hex_32(hex: []const u8) ![32]u8 {
    std.debug.assert(hex.len <= std.math.maxInt(usize));
    std.debug.assert(@sizeOf(u8) == 1);

    if (hex.len != 64) {
        return error.InvalidCharacter;
    }
    var out: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&out, hex);
    return out;
}

const EncryptVector = struct {
    conversation_key_hex: []const u8,
    nonce_hex: []const u8,
    plaintext: []const u8,
    payload_base64: []const u8,
};

const encrypt_vectors = [_]EncryptVector{
    .{
        .conversation_key_hex = "c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d",
        .nonce_hex = "0000000000000000000000000000000000000000000000000000000000000001",
        .plaintext = "a",
        .payload_base64 = "AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABee0G5VSK0/9YypIObAtDKfYEA" ++
            "jD35uVkHyB0F4DwrcNaCXlCWZKaArsGrY6M9wnuTMxWfp1RTN9Xga8no+kF5Vsb",
    },
    .{
        .conversation_key_hex = "c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d",
        .nonce_hex = "f00000000000000000000000000000f00000000000000000000000000000000f",
        .plaintext = "🍕🫃",
        .payload_base64 = "AvAAAAAAAAAAAAAAAAAAAPAAAAAAAAAAAAAAAAAAAAAPSKSK6is9ngkX2+cSq85Th16oR" ++
            "TISAOfhStnixqZziKMDvB0QQzgFZdjLTPicCJaV8nDITO+QfaQ61+KbWQIOO2Yj",
    },
    .{
        .conversation_key_hex = "3e2b52a63be47d34fe0a80e34e73d436d6963bc8f39827f327057a9986c20a45",
        .nonce_hex = "b635236c42db20f021bb8d1cdff5ca75dd1a0cc72ea742ad750f33010b24f73b",
        .plaintext = "表ポあA鷗ŒéＢ逍Üßªąñ丂㐀𠀀",
        .payload_base64 = "ArY1I2xC2yDwIbuNHN/1ynXdGgzHLqdCrXUPMwELJPc7s7JqlCMJBAIIjfkpHReBPXe" ++
            "oMCyuClwgbT419jUWU1PwaNl4FEQYKCDKVJz+97Mp3K+Q2YGa77B6gpxB/lr1QgoqpDf7w" ++
            "DVrDmOqGoiPjWDqy8KzLueKDcm9BVP8xeTJIxs=",
    },
    .{
        .conversation_key_hex = "d5a2f879123145a4b291d767428870f5a8d9e5007193321795b40183d4ab8c2b",
        .nonce_hex = "b20989adc3ddc41cd2c435952c0d59a91315d8c5218d5040573fc3749543acaf",
        .plaintext = "ability🤝的 ȺȾ",
        .payload_base64 = "ArIJia3D3cQc0sQ1lSwNWakTFdjFIY1QQFc/w3SVQ6yvbG2S0x4Yu86QGwPTy7mP3961I" ++
            "1XqB6SFFTzqDZZavhxoWMj7mEVGMQIsh2RLWI5EYQaQDIePSnXPlzf7CIt+voTD",
    },
    .{
        .conversation_key_hex = "3b15c977e20bfe4b8482991274635edd94f366595b1a3d2993515705ca3cedb8",
        .nonce_hex = "8d4442713eb9d4791175cb040d98d6fc5be8864d6ec2f89cf0895a2b2b72d1b1",
        .plaintext = "pepper👀їжак",
        .payload_base64 = "Ao1EQnE+udR5EXXLBA2Y1vxb6IZNbsL4nPCJWisrctGxY3AduCS+jTUgAAnfvKafkmpy1" ++
            "5+i9YMwCdccisRa8SvzW671T2JO4LFSPX31K4kYUKelSAdSPwe9NwO6LhOsnoJ+",
    },
};

const ConversationVector = struct {
    private_key_hex: []const u8,
    public_key_hex: []const u8,
    conversation_key_hex: []const u8,
};

const conversation_vectors = [_]ConversationVector{
    .{
        .private_key_hex = "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364139",
        .public_key_hex = "0000000000000000000000000000000000000000000000000000000000000002",
        .conversation_key_hex = "8b6392dbf2ec6a2b2d5b1477fc2be84d63ef254b667cadd31bd3f444c44ae6ba",
    },
    .{
        .private_key_hex = "0000000000000000000000000000000000000000000000000000000000000002",
        .public_key_hex = "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdeb",
        .conversation_key_hex = "be234f46f60a250bef52a5ee34c758800c4ca8e5030bf4cc1a31d37ba2104d43",
    },
    .{
        .private_key_hex = "0000000000000000000000000000000000000000000000000000000000000001",
        .public_key_hex = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
        .conversation_key_hex = "3b4610cb7189beb9cc29eb3716ecc6102f1247e8f3101a03a1787d8908aeb54e",
    },
};

fn fail_entropy_provider(_: ?*anyopaque, _: *[32]u8) ConversationEncryptionError!void {
    std.debug.assert(@sizeOf(u8) == 1);
    std.debug.assert(!@inComptime());
    return error.EntropyUnavailable;
}

fn force_invalid_conversation_key_length() ConversationEncryptionError!void {
    var invalid_secret: [31]u8 = [_]u8{0} ** 31;
    std.debug.assert(invalid_secret.len != limits.nip44_conversation_key_bytes);
    std.debug.assert(limits.nip44_conversation_key_bytes == limits.nip44_nonce_bytes);
    return validate_fixed_size_secret(
        invalid_secret[0..],
        limits.nip44_conversation_key_bytes,
    );
}

fn force_invalid_nonce_length() ConversationEncryptionError!void {
    std.debug.assert(limits.nip44_nonce_bytes == limits.nip44_conversation_key_bytes);
    std.debug.assert(limits.nip44_nonce_bytes == 32);
    return error.InvalidNonceLength;
}

fn map_shared_secret_error(
    shared_secret_error: secp256k1_backend.BackendSharedSecretError,
) ConversationEncryptionError {
    std.debug.assert(@intFromError(shared_secret_error) >= 0);
    std.debug.assert(@typeInfo(ConversationEncryptionError) == .error_set);

    return switch (shared_secret_error) {
        error.InvalidPrivateKey => error.InvalidPrivateKey,
        error.InvalidPublicKey => error.InvalidPublicKey,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

test "nip44 valid vectors derive conversation keys" {
    for (conversation_vectors) |vector| {
        const private_key = try parse_hex_32(vector.private_key_hex);
        const public_key = try parse_hex_32(vector.public_key_hex);
        const expected = try parse_hex_32(vector.conversation_key_hex);
        const actual = try nip44_get_conversation_key(&private_key, &public_key);
        try std.testing.expectEqualSlices(u8, expected[0..], actual[0..]);
        try std.testing.expect(actual[0] <= 255);
    }
}

test "nip44 valid vectors calc padded length" {
    try std.testing.expectEqual(@as(u32, 32), try nip44_calc_padded_plaintext_len(16));
    try std.testing.expectEqual(@as(u32, 32), try nip44_calc_padded_plaintext_len(32));
    try std.testing.expectEqual(@as(u32, 64), try nip44_calc_padded_plaintext_len(33));
    try std.testing.expectEqual(@as(u32, 64), try nip44_calc_padded_plaintext_len(49));
    try std.testing.expectEqual(@as(u32, 96), try nip44_calc_padded_plaintext_len(65));
}

test "nip44 padded length upper boundary accepts max plaintext" {
    const max_len = limits.nip44_plaintext_max_bytes;
    const max_padded = try nip44_calc_padded_plaintext_len(max_len);
    try std.testing.expectEqual(@as(u32, 65_536), max_padded);
    try std.testing.expect(max_padded <= limits.nip44_ciphertext_max_bytes - 2);
}

test "nip44 valid vectors encrypt and decrypt parity" {
    for (encrypt_vectors) |vector| {
        const conversation_key = try parse_hex_32(vector.conversation_key_hex);
        const nonce = try parse_hex_32(vector.nonce_hex);

        var encoded_output: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
        const encoded = try nip44_encrypt_with_nonce_to_base64(
            encoded_output[0..],
            &conversation_key,
            vector.plaintext,
            &nonce,
        );
        try std.testing.expectEqualStrings(vector.payload_base64, encoded);

        var plaintext_output: [limits.nip44_plaintext_max_bytes]u8 = undefined;
        const decrypted = try nip44_decrypt_from_base64(
            plaintext_output[0..],
            &conversation_key,
            vector.payload_base64,
        );
        try std.testing.expectEqualStrings(vector.plaintext, decrypted);
    }
}

test "nip44 deterministic fixed nonce encrypt path" {
    const vector = encrypt_vectors[0];
    const conversation_key = try parse_hex_32(vector.conversation_key_hex);
    const nonce = try parse_hex_32(vector.nonce_hex);

    var encoded_a: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    var encoded_b: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const payload_a = try nip44_encrypt_with_nonce_to_base64(
        encoded_a[0..],
        &conversation_key,
        vector.plaintext,
        &nonce,
    );
    const payload_b = try nip44_encrypt_with_nonce_to_base64(
        encoded_b[0..],
        &conversation_key,
        vector.plaintext,
        &nonce,
    );

    try std.testing.expectEqualStrings(payload_a, payload_b);
    try std.testing.expectEqualStrings(vector.payload_base64, payload_a);
}

test "nip44 decrypt staged check order enforces version before mac" {
    const vector = encrypt_vectors[0];
    const conversation_key = try parse_hex_32(vector.conversation_key_hex);
    const decoded_len = try base64_standard.Decoder.calcSizeForSlice(vector.payload_base64);

    var decoded: [limits.nip44_payload_decoded_max_bytes]u8 = undefined;
    _ = try nip44_decode_payload(vector.payload_base64, decoded[0..]);

    decoded[0] = 3;
    decoded[decoded_len - 1] ^= 1;

    var mutated_b64: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const encoded = base64_standard.Encoder.encode(mutated_b64[0..], decoded[0..decoded_len]);

    var plaintext_output: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    try std.testing.expectError(
        error.InvalidVersion,
        nip44_decrypt_from_base64(plaintext_output[0..], &conversation_key, encoded),
    );
}

test "nip44 decrypt staged check order enforces mac before padding" {
    const vector = encrypt_vectors[0];
    const conversation_key = try parse_hex_32(vector.conversation_key_hex);

    var decoded: [limits.nip44_payload_decoded_max_bytes]u8 = undefined;
    const decoded_payload = try nip44_decode_payload(vector.payload_base64, decoded[0..]);
    const decoded_len = 1 + limits.nip44_nonce_bytes + decoded_payload.ciphertext.len +
        limits.nip44_mac_bytes;

    const ciphertext_start = 1 + limits.nip44_nonce_bytes;
    decoded[ciphertext_start] ^= 0xff;
    decoded[decoded_len - 1] ^= 1;

    var mutated_b64: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const encoded = base64_standard.Encoder.encode(mutated_b64[0..], decoded[0..decoded_len]);

    var plaintext_output: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    try std.testing.expectError(
        error.InvalidMac,
        nip44_decrypt_from_base64(plaintext_output[0..], &conversation_key, encoded),
    );
}

test "nip44 invalid vectors and forcing checks" {
    const bad_mac_conversation_key = try parse_hex_32(
        "cff7bd6a3e29a450fd27f6c125d5edeb0987c475fd1e8d97591e0d4d8a89763c",
    );
    const bad_mac_ciphertext =
        "Agn/l3ULCEAS4V7LhGFM6IGA17jsDUaFCKhrbXDANholyySBfeh+EN8wNB9gaLlg4j6wdBYh+3oK+mnx" ++
        "Wu3NKRbSvQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    const bad_padding_conversation_key = try parse_hex_32(
        "5254827d29177622d40a7b67cad014fe7137700c3c523903ebbe3e1b74d40214",
    );
    const bad_padding_ciphertext =
        "Anq2XbuLvCuONcr7V0UxTh8FAyWoZNEdBHXvdbNmDZHB573MI7R7rrTYftpqmvUpahmBC2sngmI14/L0" ++
        "HjOZ7lWGJlzdh6luiOnGPc46cGxf08MRC4CIuxx3i2Lm0KqgJ7vA";

    var plaintext_output: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    const valid_conversation_key = try parse_hex_32(encrypt_vectors[0].conversation_key_hex);
    try std.testing.expectError(
        error.UnsupportedEncoding,
        nip44_decrypt_from_base64(plaintext_output[0..], &valid_conversation_key, "#AQ=="),
    );
    try std.testing.expectError(
        error.InvalidPayloadLength,
        nip44_decrypt_from_base64(plaintext_output[0..], &bad_mac_conversation_key, "AQ=="),
    );
    try std.testing.expectError(
        error.InvalidMac,
        nip44_decrypt_from_base64(
            plaintext_output[0..],
            &bad_mac_conversation_key,
            bad_mac_ciphertext,
        ),
    );
    try std.testing.expectError(
        error.InvalidPadding,
        nip44_decrypt_from_base64(
            plaintext_output[0..],
            &bad_padding_conversation_key,
            bad_padding_ciphertext,
        ),
    );

    const conversation_key = try parse_hex_32(encrypt_vectors[0].conversation_key_hex);
    var tiny_output: [8]u8 = undefined;
    const nonce = try parse_hex_32(encrypt_vectors[0].nonce_hex);
    try std.testing.expectError(
        error.BufferTooSmall,
        nip44_encrypt_with_nonce_to_base64(
            tiny_output[0..],
            &conversation_key,
            encrypt_vectors[0].plaintext,
            &nonce,
        ),
    );
}

test "nip44 decrypt rejects invalid utf8 plaintext" {
    const conversation_key = try parse_hex_32(encrypt_vectors[0].conversation_key_hex);
    const nonce = try parse_hex_32(encrypt_vectors[0].nonce_hex);
    const invalid_utf8 = [_]u8{ 0xC3, 0x28 };

    var encoded_output: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const payload = try nip44_encrypt_with_nonce_to_base64(
        encoded_output[0..],
        &conversation_key,
        invalid_utf8[0..],
        &nonce,
    );

    var plaintext_output: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    try std.testing.expectError(
        error.InvalidPadding,
        nip44_decrypt_from_base64(plaintext_output[0..], &conversation_key, payload),
    );
}

test "nip44 additional public error forcing" {
    const conversation_key = try parse_hex_32(encrypt_vectors[0].conversation_key_hex);
    const nonce = try parse_hex_32(encrypt_vectors[0].nonce_hex);

    var encoded_output: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    try std.testing.expectError(
        error.InvalidPlaintextLength,
        nip44_encrypt_with_nonce_to_base64(encoded_output[0..], &conversation_key, "", &nonce),
    );

    var invalid_len_plaintext: [@as(usize, limits.nip44_plaintext_max_bytes) + 1]u8 = undefined;
    @memset(invalid_len_plaintext[0..], 'a');
    try std.testing.expectError(
        error.InvalidPlaintextLength,
        nip44_encrypt_with_nonce_to_base64(
            encoded_output[0..],
            &conversation_key,
            invalid_len_plaintext[0..],
            &nonce,
        ),
    );

    try std.testing.expectError(
        error.EntropyUnavailable,
        nip44_encrypt_to_base64(
            encoded_output[0..],
            &conversation_key,
            "a",
            null,
            fail_entropy_provider,
        ),
    );

    var decoded_raw_tiny: [10]u8 = undefined;
    try std.testing.expectError(
        error.BufferTooSmall,
        nip44_decode_payload(encrypt_vectors[0].payload_base64, decoded_raw_tiny[0..]),
    );

    var invalid_base64_payload = [_]u8{0} ** limits.nip44_payload_base64_min_bytes;
    @memset(invalid_base64_payload[0..], 'A');
    invalid_base64_payload[17] = '!';
    var decoded_raw: [limits.nip44_payload_decoded_max_bytes]u8 = undefined;
    try std.testing.expectError(
        error.InvalidBase64,
        nip44_decode_payload(invalid_base64_payload[0..], decoded_raw[0..]),
    );

    try std.testing.expectError(
        error.InvalidConversationKeyLength,
        force_invalid_conversation_key_length(),
    );
    try std.testing.expectError(error.InvalidNonceLength, force_invalid_nonce_length());
}

test "nip44 encrypt and decrypt max plaintext boundary" {
    const conversation_key = try parse_hex_32(encrypt_vectors[0].conversation_key_hex);
    const nonce = try parse_hex_32(encrypt_vectors[0].nonce_hex);

    var max_plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    var index: usize = 0;
    while (index < max_plaintext.len) : (index += 1) {
        max_plaintext[index] = @as(u8, @intCast('a' + (index % 26)));
    }

    var payload_base64: [limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const encoded = try nip44_encrypt_with_nonce_to_base64(
        payload_base64[0..],
        &conversation_key,
        max_plaintext[0..],
        &nonce,
    );

    var decrypted_plaintext: [limits.nip44_plaintext_max_bytes]u8 = undefined;
    const decrypted = try nip44_decrypt_from_base64(
        decrypted_plaintext[0..],
        &conversation_key,
        encoded,
    );

    try std.testing.expectEqual(@as(usize, limits.nip44_plaintext_max_bytes), decrypted.len);
    try std.testing.expectEqualSlices(u8, max_plaintext[0..], decrypted);
}

test "nip44 conversation key invalid key forcing" {
    const invalid_private = try parse_hex_32(
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    );
    const invalid_public = try parse_hex_32(
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    );
    const valid_public = try parse_hex_32(conversation_vectors[2].public_key_hex);

    const valid_private = try parse_hex_32(conversation_vectors[0].private_key_hex);

    try std.testing.expectError(
        error.InvalidPrivateKey,
        nip44_get_conversation_key(&invalid_private, &valid_public),
    );
    try std.testing.expectError(
        error.InvalidPublicKey,
        nip44_get_conversation_key(&valid_private, &invalid_public),
    );
}

test "nip44 backend outage mapping stays distinct from entropy failure" {
    const mapped_error = map_shared_secret_error(error.BackendUnavailable);

    try std.testing.expect(mapped_error == error.BackendUnavailable);
    try std.testing.expect(mapped_error != error.EntropyUnavailable);
}
