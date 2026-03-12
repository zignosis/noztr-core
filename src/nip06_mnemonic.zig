const std = @import("std");
const limits = @import("limits.zig");
const libwally = @import("libwally");

const c = libwally.c;
const hardened_bit: u32 = c.BIP32_INITIAL_HARDENED_CHILD;
const private_skip_hash: u32 = c.BIP32_FLAG_KEY_PRIVATE | c.BIP32_FLAG_SKIP_HASH;

pub const Nip06Error = error{
    InvalidMnemonicLength,
    UnknownMnemonicWord,
    InvalidChecksum,
    InvalidUtf8,
    InvalidNormalization,
    InvalidSeed,
    InvalidAccount,
    DerivationFailure,
    BufferTooSmall,
    BackendUnavailable,
};

var backend_once = std.once(init_backend_once);
var backend_error: ?Nip06Error = null;

/// Validate an English BIP39 mnemonic for the NIP-06 derivation boundary.
pub fn mnemonic_validate(mnemonic: []const u8) Nip06Error!void {
    std.debug.assert(mnemonic.len <= limits.nip06_mnemonic_bytes_max);
    std.debug.assert(@sizeOf(Nip06Error) > 0);

    try validate_mnemonic_text(mnemonic);
    try require_known_words(mnemonic);
    try ensure_backend();

    var mnemonic_storage: [limits.nip06_mnemonic_bytes_max + 1]u8 = undefined;
    defer wipe_bytes(mnemonic_storage[0..]);
    const mnemonic_z = try write_c_string(mnemonic_storage[0..], mnemonic);
    if (c.bip39_mnemonic_validate(null, mnemonic_z.ptr) != c.WALLY_OK) {
        return error.InvalidChecksum;
    }
}

/// Derive the 64-byte BIP39 seed from a validated mnemonic and optional passphrase.
pub fn mnemonic_to_seed(
    output: []u8,
    mnemonic: []const u8,
    passphrase: ?[]const u8,
) Nip06Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(@sizeOf([limits.nip06_seed_bytes]u8) == limits.nip06_seed_bytes);

    if (output.len < limits.nip06_seed_bytes) return error.BufferTooSmall;
    try mnemonic_validate(mnemonic);
    try validate_optional_utf8_text(passphrase, limits.nip06_passphrase_bytes_max);
    try ensure_backend();

    var mnemonic_storage: [limits.nip06_mnemonic_bytes_max + 1]u8 = undefined;
    defer wipe_bytes(mnemonic_storage[0..]);
    var passphrase_storage: [limits.nip06_passphrase_bytes_max + 1]u8 = undefined;
    defer wipe_bytes(passphrase_storage[0..]);
    const mnemonic_z = try write_c_string(mnemonic_storage[0..], mnemonic);
    const passphrase_z = try write_optional_c_string(passphrase_storage[0..], passphrase);

    const result = c.bip39_mnemonic_to_seed512(
        mnemonic_z.ptr,
        if (passphrase_z) |value| value.ptr else null,
        output.ptr,
        limits.nip06_seed_bytes,
    );
    if (result != c.WALLY_OK) return error.BackendUnavailable;
    return output[0..limits.nip06_seed_bytes];
}

/// Derive the canonical Nostr secret key at `m/44'/1237'/<account>'/0/0`.
pub fn derive_nostr_secret_key_from_seed(
    output: []u8,
    seed: []const u8,
    account: u32,
) Nip06Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(seed.len <= limits.nip06_seed_bytes);

    if (output.len < limits.nip06_secret_key_bytes) return error.BufferTooSmall;
    if (seed.len != limits.nip06_seed_bytes) return error.InvalidSeed;
    if (account >= hardened_bit) return error.InvalidAccount;
    try ensure_backend();

    var master_key: c.struct_ext_key = undefined;
    defer wipe_ext_key(&master_key);
    try create_master_key(seed, &master_key);

    var current_key = master_key;
    defer wipe_ext_key(&current_key);
    var next_key: c.struct_ext_key = undefined;
    defer wipe_ext_key(&next_key);

    try derive_hardened_child(&current_key, 44, &next_key);
    std.mem.swap(c.struct_ext_key, &current_key, &next_key);
    try derive_hardened_child(&current_key, 1237, &next_key);
    std.mem.swap(c.struct_ext_key, &current_key, &next_key);
    try derive_hardened_child(&current_key, account, &next_key);
    std.mem.swap(c.struct_ext_key, &current_key, &next_key);
    try derive_normal_child(&current_key, 0, &next_key);
    std.mem.swap(c.struct_ext_key, &current_key, &next_key);
    try derive_normal_child(&current_key, 0, &next_key);
    std.mem.swap(c.struct_ext_key, &current_key, &next_key);
    return copy_secret_key(output, &current_key);
}

