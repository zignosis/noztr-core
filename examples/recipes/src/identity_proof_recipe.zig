const std = @import("std");
const noztr = @import("noztr");

test "recipe: identity proof helpers stay pure and deterministic" {
    const claim = noztr.nip39_external_identities.IdentityClaim{
        .provider = .github,
        .identity = "semisol",
        .proof = "9721ce4ee4fceb91c9711ca2a6c9a5ab",
    };
    const pubkey = [_]u8{0x22} ** 32;
    var url_buffer: [256]u8 = undefined;
    var text_buffer: [256]u8 = undefined;

    // noztr owns pure proof-shape glue. Provider fetch and verification stays in nzdk.
    const url = try noztr.nip39_external_identities.identity_claim_build_proof_url(
        url_buffer[0..],
        &claim,
    );
    const text = try noztr.nip39_external_identities.identity_claim_build_expected_text(
        text_buffer[0..],
        &claim,
        &pubkey,
    );

    try std.testing.expectEqualStrings(
        "https://gist.github.com/semisol/9721ce4ee4fceb91c9711ca2a6c9a5ab",
        url,
    );
    try std.testing.expect(std.mem.indexOf(u8, text, "npub1") != null);
}
