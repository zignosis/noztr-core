const std = @import("std");

pub fn build(builder: *std.Build) void {
    std.debug.assert(@sizeOf(u8) == 1);
    std.debug.assert(@sizeOf(u32) == 4);

    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});
    const enable_i6_extensions = builder.option(
        bool,
        "enable_i6_extensions",
        "Enable I6 optional extensions (NIP-45, NIP-50, NIP-77)",
    ) orelse true;
    const secp256k1_module = create_secp256k1_module(builder, target, optimize);
    const libwally_module = create_libwally_module(builder, target, optimize);
    const root_module = create_root_module(
        builder,
        target,
        optimize,
        secp256k1_module,
        libwally_module,
        enable_i6_extensions,
    );

    const root_module_core_only = create_root_module(
        builder,
        target,
        optimize,
        secp256k1_module,
        libwally_module,
        false,
    );
    _ = add_public_root_module(
        builder,
        target,
        optimize,
        secp256k1_module,
        libwally_module,
        enable_i6_extensions,
    );

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
    const unit_tests_core_only = builder.addTest(.{
        .root_module = root_module_core_only,
    });
    const run_unit_tests_core_only = builder.addRunArtifact(unit_tests_core_only);

    const test_step = builder.step("test", "Run noztr unit tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_unit_tests_core_only.step);
    add_example_test_step(builder, test_step, "examples");
}

fn create_root_module(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    secp256k1_module: *std.Build.Module,
    libwally_module: *std.Build.Module,
    enable_i6_extensions: bool,
) *std.Build.Module {
    std.debug.assert(@sizeOf(std.Build.Module) > 0);
    std.debug.assert(@sizeOf(bool) == 1);

    const build_options = builder.addOptions();
    build_options.addOption(bool, "enable_i6_extensions", enable_i6_extensions);

    const root_module = builder.createModule(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.addImport("secp256k1", secp256k1_module);
    root_module.addImport("libwally", libwally_module);
    root_module.addOptions("build_options", build_options);
    return root_module;
}

fn add_public_root_module(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    secp256k1_module: *std.Build.Module,
    libwally_module: *std.Build.Module,
    enable_i6_extensions: bool,
) *std.Build.Module {
    std.debug.assert(@sizeOf(std.Build.Module) > 0);
    std.debug.assert(@sizeOf(bool) == 1);

    const build_options = builder.addOptions();
    build_options.addOption(bool, "enable_i6_extensions", enable_i6_extensions);

    const root_module = builder.addModule("noztr", .{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.addImport("secp256k1", secp256k1_module);
    root_module.addImport("libwally", libwally_module);
    root_module.addOptions("build_options", build_options);
    return root_module;
}

fn add_example_test_step(
    builder: *std.Build,
    test_step: *std.Build.Step,
    example_dir: []const u8,
) void {
    std.debug.assert(@sizeOf(std.Build.Step) > 0);
    std.debug.assert(!@inComptime());

    const example_tests = builder.addSystemCommand(&.{
        "zig",
        "build",
        "test",
        "--summary",
        "all",
    });
    example_tests.setName(example_dir);
    example_tests.setCwd(builder.path(example_dir));
    test_step.dependOn(&example_tests.step);
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
            "-DENABLE_MODULE_SCHNORRSIG=1",
            "-DENABLE_MODULE_EXTRAKEYS=1",
            "-DENABLE_MODULE_ECDH=1",
            "-DENABLE_MODULE_RECOVERY=1",
        },
    });
}