/// Validate the mnemonic and derive the canonical Nostr secret key.
pub fn derive_nostr_secret_key(
    output: []u8,
    mnemonic: []const u8,
    passphrase: ?[]const u8,
    account: u32,
) Nip06Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(@sizeOf([limits.nip06_seed_bytes]u8) == limits.nip06_seed_bytes);

    var seed: [limits.nip06_seed_bytes]u8 = undefined;
    defer wipe_bytes(seed[0..]);
    _ = try mnemonic_to_seed(seed[0..], mnemonic, passphrase);
    return derive_nostr_secret_key_from_seed(output, seed[0..], account);
}

fn ensure_backend() Nip06Error!void {
    std.debug.assert(backend_error == null or @intFromError(backend_error.?) >= 0);
    std.debug.assert(!@inComptime());

    backend_once.call();
    if (backend_error) |err| return err;
}

fn init_backend_once() void {
    std.debug.assert(!@inComptime());
    std.debug.assert(backend_error == null);

    if (c.wally_init(0) != c.WALLY_OK) {
        backend_error = error.BackendUnavailable;
        return;
    }

    var entropy: [c.WALLY_SECP_RANDOMIZE_LEN]u8 = undefined;
    std.crypto.random.bytes(&entropy);
    defer wipe_bytes(entropy[0..]);
    if (c.wally_secp_randomize(&entropy, entropy.len) != c.WALLY_OK) {
        backend_error = error.BackendUnavailable;
    }
}

fn validate_mnemonic_text(mnemonic: []const u8) Nip06Error!void {
    std.debug.assert(mnemonic.len <= limits.nip06_mnemonic_bytes_max);
    std.debug.assert(@sizeOf(u16) == 2);

    if (mnemonic.len == 0 or mnemonic.len > limits.nip06_mnemonic_bytes_max) {
        return error.InvalidMnemonicLength;
    }
    if (!std.unicode.utf8ValidateSlice(mnemonic)) return error.InvalidUtf8;
    try require_ascii(mnemonic);
    try require_mnemonic_word_count(mnemonic);
}

fn validate_optional_utf8_text(text: ?[]const u8, max_len: u16) Nip06Error!void {
    std.debug.assert(max_len > 0);
    std.debug.assert(max_len <= limits.content_bytes_max);

    const value = text orelse return;
    if (value.len > max_len) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidUtf8;
    try require_ascii(value);
}

fn require_ascii(text: []const u8) Nip06Error!void {
    std.debug.assert(text.len <= limits.content_bytes_max);
    std.debug.assert(@sizeOf(u8) == 1);

    for (text) |byte| {
        if (byte > 0x7f) return error.InvalidNormalization;
    }
}

fn require_mnemonic_word_count(mnemonic: []const u8) Nip06Error!void {
    std.debug.assert(mnemonic.len > 0);
    std.debug.assert(mnemonic.len <= limits.nip06_mnemonic_bytes_max);

    var index: u16 = 0;
    var word_count: u8 = 0;
    while (index < mnemonic.len) {
        if (mnemonic[index] == ' ') return error.InvalidMnemonicLength;
        const next = next_word_index(mnemonic, index);
        word_count += 1;
        index = next;
        if (index == mnemonic.len) break;
        if (mnemonic[index] != ' ') return error.InvalidMnemonicLength;
        index += 1;
        if (index == mnemonic.len) return error.InvalidMnemonicLength;
    }
    if (!is_supported_word_count(word_count)) return error.InvalidMnemonicLength;
}

