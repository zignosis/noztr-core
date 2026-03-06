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

var verify_signature_call_count: u32 = 0;

pub fn reset_counters() void {
    std.debug.assert(verify_signature_call_count >= 0);
    std.debug.assert(!@inComptime());

    verify_signature_call_count = 0;
    std.debug.assert(verify_signature_call_count == 0);
}

pub fn get_verify_signature_call_count() u32 {
    std.debug.assert(verify_signature_call_count >= 0);
    std.debug.assert(!@inComptime());

    return verify_signature_call_count;
}

pub fn verify_schnorr_signature(
    public_key: *const [32]u8,
    message_digest: *const [32]u8,
    signature: *const [64]u8,
) BackendVerifyError!void {
    std.debug.assert(public_key[0] <= 255);
    std.debug.assert(signature[0] <= 255);

    verify_signature_call_count += 1;

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

fn map_public_key_error(verify_error: secp256k1.Error) BackendVerifyError {
    std.debug.assert(@intFromError(verify_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (verify_error) {
        error.InvalidPublicKey => error.InvalidPublicKey,
        else => error.BackendUnavailable,
    };
}

fn map_signature_error(verify_error: secp256k1.Error) BackendVerifyError {
    std.debug.assert(@intFromError(verify_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (verify_error) {
        error.InvalidSignature => error.InvalidSignature,
        else => error.BackendUnavailable,
    };
}

fn map_sign_error(sign_error: secp256k1.Error) BackendSignError {
    std.debug.assert(@intFromError(sign_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (sign_error) {
        error.InvalidSecretKey => error.InvalidSecretKey,
        else => error.BackendUnavailable,
    };
}

const VerifyClass = enum {
    valid,
    invalid_public_key,
    invalid_signature,
    backend_unavailable,
};

const Bip340Vector = struct {
    label: []const u8,
    public_key_hex: []const u8,
    message_hex: []const u8,
    signature_hex: []const u8,
    expected_class: VerifyClass,
};

const bip340_vectors = [_]Bip340Vector{
    .{
        .label = "official-0-valid",
        .public_key_hex = "F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9",
        .message_hex = "0000000000000000000000000000000000000000000000000000000000000000",
        .signature_hex = "E907831F80848D1069A5371B402410364BDF1C5F8307B0084C55F1CE2DCA8215" ++
            "25F66A4A85EA8B71E482A74F382D2CE5EBEEE8FDB2172F477DF4900D310536C0",
        .expected_class = .valid,
    },
    .{
        .label = "official-1-valid",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "6896BD60EEAE296DB48A229FF71DFE071BDE413E6D43F917DC8DCF8C78DE3341" ++
            "8906D11AC976ABCCB20B091292BFF4EA897EFCB639EA871CFA95F6DE339E4B0A",
        .expected_class = .valid,
    },
    .{
        .label = "official-3-valid",
        .public_key_hex = "25D1DFF95105F5253C4022F628A996AD3A0D95FBF21D468A1B33F8C160D8F517",
        .message_hex = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        .signature_hex = "7EB0509757E246F19449885651611CB965ECC1A187DD51B64FDA1EDC9637D5EC" ++
            "97582B9CB13DB3933705B32BA982AF5AF25FD78881EBB32771FC5922EFC66EA3",
        .expected_class = .valid,
    },
    .{
        .label = "official-5-invalid-pubkey",
        .public_key_hex = "EEFDEA4CDB677750A420FEE807EACF21EB9898AE79B9768766E4FAA04A2D4A34",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E177769" ++
            "69E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B",
        .expected_class = .invalid_public_key,
    },
    .{
        .label = "official-6-invalid-signature",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "FFF97BD5755EEEA420453A14355235D382F6472F8568A18B2F057A1460297556" ++
            "3CC27944640AC607CD107AE10923D9EF7A73C643E166BE5EBEAFA34B1AC553E2",
        .expected_class = .invalid_signature,
    },
    .{
        .label = "official-8-invalid-signature",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E177769" ++
            "961764B3AA9B2FFCB6EF947B6887A226E8D7C93E00C5ED0C1834FF0D0C2E6DA6",
        .expected_class = .invalid_signature,
    },
    .{
        .label = "official-12-invalid-signature",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F" ++
            "69E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B",
        .expected_class = .invalid_signature,
    },
    .{
        .label = "official-14-invalid-pubkey",
        .public_key_hex = "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC30",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E177769" ++
            "69E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B",
        .expected_class = .invalid_public_key,
    },
};

fn decode_hex_fixed(comptime bytes_len: usize, hex_input: []const u8) ![bytes_len]u8 {
    std.debug.assert(bytes_len > 0);
    std.debug.assert(hex_input.len == bytes_len * 2);

    var bytes: [bytes_len]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, hex_input);

    std.debug.assert(bytes.len == bytes_len);
    std.debug.assert(bytes[0] <= 255);
    return bytes;
}

fn classify_boundary(
    public_key: *const [32]u8,
    message_digest: *const [32]u8,
    signature: *const [64]u8,
) VerifyClass {
    std.debug.assert(public_key.len == 32);
    std.debug.assert(signature.len == 64);

    verify_schnorr_signature(public_key, message_digest, signature) catch |verify_error| {
        return switch (verify_error) {
            error.InvalidPublicKey => .invalid_public_key,
            error.InvalidSignature => .invalid_signature,
            error.BackendUnavailable => .backend_unavailable,
        };
    };

    std.debug.assert(message_digest.len == 32);
    std.debug.assert(signature.len != 0);
    return .valid;
}

fn classify_direct(
    public_key: *const [32]u8,
    message_digest: *const [32]u8,
    signature: *const [64]u8,
) VerifyClass {
    std.debug.assert(public_key.len == 32);
    std.debug.assert(message_digest.len == 32);

    const parsed_public_key = secp256k1.XOnlyPublicKey.from_slice(public_key) catch |verify_error| {
        return switch (verify_error) {
            error.InvalidPublicKey => .invalid_public_key,
            else => .backend_unavailable,
        };
    };
    secp256k1.verify_schnorr(&parsed_public_key, message_digest, signature) catch |verify_error| {
        return switch (verify_error) {
            error.InvalidSignature => .invalid_signature,
            else => .backend_unavailable,
        };
    };

    std.debug.assert(signature.len == 64);
    std.debug.assert(signature.len != 0);
    return .valid;
}

fn run_bip340_vector(vector: Bip340Vector) !void {
    std.debug.assert(vector.label.len > 0);
    std.debug.assert(vector.message_hex.len == 64);

    const public_key = try decode_hex_fixed(32, vector.public_key_hex);
    const message_digest = try decode_hex_fixed(32, vector.message_hex);
    const signature = try decode_hex_fixed(64, vector.signature_hex);

    const boundary_class = classify_boundary(&public_key, &message_digest, &signature);
    const direct_class = classify_direct(&public_key, &message_digest, &signature);

    try std.testing.expectEqual(direct_class, boundary_class);
    try std.testing.expectEqual(vector.expected_class, boundary_class);
}

test "bip340 vectors classify with boundary-direct parity" {
    reset_counters();
    for (bip340_vectors) |vector| {
        try run_bip340_vector(vector);
    }

    const expected_calls: u32 = bip340_vectors.len;
    try std.testing.expect(get_verify_signature_call_count() == expected_calls);
    try std.testing.expect(get_verify_signature_call_count() != 0);
}

test "mutation from valid bip340 vector is rejected and matches direct classifier" {
    const valid_vector = Bip340Vector{
        .label = "official-1-valid-base",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "6896BD60EEAE296DB48A229FF71DFE071BDE413E6D43F917DC8DCF8C78DE3341" ++
            "8906D11AC976ABCCB20B091292BFF4EA897EFCB639EA871CFA95F6DE339E4B0A",
        .expected_class = .valid,
    };

    const public_key = try decode_hex_fixed(32, valid_vector.public_key_hex);
    var message_digest = try decode_hex_fixed(32, valid_vector.message_hex);
    const signature = try decode_hex_fixed(64, valid_vector.signature_hex);

    message_digest[31] ^= 1;

    const boundary_class = classify_boundary(&public_key, &message_digest, &signature);
    const direct_class = classify_direct(&public_key, &message_digest, &signature);

    try std.testing.expectEqual(direct_class, boundary_class);
    try std.testing.expectEqual(VerifyClass.invalid_signature, boundary_class);
    try std.testing.expect(boundary_class != .invalid_public_key);
}

test "sign path yields deterministic signature verified by boundary" {
    const secret_key = try decode_hex_fixed(
        32,
        "0000000000000000000000000000000000000000000000000000000000000003",
    );
    const public_key = try decode_hex_fixed(
        32,
        "F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9",
    );
    const message_digest = try decode_hex_fixed(
        32,
        "0000000000000000000000000000000000000000000000000000000000000000",
    );

    var signature_a: [64]u8 = undefined;
    var signature_b: [64]u8 = undefined;

    try sign_schnorr_signature(&secret_key, &message_digest, &signature_a);
    try sign_schnorr_signature(&secret_key, &message_digest, &signature_b);

    try std.testing.expectEqualSlices(u8, &signature_a, &signature_b);
    try std.testing.expect(signature_a[0] <= 255);
    try verify_schnorr_signature(&public_key, &message_digest, &signature_a);
}

test "sign path maps invalid secret key to typed boundary error" {
    var invalid_secret_key: [32]u8 = [_]u8{0} ** 32;
    const message_digest = try decode_hex_fixed(
        32,
        "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
    );
    var signature: [64]u8 = undefined;

    const sign_result = sign_schnorr_signature(
        &invalid_secret_key,
        &message_digest,
        &signature,
    );
    try std.testing.expectError(error.InvalidSecretKey, sign_result);
    try std.testing.expect(invalid_secret_key[0] == 0);
}
