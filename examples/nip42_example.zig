const std = @import("std");
const noztr = @import("noztr");

test "NIP-42 example: auth state stores the active challenge deterministically" {
    var state = noztr.nip42_auth.AuthState{};
    noztr.nip42_auth.auth_state_init(&state);
    try noztr.nip42_auth.auth_state_set_challenge(&state, "relay-challenge");

    try std.testing.expectEqual(@as(u8, 15), state.challenge_len);
    try std.testing.expect(!noztr.nip42_auth.auth_state_is_pubkey_authenticated(
        &state,
        &([_]u8{0x11} ** 32),
    ));
}
