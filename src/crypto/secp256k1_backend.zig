const std = @import("std");
const secp256k1 = @import("secp256k1");

/// Typed boundary errors for the secp256k1 verification path.
pub const BackendVerifyError = error{
    InvalidPublicKey,
    InvalidSignature,
    BackendUnavailable,
};

/// Typed boundary errors for the secp256k1 signing path.
pub const BackendSignError = error{
    InvalidSecretKey,
    BackendUnavailable,
};

/// Typed boundary errors for public-key derivation from a secret key.
pub const BackendDerivePublicKeyError = error{
    InvalidSecretKey,
    BackendUnavailable,
};

/// Typed boundary errors for the secp256k1 ECDH shared-secret path.
pub const BackendSharedSecretError = error{
    InvalidPrivateKey,
    InvalidPublicKey,
    BackendUnavailable,
};

var verify_signature_call_count = std.atomic.Value(u32).init(0);

pub fn reset_counters() void {
    const current_count = verify_signature_call_count.load(.seq_cst);
    std.debug.assert(current_count >= 0);
    std.debug.assert(!@inComptime());

    verify_signature_call_count.store(0, .seq_cst);
    const reset_count = verify_signature_call_count.load(.seq_cst);
    std.debug.assert(reset_count == 0);
}

pub fn get_verify_signature_call_count() u32 {
    const current_count = verify_signature_call_count.load(.seq_cst);
    std.debug.assert(current_count >= 0);
    std.debug.assert(!@inComptime());

    return current_count;
}

pub fn verify_schnorr_signature(
    public_key: *const [32]u8,
    message_digest: *const [32]u8,
    signature: *const [64]u8,
) BackendVerifyError!void {
    std.debug.assert(public_key[0] <= 255);
    std.debug.assert(signature[0] <= 255);

    _ = verify_signature_call_count.fetchAdd(1, .seq_cst);

    const parsed_public_key = secp256k1.XOnlyPublicKey.from_slice(public_key) catch |verify_error| {
        return map_public_key_error(verify_error);
    };
    secp256k1.verify_schnorr(&parsed_public_key, message_digest, signature) catch |verify_error| {
        return map_signature_error(verify_error);
    };
}

pub fn sign_schnorr_signature(
    secret_key: *const [32]u8,
    message_digest: *const [32]u8,
    out_signature: *[64]u8,
) BackendSignError!void {
    std.debug.assert(secret_key[0] <= 255);
    std.debug.assert(message_digest[0] <= 255);

    secp256k1.sign_schnorr(secret_key, message_digest, out_signature) catch |sign_error| {
        return map_sign_error(sign_error);
    };
}

pub fn sign_schnorr_signature_deterministic(
    secret_key: *const [32]u8,
    message_digest: *const [32]u8,
    out_signature: *[64]u8,
) BackendSignError!void {
    std.debug.assert(secret_key[0] <= 255);
    std.debug.assert(message_digest[0] <= 255);

    secp256k1.sign_schnorr_deterministic(
        secret_key,
        message_digest,
        out_signature,
    ) catch |sign_error| {
        return map_sign_error(sign_error);
    };
}

pub fn derive_xonly_public_key(
    secret_key: *const [32]u8,
    out_public_key: *[32]u8,
) BackendDerivePublicKeyError!void {
    std.debug.assert(secret_key[0] <= 255);
    std.debug.assert(@intFromPtr(out_public_key) != 0);

    secp256k1.derive_xonly_public_key(secret_key, out_public_key) catch |derive_error| {
        return map_derive_public_key_error(derive_error);
    };
}

pub fn derive_shared_secret_x(
    private_key: *const [32]u8,
    public_key: *const [32]u8,
    out_shared_secret: *[32]u8,
) BackendSharedSecretError!void {
    std.debug.assert(private_key[0] <= 255);
    std.debug.assert(public_key[0] <= 255);

    secp256k1.derive_shared_secret_x(
        private_key,
        public_key,
        out_shared_secret,
    ) catch |shared_secret_error| {
        return map_shared_secret_error(shared_secret_error);
    };
}

fn map_public_key_error(verify_error: secp256k1.Error) BackendVerifyError {
    std.debug.assert(@intFromError(verify_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (verify_error) {
        error.InvalidPublicKey => error.InvalidPublicKey,
        error.InvalidSignature => error.BackendUnavailable,
        error.InvalidSecretKey => error.BackendUnavailable,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

fn map_signature_error(verify_error: secp256k1.Error) BackendVerifyError {
    std.debug.assert(@intFromError(verify_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (verify_error) {
        error.InvalidSignature => error.InvalidSignature,
        error.InvalidPublicKey => error.BackendUnavailable,
        error.InvalidSecretKey => error.BackendUnavailable,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

fn map_sign_error(sign_error: secp256k1.Error) BackendSignError {
    std.debug.assert(@intFromError(sign_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (sign_error) {
        error.InvalidSecretKey => error.InvalidSecretKey,
        error.InvalidPublicKey => error.BackendUnavailable,
        error.InvalidSignature => error.BackendUnavailable,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

fn map_shared_secret_error(shared_secret_error: secp256k1.Error) BackendSharedSecretError {
    std.debug.assert(@intFromError(shared_secret_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (shared_secret_error) {
        error.InvalidSecretKey => error.InvalidPrivateKey,
        error.InvalidPublicKey => error.InvalidPublicKey,
        error.InvalidSignature => error.BackendUnavailable,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

fn map_derive_public_key_error(
    derive_error: secp256k1.Error,
) BackendDerivePublicKeyError {
    std.debug.assert(@intFromError(derive_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (derive_error) {
        error.InvalidSecretKey => error.InvalidSecretKey,
        error.InvalidPublicKey => error.BackendUnavailable,
        error.InvalidSignature => error.BackendUnavailable,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

test {
    _ = @import("secp256k1_backend_test.zig");
}
