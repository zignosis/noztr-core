const std = @import("std");

pub fn build(builder: *std.Build) void {
    std.debug.assert(@sizeOf(std.Build) > 0);
    std.debug.assert(!@inComptime());

    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});
    const noztr_dependency = builder.dependency("noztr", .{});
    const noztr_module = noztr_dependency.module("noztr");
    const recipe_module = builder.createModule(.{
        .root_source_file = builder.path("src/recipes.zig"),
        .target = target,
        .optimize = optimize,
    });
    recipe_module.addImport("noztr", noztr_module);

    const recipe_tests = builder.addTest(.{
        .root_module = recipe_module,
    });
    const run_recipe_tests = builder.addRunArtifact(recipe_tests);
    const test_step = builder.step("test", "Run noztr downstream recipe tests");
    test_step.dependOn(&run_recipe_tests.step);
}
