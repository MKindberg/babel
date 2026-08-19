const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the server
    const exe = b.addExecutable(.{
        .name = "server_name",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add the dependency towards babel
    const babel = b.dependency("babel", .{ .target = target, .optimize = optimize });

    // Allow the server to import the lsp module from babel
    const lsp = babel.module("lsp");
    exe.root_module.addImport("lsp", lsp);

    b.installArtifact(exe);
}
