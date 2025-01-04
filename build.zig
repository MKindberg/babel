const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add modules
    const lsp = b.addModule("lsp", .{
        .root_source_file = b.path("src/lsp.zig"),
        .target = target,
        .optimize = optimize,
    });
    _ = b.addModule("plugins", .{
        .root_source_file = b.path("integrations/plugins.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create test server
    const tester = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("test/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    tester.root_module.addImport("lsp", lsp);
    b.installArtifact(tester);

    // Run tests
    const nvim_test = b.addTest(.{ .root_source_file = b.path("test/main.zig") });
    nvim_test.root_module.addImport("lsp", lsp);
    const run_test = b.addRunArtifact(nvim_test);
    run_test.step.dependOn(&tester.step);

    const test_step = b.step("test", "Run nvim test");
    test_step.dependOn(&run_test.step);

}
