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
    add_lint_steps(builder);
    const imported_input_fuzz_step = add_imported_input_fuzz_step(
        builder,
        target,
        optimize,
        root_module,
    );
    const empirical_benchmark_step = add_empirical_benchmark_step(builder, target, optimize, root_module);
    const rc_stress_step = add_rc_stress_throughput_step(builder, target, optimize, root_module);
    const release_artifacts_step = add_release_artifact_steps(builder, static_library);
    add_release_check_step(
        builder,
        test_step,
        imported_input_fuzz_step,
        empirical_benchmark_step,
        rc_stress_step,
        release_artifacts_step,
    );
}

fn add_lint_steps(builder: *std.Build) void {
    std.debug.assert(@sizeOf(std.Build.Step) > 0);
    std.debug.assert(!@inComptime());

    const fmt_check = builder.addSystemCommand(&.{
        "zig",
        "fmt",
        "--check",
        "build.zig",
        "build.zig.zon",
        "src",
        "examples",
        "tools",
    });
    const fmt_check_step = builder.step(
        "fmt-check",
        "Check Zig and ZON formatting with zig fmt --check",
    );
    fmt_check_step.dependOn(&fmt_check.step);

    const lint_step = builder.step(
        "lint",
        "Run the minimal noztr lint gate",
    );
    lint_step.dependOn(&fmt_check.step);
}

fn add_release_check_step(
    builder: *std.Build,
    test_step: *std.Build.Step,
    imported_input_fuzz_step: *std.Build.Step,
    empirical_benchmark_step: *std.Build.Step,
    rc_stress_step: *std.Build.Step,
    release_artifacts_step: *std.Build.Step,
) void {
    std.debug.assert(@sizeOf(std.Build.Step) > 0);

    const release_check_step = builder.step(
        "release-check",
        "Run the longer-budget release confidence gate",
    );
    release_check_step.dependOn(builder.getInstallStep());
    release_check_step.dependOn(test_step);
    release_check_step.dependOn(imported_input_fuzz_step);
    release_check_step.dependOn(empirical_benchmark_step);
    release_check_step.dependOn(rc_stress_step);
    release_check_step.dependOn(release_artifacts_step);
}

fn add_release_artifact_steps(
    builder: *std.Build,
    static_library: *std.Build.Step.Compile,
) *std.Build.Step {
    std.debug.assert(@sizeOf(std.Build.Step.Compile) > 0);

    const artifact_dir = builder.pathJoin(&.{ builder.install_path, "release" });
    const library_path = builder.pathJoin(&.{ builder.install_path, "lib", "libnoztr.a" });

    const release_artifacts = builder.addSystemCommand(&.{
        "python3",
        "tools/release/generate_release_artifacts.py",
        "--zon",
        "build.zig.zon",
        "--artifact",
        library_path,
        "--out-dir",
        artifact_dir,
    });
    release_artifacts.step.dependOn(builder.getInstallStep());
    release_artifacts.step.dependOn(&static_library.step);

    const release_artifacts_step = builder.step(
        "release-artifacts",
        "Generate release checksum and manifest outputs",
    );
    release_artifacts_step.dependOn(&release_artifacts.step);
    return release_artifacts_step;
}

fn add_imported_input_fuzz_step(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_module: *std.Build.Module,
) *std.Build.Step {
    std.debug.assert(@sizeOf(std.Build.Step) > 0);
    std.debug.assert(@sizeOf(std.Build.Module) > 0);

    const fuzz_module = builder.createModule(.{
        .root_source_file = builder.path("tools/fuzz/imported_input_properties.zig"),
        .target = target,
        .optimize = optimize,
    });
    fuzz_module.addImport("noztr", root_module);
    const fuzz_tests = builder.addTest(.{
        .root_module = fuzz_module,
    });
    const run_fuzz_tests = builder.addRunArtifact(fuzz_tests);
    const fuzz_step = builder.step(
        "imported-input-fuzz",
        "Run deterministic hostile imported-input property checks",
    );
    fuzz_step.dependOn(&run_fuzz_tests.step);
    return fuzz_step;
}

fn add_empirical_benchmark_step(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_module: *std.Build.Module,
) *std.Build.Step {
    std.debug.assert(@sizeOf(std.Build.Step) > 0);
    std.debug.assert(@sizeOf(std.Build.Module) > 0);

    const benchmark_module = builder.createModule(.{
        .root_source_file = builder.path("tools/benchmarks/exhaustive_audit_empirical.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark_module.addImport("noztr", root_module);

    const benchmark_exe = builder.addExecutable(.{
        .name = "empirical-benchmark",
        .root_module = benchmark_module,
    });
    const run_benchmark = builder.addRunArtifact(benchmark_exe);
    const benchmark_step = builder.step(
        "empirical-benchmark",
        "Run the empirical benchmark supplement harness",
    );
    benchmark_step.dependOn(&run_benchmark.step);
    return benchmark_step;
}

fn add_rc_stress_throughput_step(
    builder: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_module: *std.Build.Module,
) *std.Build.Step {
    std.debug.assert(@sizeOf(std.Build.Step) > 0);
    std.debug.assert(@sizeOf(std.Build.Module) > 0);

    const benchmark_module = builder.createModule(.{
        .root_source_file = builder.path("tools/benchmarks/rc_stress_throughput.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark_module.addImport("noztr", root_module);

    const benchmark_exe = builder.addExecutable(.{
        .name = "rc-stress-throughput",
        .root_module = benchmark_module,
    });
    const run_benchmark = builder.addRunArtifact(benchmark_exe);
    const run_benchmark_soak = builder.addRunArtifact(benchmark_exe);
    const run_benchmark_csv = builder.addRunArtifact(benchmark_exe);
    const run_benchmark_markdown = builder.addRunArtifact(benchmark_exe);
    run_benchmark_soak.addArg("--mode=soak");
    run_benchmark_csv.addArg("--format=csv");
    run_benchmark_markdown.addArg("--format=markdown");
    const benchmark_step = builder.step(
        "rc-stress-throughput",
        "Run the RC stress and throughput supplement harness",
    );
    const benchmark_soak_step = builder.step(
        "rc-stress-throughput-soak",
        "Run the RC stress and throughput supplement harness in soak mode",
    );
    const benchmark_csv_step = builder.step(
        "rc-stress-throughput-csv",
        "Run the RC stress and throughput supplement harness in CSV mode",
    );
    const benchmark_markdown_step = builder.step(
        "rc-stress-throughput-markdown",
        "Run the RC stress and throughput supplement harness in Markdown mode",
    );
    benchmark_step.dependOn(&run_benchmark.step);
    benchmark_soak_step.dependOn(&run_benchmark_soak.step);
    benchmark_csv_step.dependOn(&run_benchmark_csv.step);
    benchmark_markdown_step.dependOn(&run_benchmark_markdown.step);
    return benchmark_step;
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

    const secp_module = builder.createModule(.{
        .root_source_file = builder.path("src/internal/secp256k1.zig"),
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
