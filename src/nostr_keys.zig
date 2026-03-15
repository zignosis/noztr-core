const std = @import("std");
const nip01_event = @import("nip01_event.zig");
const secp256k1_backend = @import("crypto/secp256k1_backend.zig");

/// Typed failures for bounded Nostr key and signing helpers.
pub const NostrKeysError = error{
    InvalidSecretKey,
    InvalidEvent,
    BackendUnavailable,
};

/// Derive the Nostr x-only public key for one secret key.
pub fn nostr_derive_public_key(secret_key: *const [32]u8) NostrKeysError![32]u8 {
    std.debug.assert(@intFromPtr(secret_key) != 0);
    std.debug.assert(secret_key[0] <= 255);

    var public_key: [32]u8 = undefined;
    secp256k1_backend.derive_xonly_public_key(secret_key, &public_key) catch |derive_error| {
        return switch (derive_error) {
            error.InvalidSecretKey => error.InvalidSecretKey,
            error.BackendUnavailable => error.BackendUnavailable,
        };
    };
    return public_key;
}

/// Compute the canonical event id and sign the event with one secret key.
pub fn nostr_sign_event(
    secret_key: *const [32]u8,
    event: *nip01_event.Event,
) NostrKeysError!void {
    std.debug.assert(@intFromPtr(secret_key) != 0);
    std.debug.assert(@intFromPtr(event) != 0);

    const derived_public_key = try nostr_derive_public_key(secret_key);
    if (!std.mem.eql(u8, &derived_public_key, &event.pubkey)) {
        return error.InvalidEvent;
    }

    event.id = nip01_event.event_compute_id_checked(event) catch return error.InvalidEvent;
    secp256k1_backend.sign_schnorr_signature(secret_key, &event.id, &event.sig) catch |sign_error| {
        return switch (sign_error) {
            error.InvalidSecretKey => error.InvalidSecretKey,
            error.BackendUnavailable => error.BackendUnavailable,
        };
    };
}

test "nostr key helpers derive public key and sign matching event" {
    const secret_key = [_]u8{0x11} ** 32;
    const public_key = try nostr_derive_public_key(&secret_key);
    var event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = public_key,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "hello",
        .tags = &.{},
    };

    try nostr_sign_event(&secret_key, &event);
    try nip01_event.event_verify(&event);
}

test "nostr key helpers reject invalid secret and mismatched event pubkey" {
    const invalid_secret = [_]u8{0} ** 32;
    const valid_secret = [_]u8{0x11} ** 32;
    var event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0x22} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 1,
        .content = "hello",
        .tags = &.{},
    };

    try std.testing.expectError(error.InvalidSecretKey, nostr_derive_public_key(&invalid_secret));
    try std.testing.expectError(error.InvalidEvent, nostr_sign_event(&valid_secret, &event));
}
