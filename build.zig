const std = @import("std");

const BuildOptions = struct { target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode };

pub fn build(b: *std.Build) void {
    const build_options = BuildOptions{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };

    const build_steps = .{
        .@"test" = b.step("test", "Run nvim test"),
        .unittest = b.step("unittest", "Run unit tests"),
        .coverage = b.step("coverage", "Run unit tests with kcov coverage"),
    };

    const modules = createModules(b, build_options);

    addOptions(b, modules.lsp, build_options);
    buildTest(b, build_steps.@"test", modules.lsp, build_options);
    buildUnitTest(b, build_steps.unittest, build_options);
    buildCovTest(b, build_steps.coverage, build_options);
}

fn createModules(b: *std.Build, options: BuildOptions) struct {
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

fn addOptions(b: *std.Build, lsp: *std.Build.Module, build_options: BuildOptions) void {
    const use_tree_sitter = b.option(bool, "use_tree_sitter", "Add support for tree-sitter via TreeSitterDocument") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "use_tree_sitter", use_tree_sitter);
    lsp.addImport("build_options", options.createModule());

    if (use_tree_sitter) {
        if (b.lazyDependency("tree_sitter", build_options)) |dep| {
            lsp.addImport("tree-sitter", dep.module("tree_sitter"));
        }
    }
}

fn buildTest(
    b: *std.Build,
    step: *std.Build.Step,
    lsp: *std.Build.Module,
    options: BuildOptions,
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
    const install_tester = b.addInstallArtifact(tester, .{});

    // Run tests
    const nvim_test = b.addTest(.{ .root_module = root_module });
    nvim_test.root_module.addImport("lsp", lsp);
    const run_test = b.addRunArtifact(nvim_test);
    run_test.step.dependOn(&install_tester.step);
    run_test.has_side_effects = true;

    step.dependOn(&run_test.step);
}

fn buildUnitTest(b: *std.Build, step: *std.Build.Step, options: BuildOptions) void {
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

fn buildCovTest(b: *std.Build, step: *std.Build.Step, options: BuildOptions) void {
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

    cov_test.setExecCmd(&[_]?[]const u8{ "kcov", "--clean", "--include-pattern=src", "cov", null });
    const run_cov_test = b.addRunArtifact(cov_test);
    run_cov_test.has_side_effects = true;
    step.dependOn(&run_cov_test.step);
}
