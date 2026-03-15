const std = @import("std");

pub fn build(builder: *std.Build) void {
    std.debug.assert(@sizeOf(std.Build) > 0);
    std.debug.assert(!@inComptime());

    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});
    const noztr_dependency = builder.dependency("noztr", .{});
    const noztr_module = noztr_dependency.module("noztr");
    const example_module = builder.createModule(.{
        .root_source_file = builder.path("examples.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_module.addImport("noztr", noztr_module);

    const example_tests = builder.addTest(.{
        .root_module = example_module,
    });
    const run_example_tests = builder.addRunArtifact(example_tests);
    const test_step = builder.step("test", "Run noztr downstream examples");
    test_step.dependOn(&run_example_tests.step);
}
