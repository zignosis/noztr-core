const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-03 example: extract bounded OpenTimestamps attestation metadata" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } },
        .{ .items = &.{ "k", "1" } },
    };
    const event = common.simple_event(1040, [_]u8{0x03} ** 32, "cHJvb2Y=", tags[0..]);
    var proof: [32]u8 = undefined;

    const attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(proof[0..], &event);

    try std.testing.expectEqual(@as(u32, 5), attestation.proof_len);
    try std.testing.expectEqual(@as(u32, 1), attestation.target_kind);
}
