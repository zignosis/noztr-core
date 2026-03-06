const std = @import("std");

pub fn build(builder: *std.Build) void {
    std.debug.assert(@sizeOf(u8) == 1);
    std.debug.assert(@sizeOf(u32) == 4);

    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const root_module = builder.createModule(.{
        .root_source_file = builder.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

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
