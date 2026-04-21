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

    var out_buffer: [512]u8 = undefined;
    var in_buffer: [512]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(std.Options.debug_io, &in_buffer);
    var stdout = std.Io.File.stdout().writer(std.Options.debug_io, &out_buffer);

    var server = Lsp.init(init.gpa, init.io, &stdin.interface, &stdout.interface, server_info);
    defer server.deinit();

    return try server.start(setup);
}

fn setup(p: Lsp.SetupParameters) void {
    p.server.registerDocOpenCallback(handleOpenDoc);
    p.server.registerDocChangeCallback(handleChangeDoc);
    p.server.registerDocSaveCallback(handleSaveDoc);
    p.server.registerDocCloseCallback(handleCloseDoc);
    p.server.registerHoverCallback(handleHover);
    p.server.registerCodeActionCallback(handleCodeAction);

    p.server.registerGoToDeclarationCallback(handleGoToDeclaration);
    p.server.registerGoToDefinitionCallback(handleGotoDefinition);
    p.server.registerGoToTypeDefinitionCallback(handleGoToTypeDefinition);
    p.server.registerGoToImplementationCallback(handleGoToImplementation);
    p.server.registerFindReferencesCallback(handleFindReferences);
    p.server.registerFormattingCallback(handleFormat);
}

fn handleOpenDoc(p: Lsp.OpenDocumentParameters) void {
    const file = std.Io.Dir.cwd().createFile(p.io, "output.txt", .{ .truncate = true }) catch unreachable;
    p.context.state = file;
    _ = p.context.state.?.writeStreamingAll(p.io, "Opened document\n") catch unreachable;
}
fn handleCloseDoc(p: Lsp.CloseDocumentParameters) void {
    _ = p.context.state.?.writeStreamingAll(p.io, "Closed document\n") catch unreachable;
    p.context.state.?.close(p.io);
}
fn handleChangeDoc(p: Lsp.ChangeDocumentParameters) void {
    _ = p.context.state.?.writeStreamingAll(p.io, "Changed document\n") catch unreachable;
}
fn handleSaveDoc(p: Lsp.SaveDocumentParameters) void {
    _ = p.context.state.?.writeStreamingAll(p.io, "Saved document\n") catch unreachable;
}
fn handleHover(p: Lsp.HoverParameters) ?[]const u8 {
    _ = p.context.state.?.writeStreamingAll(p.io, "Hover\n") catch unreachable;
    return null;
}
fn handleCodeAction(p: Lsp.CodeActionParameters) ?[]const lsp.types.Response.CodeAction.Result {
    _ = p.context.state.?.writeStreamingAll(p.io, "Code action\n") catch unreachable;
    return null;
}
fn handleGoToDeclaration(p: Lsp.GoToDeclarationParameters) ?lsp.types.Location {
    _ = p.context.state.?.writeStreamingAll(p.io, "Go to declaration\n") catch unreachable;
    return null;
}
fn handleGotoDefinition(p: Lsp.GoToDefinitionParameters) ?lsp.types.Location {
    _ = p.context.state.?.writeStreamingAll(p.io, "Go to definition\n") catch unreachable;
    return null;
}
fn handleGoToTypeDefinition(p: Lsp.GoToTypeDefinitionParameters) ?lsp.types.Location {
    _ = p.context.state.?.writeStreamingAll(p.io, "Go to type definition\n") catch unreachable;
    return null;
}
fn handleGoToImplementation(p: Lsp.GoToImplementationParameters) ?lsp.types.Location {
    _ = p.context.state.?.writeStreamingAll(p.io, "Go to implementation\n") catch unreachable;
    return null;
}
fn handleFindReferences(p: Lsp.FindReferencesParameters) ?[]lsp.types.Location {
    _ = p.context.state.?.writeStreamingAll(p.io, "Find references\n") catch unreachable;
    return null;
}
fn handleFormat(p: Lsp.FormattingParameters) Lsp.FormattingReturn {
    _ = p.context.state.?.writeStreamingAll(p.io, "Formatting\n") catch unreachable;
    return null;
}

test "Run nvim" {
    const io = std.testing.io;
    const nvim_config =
        \\ vim.lsp.set_log_level("TRACE")
        \\ vim.lsp.config.tester = {
        \\     cmd = {"zig-out/bin/test"},
        \\     filetypes = {"text"},
        \\ }
        \\ vim.lsp.enable("tester")
    ;
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "nvim_config.lua", .data = nvim_config }) catch unreachable;
    defer std.Io.Dir.cwd().deleteFile(io, "nvim_config.lua") catch {};

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
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "commands.lua", .data = commands }) catch unreachable;
    defer std.Io.Dir.cwd().deleteFile(io, "commands.lua") catch {};
    const argv = [_][]const u8{
        "nvim",
        "--headless",
        "-u",
        "nvim_config.lua",
        "test.txt",
        "-c",
        "sleep 1", // ls doesn't start properly without this sleep
        "-l",
        "commands.lua",
    };
    var nvim_handle = try std.process.spawn(io, .{ .argv = &argv, .stdout = .ignore, .stderr = .ignore });

    const term = try nvim_handle.wait(io);
    defer std.Io.Dir.cwd().deleteFile(io, "output.txt") catch {};
    defer std.Io.Dir.cwd().deleteFile(io, "test.txt") catch {};

    try std.testing.expectEqual(term.exited, 0);

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
    const actual = try std.Io.Dir.cwd().readFileAlloc(io, "output.txt", std.testing.allocator, std.Io.Limit.unlimited);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
