const std = @import("std");

const types = @import("types.zig");
const rpc = @import("rpc.zig");

const lsp = @import("lsp.zig");
const Lsp = lsp.Lsp;

fn queueMessage(writer: anytype, message: anytype) !void {
    const allocator = std.testing.allocator;
    const encoded = try rpc.encodeMessage(allocator, message);
    defer allocator.free(encoded);
    _ = try writer.write(encoded);
}

fn initializeServer(writer: anytype) !void {
    const initialize = types.Request.Initialize{ .id = @enumFromInt(0) };
    try queueMessage(writer, initialize);
    const initialized = types.Notification.Notification{ .method = "initialized" };
    try queueMessage(writer, initialized);
}

fn shutdownServer(writer: anytype) !void {
    const shutdown = types.Request.Shutdown{ .id = @enumFromInt(0) };
    try queueMessage(writer, shutdown);
    const exit = types.Notification.Notification{ .method = "exit" };
    try queueMessage(writer, exit);
}

fn openDoc(writer: anytype, uri: []const u8, text: []const u8) !void {
    const open_doc = types.Notification.DidOpenTextDocument{ .params = .{ .textDocument = .{ .uri = uri, .languageId = "txt", .version = 0, .text = text } } };
    try queueMessage(writer, open_doc);
}

fn closeDoc(writer: anytype, uri: []const u8) !void {
    const close_doc = types.Notification.DidCloseTextDocument{ .params = .{ .textDocument = .{ .uri = uri } } };
    try queueMessage(writer, close_doc);
}

fn changeDoc(writer: anytype, uri: []const u8, text: []const u8) !void {
    const changes = [_]types.ChangeEvent{.{ .text = text, .range = .{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } } }};
    const close_doc = types.Notification.DidChangeTextDocument{ .params = .{
        .textDocument = .{ .uri = uri, .version = 0 },
        .contentChanges = &changes,
    } };
    try queueMessage(writer, close_doc);
}

test "init-shutdown" {
    lsp.test_input_file = "test_input";
    defer lsp.test_input_file = null;
    lsp.test_output_file = "test_output";
    defer lsp.test_output_file = null;
    const file = try std.fs.cwd().createFile(lsp.test_input_file.?, .{});

    try initializeServer(file);

    const uri = "test.txt";
    try openDoc(file, uri, "Test document");
    try changeDoc(file, uri, "Added text");
    try closeDoc(file, uri);

    try shutdownServer(file);

    file.close();

    var server = Lsp(.{}).init(std.testing.allocator, .{ .name = "testing" });
    defer server.deinit();
    const res = try server.start();

    try std.fs.cwd().deleteFile(lsp.test_input_file.?);
    try std.fs.cwd().deleteFile(lsp.test_output_file.?);
    try std.testing.expectEqual(0, res);
}
