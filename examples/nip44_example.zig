const std = @import("std");
const noztr = @import("noztr");

test "NIP-44 example: encrypt and decrypt with fixed conversation key and nonce" {
    const conversation_key = [_]u8{
        0xc4, 0x1c, 0x77, 0x53, 0x56, 0xfd, 0x92, 0xea,
        0xdc, 0x63, 0xff, 0x5a, 0x0d, 0xc1, 0xda, 0x21,
        0x1b, 0x26, 0x8c, 0xbe, 0xa2, 0x23, 0x16, 0x76,
        0x70, 0x95, 0xb2, 0x87, 0x1e, 0xa1, 0x41, 0x2d,
    };
    const nonce = [_]u8{0} ** 31 ++ [_]u8{1};
    var encoded: [noztr.limits.nip44_payload_base64_max_bytes]u8 = undefined;
    const payload = try noztr.nip44.nip44_encrypt_with_nonce_to_base64(
        encoded[0..],
        &conversation_key,
        "a",
        &nonce,
    );
    var plaintext: [noztr.limits.nip44_plaintext_max_bytes]u8 = undefined;
    const decrypted = try noztr.nip44.nip44_decrypt_from_base64(
        plaintext[0..],
        &conversation_key,
        payload,
    );

    try std.testing.expectEqualStrings("a", decrypted);
    try std.testing.expect(payload.len > 0);
}
