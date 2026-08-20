const std = @import("std");
const lsp = @import("lsp");

const Lsp = lsp.Lsp(.{
    .state_type = std.Io.File,
});

const builtin = @import("builtin");

pub const std_options = std.Options{
    .log_level = .debug,
    .logFn = lsp.log,
};

pub fn main(init: std.process.Init) !u8 {
    const server_info = lsp.types.ServerInfo{
        .name = "tester",
        .version = "0.1.0",
    };

    var out_buffer: [1024]u8 = undefined;
    var in_buffer: [1024]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(std.Options.debug_io, &in_buffer);
    var stdout = std.Io.File.stdout().writer(std.Options.debug_io, &out_buffer);

    var server = Lsp.init(init.gpa, init.io, &stdin.interface, &stdout.interface, server_info);
    defer server.deinit();

    return try server.start(setup);
}

fn setup(p: Lsp.SetupParameters) void {
    p.server.registerCallback(.{ .@"textDocument/didOpen" = handleOpenDoc });
    p.server.registerCallback(.{ .@"textDocument/didChange" = handleChangeDoc });
    p.server.registerCallback(.{ .@"textDocument/didSave" = handleSaveDoc });
    p.server.registerCallback(.{ .@"textDocument/didClose" = handleCloseDoc });
    p.server.registerCallback(.{ .@"textDocument/hover" = handleHover });
    p.server.registerCallback(.{ .@"textDocument/codeAction" = handleCodeAction });

    p.server.registerCallback(.{ .@"textDocument/declaration" = handleGoToDeclaration });
    p.server.registerCallback(.{ .@"textDocument/definition" = handleGotoDefinition });
    p.server.registerCallback(.{ .@"textDocument/typeDefinition" = handleGoToTypeDefinition });
    p.server.registerCallback(.{ .@"textDocument/implementation" = handleGoToImplementation });
    p.server.registerCallback(.{ .@"textDocument/references" = handleFindReferences });
    p.server.registerCallback(.{ .@"textDocument/formatting" = handleFormat });
}

fn handleOpenDoc(p: Lsp.OpenDocumentParameters) void {
    const io = p.context.server.io;
    const file = std.Io.Dir.cwd().createFile(io, "output.txt", .{ .truncate = true }) catch unreachable;
    p.context.state = file;
    _ = p.context.state.?.writeStreamingAll(io, "Opened document\n") catch unreachable;
}
fn handleCloseDoc(p: Lsp.CloseDocumentParameters) void {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Closed document\n") catch unreachable;
    p.context.state.?.close(io);
}
fn handleChangeDoc(p: Lsp.ChangeDocumentParameters) void {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Changed document\n") catch unreachable;
}
fn handleSaveDoc(p: Lsp.SaveDocumentParameters) void {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Saved document\n") catch unreachable;
}
fn handleHover(p: Lsp.HoverParameters) Lsp.HoverReturn {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Hover\n") catch unreachable;
    return null;
}
fn handleCodeAction(p: Lsp.CodeActionParameters) ?[]const lsp.types.Response.CodeAction.Result {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Code action\n") catch unreachable;
    return null;
}
fn handleGoToDeclaration(p: Lsp.GoToDeclarationParameters) ?lsp.types.Location {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Go to declaration\n") catch unreachable;
    return null;
}
fn handleGotoDefinition(p: Lsp.GoToDefinitionParameters) ?lsp.types.Location {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Go to definition\n") catch unreachable;
    return null;
}
fn handleGoToTypeDefinition(p: Lsp.GoToTypeDefinitionParameters) ?lsp.types.Location {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Go to type definition\n") catch unreachable;
    return null;
}
fn handleGoToImplementation(p: Lsp.GoToImplementationParameters) ?lsp.types.Location {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Go to implementation\n") catch unreachable;
    return null;
}
fn handleFindReferences(p: Lsp.FindReferencesParameters) ?[]lsp.types.Location {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Find references\n") catch unreachable;
    return null;
}
fn handleFormat(p: Lsp.FormattingParameters) Lsp.FormattingReturn {
    const io = p.context.server.io;
    _ = p.context.state.?.writeStreamingAll(io, "Formatting\n") catch unreachable;
    return null;
}

test "Run nvim" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tester_path = try std.Io.Dir.cwd().realPathFileAlloc(io, "zig-out/bin/test", allocator);
    defer allocator.free(tester_path);

    const nvim_config = try std.fmt.allocPrint(allocator,
        \\ vim.lsp.set_log_level("TRACE")
        \\ vim.lsp.config.tester = {{
        \\     cmd = {{"{s}"}},
        \\     filetypes = {{"text"}},
        \\ }}
        \\ vim.lsp.enable("tester")
    , .{tester_path});
    defer allocator.free(nvim_config);
    tmp_dir.dir.writeFile(io, .{ .sub_path = "nvim_config.lua", .data = nvim_config }) catch unreachable;

    const commands =
        \\vim.cmd(":norm itext")
        \\vim.lsp.buf.hover()
        \\vim.cmd(":norm itext")
        \\vim.lsp.buf.code_action()
        \\vim.lsp.buf.format()
        \\vim.lsp.buf.definition()
        \\vim.lsp.buf.declaration()
        \\vim.lsp.buf.type_definition()
        \\vim.lsp.buf.implementation()
        \\vim.lsp.buf.references()
        \\vim.cmd(":wq")
    ;
    tmp_dir.dir.writeFile(io, .{ .sub_path = "commands.lua", .data = commands }) catch unreachable;

    const argv = [_][]const u8{
        "timeout",
        "-k",
        "5",
        "20",
        "nvim",
        "--headless",
        "-u",
        "nvim_config.lua",
        "test.txt",
        "-c",
        // Wait for the client to attach before commands.lua starts
        "lua vim.wait(5000, function() return #vim.lsp.get_clients({ bufnr = 0 }) > 0 end, 100)",
        "-l",
        "commands.lua",
    };
    var nvim_handle = try std.process.spawn(io, .{
        .argv = &argv,
        .cwd = .{ .dir = tmp_dir.dir },
        .stdout = .ignore,
        .stderr = .ignore,
    });
    const term = try nvim_handle.wait(io);

    switch (term) {
        .exited => |code| try std.testing.expectEqual(0, code),
        else => {
            std.debug.print("nvim did not exit normally: {}\n", .{term});
            return error.NvimError;
        },
    }

    const expected =
        \\Opened document
        \\Changed document
        \\Hover
        \\Changed document
        \\Code action
        \\Formatting
        \\Go to definition
        \\Go to declaration
        \\Go to type definition
        \\Go to implementation
        \\Find references
        \\Saved document
        \\
    ;
    const actual = try tmp_dir.dir.readFileAlloc(io, "output.txt", allocator, std.Io.Limit.unlimited);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