fn create_libwally_module(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    std.debug.assert(@sizeOf(std.Build.Module) > 0);
    std.debug.assert(@sizeOf(std.builtin.OptimizeMode) > 0);

    const write_files = builder.addWriteFiles();
    const shim_file = write_files.add("libwally_shim.zig", libwally_shim_source);
    _ = write_files.add("config.h", libwally_config_source);

    const libwally_module = builder.createModule(.{
        .root_source_file = shim_file,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    configure_libwally_c_bindings(builder, write_files, libwally_module);
    return libwally_module;
}

fn configure_libwally_c_bindings(
    builder: *std.Build,
    write_files: *std.Build.Step.WriteFile,
    module: *std.Build.Module,
) void {
    std.debug.assert(@sizeOf(std.Build.Module) > 0);
    std.debug.assert(!@inComptime());

    const libwally_dependency = builder.dependency("libwally-core", .{});
    const libwally_root = libwally_dependency.path("");
    const secp_dependency = builder.dependency("secp256k1", .{});

    module.addCMacro("WALLY_CORE_BUILD", "1");
    module.addCMacro("BUILD_MINIMAL", "1");
    module.addCMacro("BUILD_STANDARD_SECP", "1");
    module.addCMacro("WALLY_ABI_NO_ELEMENTS", "1");
    module.addIncludePath(write_files.getDirectory());
    module.addIncludePath(libwally_root);
    module.addIncludePath(libwally_dependency.path("include"));
    module.addIncludePath(libwally_dependency.path("src"));
    module.addIncludePath(libwally_dependency.path("src/ccan"));
    module.addIncludePath(secp_dependency.path("include"));

    const source_files = &.{
        "src/internal.c",
        "src/base_58.c",
        "src/bip32.c",
        "src/bip39.c",
        "src/mnemonic.c",
        "src/wordlist.c",
        "src/pbkdf2.c",
        "src/hmac.c",
        "src/sign.c",
        "src/ccan/ccan/crypto/sha256/sha256.c",
        "src/ccan/ccan/crypto/sha512/sha512.c",
        "src/ccan/ccan/crypto/ripemd160/ripemd160.c",
    };
    module.addCSourceFiles(.{
        .root = libwally_root,
        .files = source_files,
        .flags = &.{},
    });
}

const secp256k1_shim_source =
    \\const std = @import("std");
    \\const secp = @cImport({
    \\    @cInclude("secp256k1.h");
    \\    @cInclude("secp256k1_schnorrsig.h");
    \\    @cInclude("secp256k1_extrakeys.h");
    \\    @cInclude("secp256k1_ecdh.h");
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
    \\    var randomization_seed: [32]u8 = undefined;
    \\    std.crypto.random.bytes(&randomization_seed);
    \\    defer wipe_randomization_seed(&randomization_seed);
    \\    const randomize_result = secp.secp256k1_context_randomize(
    \\        created,
    \\        @ptrCast(&randomization_seed),
    \\    );
    \\    if (randomize_result != 1) {
    \\        secp.secp256k1_context_destroy(created);
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
    \\fn wipe_keypair(keypair: *secp.secp256k1_keypair) void {
    \\    std.debug.assert(!@inComptime());
    \\    std.debug.assert(@sizeOf(secp.secp256k1_keypair) > 0);
    \\
    \\    std.crypto.secureZero(u8, std.mem.asBytes(keypair));
    \\}
    \\
    \\fn wipe_aux_random(aux_random: *[32]u8) void {
    \\    std.debug.assert(!@inComptime());
    \\    std.debug.assert(aux_random.len == 32);
    \\
    \\    std.crypto.secureZero(u8, aux_random[0..]);
    \\}
    \\
    \\fn wipe_randomization_seed(randomization_seed: *[32]u8) void {
    \\    std.debug.assert(!@inComptime());
    \\    std.debug.assert(randomization_seed.len == 32);
    \\
    \\    std.crypto.secureZero(u8, randomization_seed[0..]);
    \\}
    \\
    \\fn sign_schnorr_with_aux(
    \\    secret_key: *const [32]u8,
    \\    message_digest: *const [32]u8,
    \\    out_signature: *[64]u8,
    \\    aux_random: ?*const [32]u8,
    \\) Error!void {
    \\    std.debug.assert(secret_key[0] <= 255);
    \\    std.debug.assert(message_digest[0] <= 255);
    \\
    \\    const context = try get_signing_context();
    \\    std.debug.assert(out_signature.len == 64);
    \\
    \\    var keypair: secp.secp256k1_keypair = undefined;
    \\    defer wipe_keypair(&keypair);
    \\
    \\    const create_result = secp.secp256k1_keypair_create(
    \\        context,
    \\        &keypair,
    \\        secret_key,
    \\    );
    \\    if (create_result != 1) {
    \\        return error.InvalidSecretKey;
    \\    }
    \\
    \\    var aux_random_ptr: [*c]const u8 = null;
    \\    if (aux_random) |aux_random_value| {
    \\        std.debug.assert(aux_random_value.len == 32);
    \\        aux_random_ptr = @ptrCast(aux_random_value);
    \\    }
    \\
    \\    const sign_result = secp.secp256k1_schnorrsig_sign32(
    \\        context,
    \\        out_signature,
    \\        message_digest,
    \\        &keypair,
    \\        aux_random_ptr,
    \\    );
    \\    if (sign_result != 1) {
    \\        return error.BackendUnavailable;
    \\    }
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
    \\    var aux_random: [32]u8 = undefined;
    \\    std.crypto.random.bytes(&aux_random);
    \\    defer wipe_aux_random(&aux_random);
    \\
    \\    return sign_schnorr_with_aux(secret_key, message_digest, out_signature, &aux_random);
    \\}
    \\
    \\pub fn sign_schnorr_deterministic(
    \\    secret_key: *const [32]u8,
    \\    message_digest: *const [32]u8,
    \\    out_signature: *[64]u8,
    \\) Error!void {
    \\    std.debug.assert(secret_key[0] <= 255);
    \\    std.debug.assert(message_digest[0] <= 255);
    \\
    \\    return sign_schnorr_with_aux(secret_key, message_digest, out_signature, null);
    \\}
    \\
    \\fn ecdh_hash_x_coordinate(
    \\    output: [*c]u8,
    \\    x32: [*c]const u8,
    \\    y32: [*c]const u8,
    \\    data: ?*anyopaque,
    \\) callconv(.c) c_int {
    \\    _ = y32;
    \\    _ = data;
    \\    std.debug.assert(output != null);
    \\    std.debug.assert(x32 != null);
    \\
    \\    @memcpy(output[0..32], x32[0..32]);
    \\    return 1;
    \\}
    \\
    \\pub fn derive_shared_secret_x(
    \\    secret_key: *const [32]u8,
    \\    public_key_xonly: *const [32]u8,
    \\    out_shared_secret: *[32]u8,
    \\) Error!void {
    \\    std.debug.assert(secret_key[0] <= 255);
    \\    std.debug.assert(public_key_xonly[0] <= 255);
    \\
    \\    var compressed_public_key: [33]u8 = undefined;
    \\    compressed_public_key[0] = 0x02;
    \\    @memcpy(compressed_public_key[1..33], public_key_xonly[0..32]);
    \\
    \\    var public_key: secp.secp256k1_pubkey = undefined;
    \\    const parse_result = secp.secp256k1_ec_pubkey_parse(
    \\        secp.secp256k1_context_no_precomp,
    \\        &public_key,
    \\        &compressed_public_key,
    \\        compressed_public_key.len,
    \\    );
    \\    if (parse_result != 1) {
    \\        return error.InvalidPublicKey;
    \\    }
    \\
    \\    const ecdh_result = secp.secp256k1_ecdh(
    \\        secp.secp256k1_context_no_precomp,
    \\        out_shared_secret,
    \\        &public_key,
    \\        secret_key,
    \\        ecdh_hash_x_coordinate,
    \\        null,
    \\    );
    \\    if (ecdh_result != 1) {
    \\        return error.InvalidSecretKey;
    \\    }
    \\}
;

const libwally_shim_source =
    \\pub const c = @cImport({
    \\    @cInclude("wally_core.h");
    \\    @cInclude("wally_bip39.h");
    \\    @cInclude("wally_bip32.h");
    \\});
;

const libwally_config_source =
    \\#ifndef LIBWALLYCORE_CONFIG_H
    \\#define LIBWALLYCORE_CONFIG_H
    \\
    \\#include "ccan_config.h"
    \\
    \\#endif
;
