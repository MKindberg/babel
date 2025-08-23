const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_steps = .{
        .@"test" = b.step("test", "Run nvim test"),
    };

    const modules = createModules(b, .{ .target = target, .optimize = optimize });

    buildTest(b, build_steps.@"test", modules.lsp, .{ .target = target, .optimize = optimize });
}

fn createModules(
    b: *std.Build,
    options: struct {
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
    },
) struct {
    lsp: *std.Build.Module,
    plugins: *std.Build.Module,
} {
    const lsp = b.addModule("lsp", .{
        .root_source_file = b.path("src/lsp.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    const plugins = b.addModule("plugins", .{
        .root_source_file = b.path("integrations/plugins.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });

    return .{
        .lsp = lsp,
        .plugins = plugins,
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
