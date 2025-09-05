const std = @import("std");

pub fn build(b: *std.Build) void {
    // Build the server
    const exe = b.addExecutable(.{
        .name = "server_name",
        .root_source_file = b.path("src/main.zig"),
    });

    // Add the dependency towards babel
    const babel = b.dependency("babel", .{});

    // Allow the server to import the lsp module from babel
    const lsp = babel.module("lsp");
    exe.root_module.addImport("lsp", lsp);

    b.installArtifact(exe);
}
