const std = @import("std");

const ServerInfo = @import("../plugins.zig").ServerInfo;

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    var languages = std.array_list.Managed(u8).init(allocator);
    defer languages.deinit();
    for (info.languages) |l| {
        try languages.writer().print("\"{s}\", ", .{l});
    }
    var langs = std.array_list.Managed(u8).init(allocator);
    defer langs.deinit();
    for (info.languages) |l| {
        try langs.writer().print("\"{s}\", ", .{l});
    }
    const content = try std.fmt.allocPrint(allocator, plugin_lua, .{
        .name = info.name,
        .display = info.displayName orelse info.name,
        .languages = langs.items,
    });
    defer allocator.free(content);
    const filename = try std.fmt.allocPrint(allocator, "lua/{s}/init.lua", .{info.name});
    std.posix.mkdir("lua", std.fs.Dir.default_mode) catch |e| if (e != error.PathAlreadyExists ) return e;
    std.posix.mkdir(std.fs.path.dirname(filename).?, std.fs.Dir.default_mode) catch |e| if (e != error.PathAlreadyExists ) return e;
    defer allocator.free(filename);
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(content);
}

const plugin_lua =
    \\local M = {{}}
    \\M.setup = function()
    \\    local autocmd = vim.api.nvim_create_autocmd
    \\    autocmd("FileType", {{
    \\        pattern = {{ {[languages]s}}},
    \\        callback = function()
    \\            local client = vim.lsp.start({{
    \\                name = '{[display]s}',
    \\                cmd = {{ '{[name]s}' }},
    \\            }})
    \\            if not client then
    \\                vim.notify("Failed to start {[display]s}")
    \\            else
    \\                vim.lsp.buf_attach_client(0, client)
    \\            end
    \\        end
    \\    }})
    \\end
    \\return M
    \\
;
