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
    const change_doc = types.Notification.DidChangeTextDocument{ .params = .{
        .textDocument = .{ .uri = uri, .version = 0 },
        .contentChanges = &changes,
    } };
    try queueMessage(writer, change_doc);
}

fn formatDoc(writer: *std.Io.Writer, uri: []const u8) !void {
    const formatting = types.Request.Formatting{ .id = @enumFromInt(0), .params = .{ .textDocument = .{ .uri = uri }, .options = .{ .tabSize = 4, .insertSpaces = false } } };
    try queueMessage(writer, formatting);
}

test "init-shutdown" {
    var input_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer input_writer.deinit();

    const uri = "test.txt";
    try initializeServer(&input_writer.writer);
    try openDoc(&input_writer.writer, uri, "Test document");
    try changeDoc(&input_writer.writer, uri, "Added text");
    try closeDoc(&input_writer.writer, uri);
    try shutdownServer(&input_writer.writer);

    var reader = std.Io.Reader.fixed(input_writer.written());
    var writer = std.Io.Writer.Discarding.init(&.{}).writer;

    var server = Lsp(.{}).init(std.testing.allocator, std.testing.io, &reader, &writer, .{ .name = "testing" });
    defer server.deinit();
    const res = try server.start(null);

    try std.testing.expectEqual(0, res);
}

fn formatCallback(_: Lsp(.{}).FormattingParameters) Lsp(.{}).FormattingReturn {
    return null;
}

test "formatting" {
    var input_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer input_writer.deinit();

    const uri = "test.txt";
    try initializeServer(&input_writer.writer);
    try openDoc(&input_writer.writer, uri, "Test document");
    try changeDoc(&input_writer.writer, uri, "Added text");
    try formatDoc(&input_writer.writer, uri);
    try closeDoc(&input_writer.writer, uri);
    try shutdownServer(&input_writer.writer);

    var reader = std.Io.Reader.fixed(input_writer.written());
    var writer = std.Io.Writer.Discarding.init(&.{}).writer;

    var server = Lsp(.{}).init(std.testing.allocator, std.testing.io, &reader, &writer, .{ .name = "testing" });
    server.registerCallback(.{ .@"textDocument/formatting" = formatCallback });
    defer server.deinit();
    const res = try server.start(null);

    try std.testing.expectEqual(0, res);
}

fn initializeServerWithConfiguration(writer: *std.Io.Writer, supports_configuration: bool) !void {
    const initialize = .{
        .jsonrpc = "2.0",
        .id = 0,
        .method = "initialize",
        .params = .{ .capabilities = .{ .workspace = .{ .configuration = supports_configuration } } },
    };
    try queueMessage(writer, initialize);
    const initialized = types.Notification.Notification{ .method = "initialized" };
    try queueMessage(writer, initialized);
}

fn changeConfiguration(writer: *std.Io.Writer) !void {
    const notification = .{
        .jsonrpc = "2.0",
        .method = "workspace/didChangeConfiguration",
        .params = .{ .settings = .{ .changed = true } },
    };
    try queueMessage(writer, notification);
}

fn configurationResponse(writer: *std.Io.Writer, id: i32) !void {
    const response = .{
        .jsonrpc = "2.0",
        .id = id,
        .result = .{.{ .enabled = true, .name = "from client" }},
    };
    try queueMessage(writer, response);
}

const configuration_settings: lsp.LspSettings = .{ .config_options = &.{"testing"} };

var configuration_count: ?usize = null;
var configuration_enabled: ?bool = null;
var configuration_name_buf: [64]u8 = undefined;
var configuration_name: ?[]const u8 = null;

fn configurationChangeCallback(p: Lsp(configuration_settings).ConfigurationChangeParameters) void {
    configuration_count = p.result.len;
    if (p.result.len == 0) return;
    configuration_enabled = p.result[0].object.get("enabled").?.bool;
    const name = p.result[0].object.get("name").?.string;
    configuration_name = configuration_name_buf[0..name.len];
    @memcpy(configuration_name_buf[0..name.len], name);
}

fn resetConfigurationResults() void {
    configuration_count = null;
    configuration_enabled = null;
    configuration_name = null;
}

test "configuration request" {
    var input_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer input_writer.deinit();

    try initializeServerWithConfiguration(&input_writer.writer, true);
    // Server-initiated request ids count down from -1. The first request is sent
    // automatically after the 'initialized' notification.
    try configurationResponse(&input_writer.writer, -1);
    try changeConfiguration(&input_writer.writer);
    try configurationResponse(&input_writer.writer, -2);
    try shutdownServer(&input_writer.writer);

    var reader = std.Io.Reader.fixed(input_writer.written());
    var writer = std.Io.Writer.Discarding.init(&.{}).writer;

    resetConfigurationResults();

    var server = Lsp(configuration_settings).init(std.testing.allocator, std.testing.io, &reader, &writer, .{ .name = "testing" });
    server.registerCallback(.{ .@"workspace/didChangeConfiguration" = configurationChangeCallback });
    defer server.deinit();
    const res = try server.start(null);

    try std.testing.expectEqual(0, res);
    try std.testing.expectEqual(@as(?usize, 1), configuration_count);
    try std.testing.expectEqual(@as(?bool, true), configuration_enabled);
    try std.testing.expectEqualStrings("from client", configuration_name.?);
}

test "configuration request without client support" {
    var input_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer input_writer.deinit();

    try initializeServerWithConfiguration(&input_writer.writer, false);
    try changeConfiguration(&input_writer.writer);
    try shutdownServer(&input_writer.writer);

    var reader = std.Io.Reader.fixed(input_writer.written());
    var writer = std.Io.Writer.Discarding.init(&.{}).writer;

    resetConfigurationResults();

    var server = Lsp(configuration_settings).init(std.testing.allocator, std.testing.io, &reader, &writer, .{ .name = "testing" });
    server.registerCallback(.{ .@"workspace/didChangeConfiguration" = configurationChangeCallback });
    defer server.deinit();
    const res = try server.start(null);

    // The client doesn't support pull configuration, so the callback is never invoked
    try std.testing.expectEqual(0, res);
    try std.testing.expect(configuration_count == null);
}
