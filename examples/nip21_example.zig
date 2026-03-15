const std = @import("std");
const noztr = @import("noztr");

test "NIP-21 example: parse strict nostr URIs on top of NIP-19" {
    var bech32_output: [128]u8 = undefined;
    var scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    const encoded = try noztr.nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{ .npub = [_]u8{0x22} ** 32 },
    );
    var uri_buffer: [160]u8 = undefined;
    const uri = try std.fmt.bufPrint(uri_buffer[0..], "nostr:{s}", .{encoded});

    const reference = try noztr.nip21_uri.nip21_parse(uri, scratch[0..]);

    try std.testing.expect(reference.entity == .npub);
    try std.testing.expectEqualStrings(encoded, reference.identifier);
}
