const std = @import("std");
const noztr = @import("noztr");

test "NIP-19 example: encode and decode npub identifiers" {
    var output: [128]u8 = undefined;
    var scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;

    const encoded = try noztr.nip19_bech32.nip19_encode(
        output[0..],
        .{ .npub = [_]u8{0x11} ** 32 },
    );
    const decoded = try noztr.nip19_bech32.nip19_decode(encoded, scratch[0..]);

    try std.testing.expect(decoded == .npub);
    try std.testing.expectEqualStrings("npub", encoded[0..4]);
}