fn require_known_words(mnemonic: []const u8) Nip06Error!void {
    std.debug.assert(mnemonic.len > 0);
    std.debug.assert(mnemonic.len <= limits.nip06_mnemonic_bytes_max);

    var index: u16 = 0;
    while (index < mnemonic.len) {
        const next = next_word_index(mnemonic, index);
        if (!word_is_known(mnemonic[index..next])) return error.UnknownMnemonicWord;
        index = next;
        if (index < mnemonic.len) index += 1;
    }
}

fn next_word_index(mnemonic: []const u8, start: u16) u16 {
    std.debug.assert(start < mnemonic.len);
    std.debug.assert(mnemonic[start] != ' ');

    var index = start;
    while (index < mnemonic.len and mnemonic[index] != ' ') : (index += 1) {}
    return index;
}

fn is_supported_word_count(word_count: u8) bool {
    std.debug.assert(word_count <= 24);
    std.debug.assert(@sizeOf(u8) == 1);

    return word_count == 12 or word_count == 15 or word_count == 18 or
        word_count == 21 or word_count == 24;
}

fn word_is_known(word: []const u8) bool {
    std.debug.assert(word.len > 0);
    std.debug.assert(word.len <= limits.nip06_mnemonic_bytes_max);

    var index: usize = 0;
    while (index < c.BIP39_WORDLIST_LEN) : (index += 1) {
        const entry = c.bip39_get_word_by_index(null, index) orelse return false;
        if (std.mem.eql(u8, std.mem.span(entry), word)) return true;
    }
    return false;
}

fn write_c_string(buffer: []u8, text: []const u8) Nip06Error![:0]const u8 {
    std.debug.assert(buffer.len > 0);
    std.debug.assert(text.len + 1 <= buffer.len);

    if (text.len + 1 > buffer.len) return error.BufferTooSmall;
    @memcpy(buffer[0..text.len], text);
    buffer[text.len] = 0;
    return buffer[0..text.len :0];
}

fn write_optional_c_string(buffer: []u8, text: ?[]const u8) Nip06Error!?[:0]const u8 {
    std.debug.assert(buffer.len > 0);
    std.debug.assert(text == null or text.?.len + 1 <= buffer.len);

    const value = text orelse return null;
    return try write_c_string(buffer, value);
}

fn create_master_key(seed: []const u8, output: *c.struct_ext_key) Nip06Error!void {
    std.debug.assert(seed.len == limits.nip06_seed_bytes);
    std.debug.assert(@sizeOf(c.struct_ext_key) > limits.nip06_seed_bytes);

    const result = c.bip32_key_from_seed(
        seed.ptr,
        seed.len,
        c.BIP32_VER_MAIN_PRIVATE,
        c.BIP32_FLAG_SKIP_HASH,
        output,
    );
    if (result != c.WALLY_OK) return error.DerivationFailure;
}

fn derive_hardened_child(
    parent: *const c.struct_ext_key,
    index: u32,
    output: *c.struct_ext_key,
) Nip06Error!void {
    std.debug.assert(index < hardened_bit);
    std.debug.assert(@sizeOf(c.struct_ext_key) > 0);

    const child_index = hardened_bit | index;
    const result = c.bip32_key_from_parent(parent, child_index, private_skip_hash, output);
    if (result != c.WALLY_OK) return error.DerivationFailure;
}

fn derive_normal_child(
    parent: *const c.struct_ext_key,
    index: u32,
    output: *c.struct_ext_key,
) Nip06Error!void {
    std.debug.assert(index < hardened_bit);
    std.debug.assert(@sizeOf(c.struct_ext_key) > 0);

    const result = c.bip32_key_from_parent(parent, index, private_skip_hash, output);
    if (result != c.WALLY_OK) return error.DerivationFailure;
}

fn copy_secret_key(output: []u8, hdkey: *const c.struct_ext_key) Nip06Error![]const u8 {
    std.debug.assert(output.len <= limits.content_bytes_max);
    std.debug.assert(hdkey.priv_key.len == limits.nip06_secret_key_bytes + 1);

    if (output.len < limits.nip06_secret_key_bytes) return error.BufferTooSmall;
    if (hdkey.priv_key[0] != 0) return error.DerivationFailure;

    var staging: [limits.nip06_secret_key_bytes]u8 = undefined;
    defer wipe_bytes(staging[0..]);
    @memcpy(staging[0..], hdkey.priv_key[1 .. limits.nip06_secret_key_bytes + 1]);
    @memcpy(output[0..limits.nip06_secret_key_bytes], staging[0..]);
    return output[0..limits.nip06_secret_key_bytes];
}

