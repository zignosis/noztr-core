const std = @import("std");
const noztr = @import("noztr");

test "NIP-27 example: extract inline nostr references from content" {
    var bech32_output: [128]u8 = undefined;
    var uri_output: [160]u8 = undefined;
    var scratch: [noztr.limits.nip19_tlv_scratch_bytes_max]u8 = undefined;
    var references: [1]noztr.nip27_references.ContentReference = undefined;
    const encoded = try noztr.nip19_bech32.nip19_encode(
        bech32_output[0..],
        .{ .note = [_]u8{0x27} ** 32 },
    );
    const content = try std.fmt.bufPrint(uri_output[0..], "see nostr:{s}", .{encoded});

    const count = try noztr.nip27_references.reference_extract(
        content,
        references[0..],
        scratch[0..],
    );

    try std.testing.expectEqual(@as(u16, 1), count);
    try std.testing.expect(references[0].reference.entity == .note);
}
