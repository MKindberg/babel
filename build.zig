const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_steps = .{
        .@"test" = b.step("test", "Run nvim test"),
        .unittest = b.step("unittest", "Run unit tests"),
        .coverage = b.step("coverage", "Run unit tests with kcov coverage"),
    };

    const modules = createModules(b, .{ .target = target, .optimize = optimize });

    buildTest(b, build_steps.@"test", modules.lsp, .{ .target = target, .optimize = optimize });
    buildUnitTest(b, build_steps.unittest, .{ .target = target, .optimize = optimize });
    buildCovTest(b, build_steps.coverage, .{ .target = target, .optimize = optimize });
}

fn createModules(
    b: *std.Build,
    options: struct {
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    },
) struct {
    lsp: *std.Build.Module,
} {
    const lsp = b.addModule("lsp", .{
        .root_source_file = b.path("src/lsp.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });

    return .{
        .lsp = lsp,
    };
}

fn buildTest(
    b: *std.Build,
    step: *std.Build.Step,
    lsp: *std.Build.Module,
    options: struct {
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    },
) void {
    const root_module = b.createModule(.{
        .root_source_file = b.path("test/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    // Create test server
    const tester = b.addExecutable(.{
        .name = "test",
        .root_module = root_module,
    });
    tester.root_module.addImport("lsp", lsp);
    b.installArtifact(tester);

    // Run tests
    const nvim_test = b.addTest(.{ .root_module = root_module });
    nvim_test.root_module.addImport("lsp", lsp);
    const run_test = b.addRunArtifact(nvim_test);
    run_test.step.dependOn(&tester.step);

    step.dependOn(&run_test.step);
}

fn buildUnitTest(
    b: *std.Build,
    step: *std.Build.Step,
    options: struct {
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    },
) void {
    const unit_test = b.addTest(.{
        .name = "test-unit",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = options.target,
            .optimize = options.optimize,
        }),
        .filters = b.args orelse &.{},
    });
    const run_unit_test = b.addRunArtifact(unit_test);
    step.dependOn(&run_unit_test.step);
}

fn buildCovTest(
    b: *std.Build,
    step: *std.Build.Step,
    options: struct {
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    },
) void {
    const cov_test = b.addTest(.{
        .name = "test-unit",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = options.target,
            .optimize = options.optimize,
        }),
        .filters = b.args orelse &.{},
        .use_llvm = true,
    });

    cov_test.setExecCmd(&[_]?[]const u8{ "kcov","--clean", "--include-pattern=src", "cov", null });
    const run_cov_test = b.addRunArtifact(cov_test);
    run_cov_test.has_side_effects = true;
    step.dependOn(&run_cov_test.step);
}
