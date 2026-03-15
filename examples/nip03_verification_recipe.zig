const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

const ots_header_magic = [_]u8{
    0x00, 0x4f, 0x70, 0x65, 0x6e, 0x54, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70,
    0x73, 0x00, 0x00, 0x50, 0x72, 0x6f, 0x6f, 0x66, 0x00, 0xbf, 0x89, 0xe2, 0xe8, 0x84,
    0xe8, 0x92, 0x94,
};
const ots_bitcoin_tag = [_]u8{ 0x05, 0x88, 0x96, 0x0d, 0x73, 0xd7, 0x19, 0x01 };

test "recipe: local opentimestamps verification stays inside kernel helpers" {
    var target = common.simple_event(1, [_]u8{0x03} ** 32, "hello", &.{});
    try common.finalize_event_id(&target);
    const event_id_hex = std.fmt.bytesToHex(target.id, .lower);
    var proof_bytes: [96]u8 = undefined;
    const proof = build_local_bitcoin_proof(proof_bytes[0..], &target.id);
    var proof_b64: [256]u8 = undefined;
    const encoded = std.base64.standard.Encoder.encode(proof_b64[0..], proof);
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "e", event_id_hex[0..] } },
        .{ .items = &.{ "k", "1" } },
    };
    const attestation_event = common.simple_event(1040, [_]u8{0x33} ** 32, encoded, tags[0..]);
    var decoded_proof: [128]u8 = undefined;

    const attestation = try noztr.nip03_opentimestamps.opentimestamps_extract(
        decoded_proof[0..],
        &attestation_event,
    );
    try noztr.nip03_opentimestamps.opentimestamps_validate_target_reference(
        &attestation,
        &target,
    );
    try noztr.nip03_opentimestamps.opentimestamps_validate_local_proof(
        &attestation,
        decoded_proof[0..attestation.proof_len],
    );
    try std.testing.expectEqual(@as(u32, 1), attestation.target_kind);
}

fn build_local_bitcoin_proof(output: []u8, digest: *const [32]u8) []const u8 {
    std.debug.assert(output.len >= ots_header_magic.len + 44);
    std.debug.assert(@intFromPtr(digest) != 0);

    var index: usize = 0;
    @memcpy(output[index .. index + ots_header_magic.len], ots_header_magic[0..]);
    index += ots_header_magic.len;
    output[index] = 0x01;
    output[index + 1] = 0x08;
    index += 2;
    @memcpy(output[index .. index + digest.len], digest[0..]);
    index += digest.len;
    output[index] = 0x00;
    index += 1;
    @memcpy(output[index .. index + ots_bitcoin_tag.len], ots_bitcoin_tag[0..]);
    index += ots_bitcoin_tag.len;
    output[index] = 0x01;
    output[index + 1] = 0x2a;
    return output[0 .. index + 2];
}
