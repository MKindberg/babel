const std = @import("std");

const types = @import("types.zig");
const rpc = @import("rpc.zig");

const lsp = @import("lsp.zig");
const Lsp = lsp.Lsp;

fn queueMessage(writer: *std.Io.Writer, message: anytype) !void {
    const allocator = std.testing.allocator;
    const encoded = try rpc.encodeMessage(allocator, message);
    defer allocator.free(encoded);
    _ = try writer.write(encoded);
}

fn initializeServer(writer: *std.Io.Writer) !void {
    const initialize = types.Request.Initialize{ .id = @enumFromInt(0) };
    try queueMessage(writer, initialize);
    const initialized = types.Notification.Notification{ .method = "initialized" };
    try queueMessage(writer, initialized);
}

fn shutdownServer(writer: *std.Io.Writer) !void {
    const shutdown = types.Request.Shutdown{ .id = @enumFromInt(0) };
    try queueMessage(writer, shutdown);
    const exit = types.Notification.Notification{ .method = "exit" };
    try queueMessage(writer, exit);
}

fn openDoc(writer: *std.Io.Writer, uri: []const u8, text: []const u8) !void {
    const open_doc = types.Notification.DidOpenTextDocument{ .params = .{ .textDocument = .{ .uri = uri, .languageId = "txt", .version = 0, .text = text } } };
    try queueMessage(writer, open_doc);
}

fn closeDoc(writer: *std.Io.Writer, uri: []const u8) !void {
    const close_doc = types.Notification.DidCloseTextDocument{ .params = .{ .textDocument = .{ .uri = uri } } };
    try queueMessage(writer, close_doc);
}

fn changeDoc(writer: *std.Io.Writer, uri: []const u8, text: []const u8) !void {
    const changes = [_]types.ChangeEvent{.{ .text = text, .range = .{ .start = .{ .line = 0, .character = 0 }, .end = .{ .line = 0, .character = 0 } } }};
    const close_doc = types.Notification.DidChangeTextDocument{ .params = .{
        .textDocument = .{ .uri = uri, .version = 0 },
        .contentChanges = &changes,
    } };
    try queueMessage(writer, close_doc);
}

test "init-shutdown" {
    var input_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer input_writer.deinit();

    const uri = "test.txt";
    try openDoc(&input_writer.writer, uri, "Test document");
    try changeDoc(&input_writer.writer, uri, "Added text");
    try closeDoc(&input_writer.writer, uri);
    try initializeServer(&input_writer.writer);
    try shutdownServer(&input_writer.writer);

    var reader = std.Io.Reader.fixed(input_writer.written());
    var writer = std.Io.Writer.Discarding.init(&.{}).writer;

    var server = Lsp(.{}).init(std.testing.allocator, &reader, &writer, .{ .name = "testing" });
    defer server.deinit();
    const res = try server.start();

    try std.testing.expectEqual(0, res);
}
