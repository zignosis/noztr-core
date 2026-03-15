const std = @import("std");
const noztr = @import("noztr");

test "NIP-06 example: derive canonical nostr secret key" {
    const mnemonic =
        "install scatter logic circle pencil average fall shoe quantum disease suspect usage";
    var output: [32]u8 = undefined;

    try noztr.nip06_mnemonic.mnemonic_validate(mnemonic);
    const secret = try noztr.nip06_mnemonic.derive_nostr_secret_key(
        output[0..],
        mnemonic,
        null,
        0,
    );

    try std.testing.expectEqual(@as(usize, 32), secret.len);
    try std.testing.expect(secret[0] != 0);
}
