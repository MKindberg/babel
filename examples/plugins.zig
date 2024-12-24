const std = @import("std");
const lsp_plugins = @import("lsp_plugins");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Create a struct with information about the server used in the generated files
    // A lot of the information is optional depending on what is being generated.
    const info = lsp_plugins.ServerInfo{
        .name = "server_name",
        .description = "Description",
        .publisher = "mkindberg",
        .languages = &[_][]const u8{"zig"},
        .repository = "https://github.com/mkindberg/babel",
        .source_id = "pkg:github/mkindberg/babel",
        .version = "0.1.0",
        .license = "MIT",
    };

    // The plugins can be generated all at once
    try lsp_plugins.generate(allocator, info);

    // or separately. The plugins will be placed in a new dir called
    // editors with subdirectories for each editor.
    try lsp_plugins.generateVSCode(allocator, info);
    try lsp_plugins.generateNvim(allocator, info);
    try lsp_plugins.generateMasonRegistry(allocator, info);
}
