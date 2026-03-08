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
        .label = "official-2-valid",
        .public_key_hex = "DD308AFEC5777E13121FA72B9CC1B7CC0139715309B086C960E18FD969774EB8",
        .message_hex = "7E2D58D8B3BCDF1ABADEC7829054F90DDA9805AAB56C77333024B9D0A508B75C",
        .signature_hex = "5831AAEED7B44BB74E5EAB94BA9D4294C49BCF2A60728D8B4C200F50DD313C1B" ++
            "AB745879A5AD954A72C45A91C3A51D3C7ADEA98D82F8481E0E1E03674A6F3FB7",
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
        .label = "official-4-valid",
        .public_key_hex = "D69C3509BB99E412E68B0FE8544E72837DFA30746D8BE2AA65975F29D22DC7B9",
        .message_hex = "4DF3C3F68FCC83B27E9D42C90431A72499F17875C81A599B566C9889B9696703",
        .signature_hex = "00000000000000000000003B78CE563F89A0ED9414F5AA28AD0D96D6795F9C63" ++
            "76AFB1548AF603B3EB45C9F8207DEE1060CB71C04E80F593060B07D28308D7F4",
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
        .label = "official-7-invalid-signature",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "1FA62E331EDBC21C394792D2AB1100A7B432B013DF3F6FF4F99FCB33E0E1515F" ++
            "28890B3EDB6E7189B630448B515CE4F8622A954CFE545735AAEA5134FCCDB2BD",
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
        .label = "official-9-invalid-signature",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "0000000000000000000000000000000000000000000000000000000000000000" ++
            "123DDA8328AF9C23A94C1FEECFD123BA4FB73476F0D594DCB65C6425BD186051",
        .expected_class = .invalid_signature,
    },
    .{
        .label = "official-10-invalid-signature",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "0000000000000000000000000000000000000000000000000000000000000001" ++
            "7615FBAF5AE28864013C099742DEADB4DBA87F11AC6754F93780D5A1837CF197",
        .expected_class = .invalid_signature,
    },
    .{
        .label = "official-11-invalid-signature",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "4A298DACAE57395A15D0795DDBFD1DCB564DA82B0F269BC70A74F8220429BA1D" ++
            "69E89B4C5564D00349106B8497785DD7D1D713A8AE82B32FA79D5F7FC407D39B",
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
        .label = "official-13-invalid-signature",
        .public_key_hex = "DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659",
        .message_hex = "243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
        .signature_hex = "6CFF5C3BA86C69EA4B7376F31A9BCB4F74C1976089B2D9963DA2E5543E177769" ++
            "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141",
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

test "deterministic sign path yields stable signature verified by boundary" {
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

    try sign_schnorr_signature_deterministic(&secret_key, &message_digest, &signature_a);
    try sign_schnorr_signature_deterministic(&secret_key, &message_digest, &signature_b);

    try std.testing.expectEqualSlices(u8, &signature_a, &signature_b);
    try std.testing.expect(signature_a[0] <= 255);
    try verify_schnorr_signature(&public_key, &message_digest, &signature_a);
}

test "hardened sign path yields verifiable schnorr signature" {
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

    var signature: [64]u8 = undefined;

    try sign_schnorr_signature(&secret_key, &message_digest, &signature);
    try std.testing.expect(signature[0] <= 255);
    try std.testing.expect(signature.len == 64);
    try verify_schnorr_signature(&public_key, &message_digest, &signature);
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
