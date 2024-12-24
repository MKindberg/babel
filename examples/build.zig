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

    // Create a build target for generating minimal editor plugins
    const plugin_generator = b.addExecutable(.{
        .name = "generate_plugins",
        .root_source_file = b.path("plugin_generator.zig"),
        .target = b.host,
    });
    plugin_generator.root_module.addImport("lsp_plugins", babel.module("plugins"));
    b.step("gen_plugins", "Generate plugins").dependOn(&b.addRunArtifact(plugin_generator).step);
}