fn wipe_ext_key(hdkey: *c.struct_ext_key) void {
    std.debug.assert(!@inComptime());
    std.debug.assert(@sizeOf(c.struct_ext_key) > 0);

    wipe_bytes(std.mem.asBytes(hdkey));
}

fn wipe_bytes(bytes: []u8) void {
    std.debug.assert(bytes.len >= 0);
    std.debug.assert(!@inComptime());

    std.crypto.secureZero(u8, bytes);
}

test "mnemonic validate accepts official vectors" {
    try mnemonic_validate(
        "leader monkey parrot ring guide accident before fence cannon height naive bean",
    );
    try mnemonic_validate(
        "what bleak badge arrange retreat wolf trade produce cricket blur garlic valid proud rude strong choose busy staff weather area salt hollow arm fade",
    );
}

test "mnemonic to seed matches official bip39 vectors" {
    try expect_seed_hex(
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
        "TREZOR",
        "c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e5349553" ++
            "1f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04",
    );
    try expect_seed_hex(
        "legal winner thank year wave sausage worth useful legal winner thank yellow",
        "TREZOR",
        "2e8905819b8723fe2c1d161860e5ee1830318dbf49a83bd451cfb8440c28bd6f" ++
            "a457fe1296106559a3c80937a1c1069be3a3a5bd381ee6260e8d9739fce1f607",
    );
}

test "derive nostr secret key matches canonical vectors" {
    try expect_secret_key_hex(
        "equal dragon fabric refuse stable cherry smoke allow alley easy never medal attend together lumber movie what sad siege weather matrix buffalo state shoot",
        0,
        "06992419a8fe821dd8de03d4c300614e8feefb5ea936b76f89976dcace8aebee",
    );
    try expect_secret_key_hex(
        "leader monkey parrot ring guide accident before fence cannon height naive bean",
        0,
        "7f7ff03d123792d6ac594bfa67bf6d0c0ab55b6b1fdb6249303fe861f1ccba9a",
    );
    try expect_secret_key_hex(
        "what bleak badge arrange retreat wolf trade produce cricket blur garlic valid proud rude strong choose busy staff weather area salt hollow arm fade",
        0,
        "c15d739894c81a2fcfd3a2df85a0d2c0dbc47a280d092799f144d73d7ae78add",
    );
}

test "derive nostr secret key covers account one deterministically" {
    var first: [limits.nip06_secret_key_bytes]u8 = undefined;
    var second: [limits.nip06_secret_key_bytes]u8 = undefined;
    var third: [limits.nip06_secret_key_bytes]u8 = undefined;
    const mnemonic =
        "equal dragon fabric refuse stable cherry smoke allow alley easy never medal " ++
        "attend together lumber movie what sad siege weather matrix buffalo state shoot";

    const first_key = try derive_nostr_secret_key(first[0..], mnemonic, null, 1);
    const second_key = try derive_nostr_secret_key(second[0..], mnemonic, null, 1);
    const account_zero = try derive_nostr_secret_key(third[0..], mnemonic, null, 0);

    try std.testing.expectEqualStrings(
        "5735ecd7389ba3dcc0c4464d6c9328867821560c3923acff14aeeb4b6cd5c775",
        &std.fmt.bytesToHex(first, .lower),
    );
    try std.testing.expectEqualSlices(u8, first_key, second_key);
    try std.testing.expect(!std.mem.eql(u8, first_key, account_zero));
}

