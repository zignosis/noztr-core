const std = @import("std");
const noztr = @import("noztr");

test "NIP-39 example: build expected proof text" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .github,
        .identity = "alice",
        .proof = "gist-id",
    };
    const pubkey = [_]u8{0x39} ** 32;
    var output: [256]u8 = undefined;

    const proof_text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        output[0..],
        &claim,
        &pubkey,
    );

    try std.testing.expect(std.mem.indexOf(u8, proof_text, "Verifying that I control") != null);
    try std.testing.expect(std.mem.indexOf(u8, proof_text, "npub") != null);
}
