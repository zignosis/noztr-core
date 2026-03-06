const std = @import("std");

pub fn build(builder: *std.Build) void {
    std.debug.assert(@sizeOf(u8) == 1);
    std.debug.assert(@sizeOf(u32) == 4);

    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});
    const secp256k1_module = create_secp256k1_module(builder, target, optimize);

    const root_module = builder.createModule(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.addImport("secp256k1", secp256k1_module);

    const static_library = builder.addLibrary(.{
        .linkage = .static,
        .name = "noztr",
        .root_module = root_module,
    });
    builder.installArtifact(static_library);

    const unit_tests = builder.addTest(.{
        .root_module = root_module,
    });
    const run_unit_tests = builder.addRunArtifact(unit_tests);

    const test_step = builder.step("test", "Run noztr unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

fn create_secp256k1_module(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    std.debug.assert(@sizeOf(std.Build.Module) > 0);
    std.debug.assert(@sizeOf(std.builtin.OptimizeMode) > 0);

    const write_files = builder.addWriteFiles();
    const shim_file = write_files.add("secp256k1_shim.zig", secp256k1_shim_source);

    const secp_module = builder.createModule(.{
        .root_source_file = shim_file,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    configure_secp_c_bindings(builder, secp_module);
    return secp_module;
}

fn configure_secp_c_bindings(builder: *std.Build, module: *std.Build.Module) void {
    std.debug.assert(@sizeOf(std.Build.Module) > 0);
    std.debug.assert(!@inComptime());

    const secp_dependency = builder.dependency("secp256k1", .{});
    const secp_root = secp_dependency.path("");

    module.addCMacro("USE_FIELD_10X26", "1");
    module.addCMacro("USE_SCALAR_8X32", "1");
    module.addCMacro("USE_ENDOMORPHISM", "1");
    module.addCMacro("USE_NUM_NONE", "1");
    module.addCMacro("USE_FIELD_INV_BUILTIN", "1");
    module.addCMacro("USE_SCALAR_INV_BUILTIN", "1");
    module.addIncludePath(secp_root);
    module.addIncludePath(secp_dependency.path("src"));
    module.addIncludePath(secp_dependency.path("include"));

    const secp_source_files = &.{
        "src/secp256k1.c",
        "src/precomputed_ecmult.c",
        "src/precomputed_ecmult_gen.c",
    };
    module.addCSourceFiles(.{
        .root = secp_root,
        .files = secp_source_files,
        .flags = &.{
            "-DENABLE_MODULE_RECOVERY=1",
            "-DENABLE_MODULE_SCHNORRSIG=1",
            "-DENABLE_MODULE_ECDH=1",
            "-DENABLE_MODULE_EXTRAKEYS=1",
        },
    });
}

const secp256k1_shim_source =
    \\const std = @import("std");
    \\const secp = @cImport({
    \\    @cInclude("secp256k1.h");
    \\    @cInclude("secp256k1_schnorrsig.h");
    \\    @cInclude("secp256k1_extrakeys.h");
    \\});
    \\
    \\pub const Error = error{
    \\    InvalidPublicKey,
    \\    InvalidSignature,
    \\    InvalidSecretKey,
    \\    BackendUnavailable,
    \\};
    \\
    \\fn init_signing_context() void {
    \\    std.debug.assert(!@inComptime());
    \\    std.debug.assert(signing_context_storage == null or signing_context_error == null);
    \\
    \\    const created = secp.secp256k1_context_create(secp.SECP256K1_CONTEXT_SIGN);
    \\    if (created == null) {
    \\        signing_context_error = error.BackendUnavailable;
    \\        return;
    \\    }
    \\
    \\    signing_context_storage = created;
    \\    std.debug.assert(signing_context_storage != null);
    \\}
    \\
    \\var signing_context_storage: ?*secp.secp256k1_context = null;
    \\var signing_context_error: ?Error = null;
    \\var signing_context_once = std.once(init_signing_context);
    \\
    \\fn get_signing_context() Error!*secp.secp256k1_context {
    \\    std.debug.assert(!@inComptime());
    \\    std.debug.assert(signing_context_error == null or signing_context_storage == null);
    \\
    \\    signing_context_once.call();
    \\    if (signing_context_error) |context_error| {
    \\        return context_error;
    \\    }
    \\
    \\    const context = signing_context_storage orelse return error.BackendUnavailable;
    \\    return context;
    \\}
    \\
    \\pub const XOnlyPublicKey = struct {
    \\    inner: secp.secp256k1_xonly_pubkey,
    \\
    \\    pub fn from_slice(public_key: *const [32]u8) Error!XOnlyPublicKey {
    \\        std.debug.assert(public_key[0] <= 255);
    \\        std.debug.assert(!@inComptime());
    \\
    \\        var parsed: secp.secp256k1_xonly_pubkey = undefined;
    \\        const result = secp.secp256k1_xonly_pubkey_parse(
    \\            secp.secp256k1_context_no_precomp,
    \\            &parsed,
    \\            public_key,
    \\        );
    \\        if (result == 1) {
    \\            return .{ .inner = parsed };
    \\        }
    \\
    \\        return error.InvalidPublicKey;
    \\    }
    \\};
    \\
    \\pub fn verify_schnorr(
    \\    public_key: *const XOnlyPublicKey,
    \\    message_digest: *const [32]u8,
    \\    signature: *const [64]u8,
    \\) Error!void {
    \\    std.debug.assert(message_digest[0] <= 255);
    \\    std.debug.assert(signature[0] <= 255);
    \\
    \\    const result = secp.secp256k1_schnorrsig_verify(
    \\        secp.secp256k1_context_no_precomp,
    \\        signature,
    \\        message_digest,
    \\        32,
    \\        &public_key.inner,
    \\    );
    \\    if (result == 1) {
    \\        return;
    \\    }
    \\
    \\    return error.InvalidSignature;
    \\}
    \\
    \\pub fn sign_schnorr(
    \\    secret_key: *const [32]u8,
    \\    message_digest: *const [32]u8,
    \\    out_signature: *[64]u8,
    \\) Error!void {
    \\    std.debug.assert(secret_key[0] <= 255);
    \\    std.debug.assert(message_digest[0] <= 255);
    \\
    \\    const context = try get_signing_context();
    \\    std.debug.assert(out_signature.len == 64);
    \\
    \\    var keypair: secp.secp256k1_keypair = undefined;
    \\    const create_result = secp.secp256k1_keypair_create(
    \\        context,
    \\        &keypair,
    \\        secret_key,
    \\    );
    \\    if (create_result != 1) {
    \\        return error.InvalidSecretKey;
    \\    }
    \\
    \\    const sign_result = secp.secp256k1_schnorrsig_sign32(
    \\        context,
    \\        out_signature,
    \\        message_digest,
    \\        &keypair,
    \\        null,
    \\    );
    \\    if (sign_result != 1) {
    \\        return error.BackendUnavailable;
    \\    }
    \\    return;
    \\}
;