test "null and empty passphrase derive the same seed and secret key" {
    const mnemonic =
        "abandon abandon abandon abandon abandon abandon abandon abandon " ++
        "abandon abandon abandon about";
    var seed_null: [limits.nip06_seed_bytes]u8 = undefined;
    var seed_empty: [limits.nip06_seed_bytes]u8 = undefined;
    var secret_null: [limits.nip06_secret_key_bytes]u8 = undefined;
    var secret_empty: [limits.nip06_secret_key_bytes]u8 = undefined;

    const null_seed = try mnemonic_to_seed(seed_null[0..], mnemonic, null);
    const empty_seed = try mnemonic_to_seed(seed_empty[0..], mnemonic, "");
    const null_secret = try derive_nostr_secret_key(secret_null[0..], mnemonic, null, 0);
    const empty_secret = try derive_nostr_secret_key(secret_empty[0..], mnemonic, "", 0);

    try std.testing.expectEqualSlices(u8, null_seed, empty_seed);
    try std.testing.expectEqualSlices(u8, null_secret, empty_secret);
}

test "mnemonic boundary rejects malformed and invalid inputs" {
    const bad_utf8 = [_]u8{ 0xc3, 0x28 };
    const non_ascii_mnemonic = "legal winner thank year wave sausage worth useful legal winner thank yéllow";

    try std.testing.expectError(
        error.InvalidMnemonicLength,
        mnemonic_validate("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"),
    );
    try std.testing.expectError(
        error.UnknownMnemonicWord,
        mnemonic_validate(
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon zzzz",
        ),
    );
    try std.testing.expectError(
        error.InvalidChecksum,
        mnemonic_validate(
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon",
        ),
    );
    try std.testing.expectError(error.InvalidUtf8, mnemonic_validate(bad_utf8[0..]));
    try std.testing.expectError(
        error.InvalidNormalization,
        mnemonic_validate(non_ascii_mnemonic),
    );
}

test "derive boundary enforces account seed and output limits" {
    var seed_bytes = [_]u8{0} ** limits.nip06_seed_bytes;
    const short_seed = [_]u8{0} ** (limits.nip06_seed_bytes - 1);
    var full_output: [limits.nip06_secret_key_bytes]u8 = undefined;
    var short_output: [limits.nip06_secret_key_bytes - 1]u8 = undefined;
    var short_seed_output: [limits.nip06_seed_bytes - 1]u8 = undefined;

    try std.testing.expectError(
        error.InvalidUtf8,
        mnemonic_to_seed(
            seed_bytes[0..],
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            &[_]u8{ 0xc3, 0x28 },
        ),
    );
    try std.testing.expectError(
        error.InvalidNormalization,
        mnemonic_to_seed(
            seed_bytes[0..],
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            "Trézor",
        ),
    );
    try std.testing.expectError(
        error.BufferTooSmall,
        mnemonic_to_seed(
            short_seed_output[0..],
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            "TREZOR",
        ),
    );
    try std.testing.expectError(
        error.InvalidAccount,
        derive_nostr_secret_key_from_seed(full_output[0..], seed_bytes[0..], hardened_bit),
    );
    try std.testing.expectError(
        error.InvalidSeed,
        derive_nostr_secret_key_from_seed(seed_bytes[0..32], short_seed[0..], 0),
    );
    try std.testing.expectError(
        error.BufferTooSmall,
        derive_nostr_secret_key_from_seed(short_output[0..], seed_bytes[0..], 0),
    );
}

fn expect_seed_hex(
    mnemonic: []const u8,
    passphrase: []const u8,
    expected_hex: []const u8,
) !void {
    var seed: [limits.nip06_seed_bytes]u8 = undefined;

    const actual = try mnemonic_to_seed(seed[0..], mnemonic, passphrase);
    try std.testing.expectEqualStrings(expected_hex, &std.fmt.bytesToHex(seed, .lower));
    try std.testing.expectEqual(@as(usize, limits.nip06_seed_bytes), actual.len);
}

fn expect_secret_key_hex(
    mnemonic: []const u8,
    account: u32,
    expected_hex: []const u8,
) !void {
    var secret: [limits.nip06_secret_key_bytes]u8 = undefined;

    const actual = try derive_nostr_secret_key(secret[0..], mnemonic, null, account);
    try std.testing.expectEqualStrings(expected_hex, &std.fmt.bytesToHex(secret, .lower));
    try std.testing.expectEqual(@as(usize, limits.nip06_secret_key_bytes), actual.len);
}
