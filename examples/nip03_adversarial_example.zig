const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "adversarial NIP-03 example: malformed proof payload stays typed" {
    const event_id_hex = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", event_id_hex } },
        .{ .items = &.{ "k", "1" } },
    };
    const attestation_event = common.simple_event(
        noztr.nip03_opentimestamps.opentimestamps_kind,
        [_]u8{0x33} ** 32,
        "%%%not-base64%%%",
        tags[0..],
    );
    var decoded_proof: [128]u8 = undefined;

    try std.testing.expectError(
        error.InvalidBase64,
        noztr.nip03_opentimestamps.opentimestamps_extract(decoded_proof[0..], &attestation_event),
    );
}
