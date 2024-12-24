const std = @import("std");
const lsp = @import("lsp");

const Lsp = lsp.Lsp(void);

pub const std_options = .{
    .log_level = .debug,
    .logFn = lsp.log,
};

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const server_data = lsp.types.ServerData{
        .serverInfo = .{
            .name = "babel-ls",
            .version = "0.1.0",
        },
    };

    var server = Lsp.init(allocator, server_data);
    defer server.deinit();

    server.registerCompletionCallback(handleCompletion);

    return try server.start();
}

fn handleCompletion(arena: std.mem.Allocator, context: *Lsp.Context, position: lsp.types.Position) ?lsp.types.CompletionList {
    const idx = lsp.Document.posToIdx(context.document.text, position).?;
    std.debug.print("handleCompletion idx = {}", .{idx});
    if (idx == 1 or context.document.text[idx - 2] == '\n') {
        std.debug.print("handleCompletion2", .{});
        return .{ .items = handlerCompletions(arena) };
    }
    return null;
}

fn handlerCompletions(allocator: std.mem.Allocator) []lsp.types.CompletionItem {
    var completions = std.ArrayList(lsp.types.CompletionItem).init(allocator);
    completions.append(.{
        .label = "handleOpenDoc",
        .insertText = "fn ${1:handleOpenDoc}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context) void {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleCloseDoc",
        .insertText = "fn ${1:handleCloseDoc}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context) void {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleChangeDoc",
        .insertText = "fn ${1:handleChangeDoc}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context, ${4:changes}: []lsp.types.ChangeEvent) void {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleSaveDoc",
        .insertText = "fn ${1:handleSaveDoc}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context) void {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleHover",
        .insertText = "fn ${1:handleHover}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context, ${4:position}: lsp.types.Position) ?[]const u8 {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleCodeAction",
        .insertText = "fn ${1:handleCodeAction}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context, ${4:range}: lsp.types.Range) ?[]const lsp.types.Response.CodeAction.Result {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleGoToDeclaration",
        .insertText = "fn ${1:handleGoToDeclaration}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context, ${4:position}: lsp.types.Position) ?lsp.types.Location {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleGotoDefinition",
        .insertText = "fn ${1:handleGotoDefinition}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context, ${4:position}: lsp.types.Position) ?lsp.types.Location {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleGoToTypeDefinition",
        .insertText = "fn ${1:handleGoToTypeDefinition}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context, ${4:position}: lsp.types.Position) ?lsp.types.Location {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleGoToImplementation",
        .insertText = "fn ${1:handleGoToImplementation}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context, ${4:position}: lsp.types.Position) ?lsp.types.Location {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    completions.append(.{
        .label = "handleFindReferences",
        .insertText = "fn ${1:handleFindReferences}(${2:arena}: std.mem.Allocator, ${3:context}: *Lsp.Context, ${4:position}: lsp.types.Position) ?[]lsp.types.Location {$0}",
        .insertTextFormat = .Snippet,
        .kind = .Function,
    }) catch unreachable;
    return completions.items;
}
