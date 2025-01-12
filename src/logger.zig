const std = @import("std");
const types = @import("types.zig");
const writeResponseInternal = @import("lsp.zig").writeResponseInternal;

pub var trace_value: types.TraceValue = .Off;

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;

    const message_type = switch (level) {
        .err => types.MessageType.Error,
        .warn => types.MessageType.Warning,
        .info => types.MessageType.Info,
        .debug => types.MessageType.Debug,
    };

    var message_buf: [1024]u8 = undefined;

    const message = std.fmt.bufPrint(&message_buf, format, args) catch return;

    const notification = types.Notification.LogMessage{ .params = .{
        .type = message_type,
        .message = message,
    } };

    var response_buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&response_buf);
    writeResponseInternal(fba.allocator(), notification) catch return;
}

pub fn trace(comptime format: []const u8, args: anytype) void {
    if (trace_value == .Off) return;

    var buf: [1024]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, format, args) catch return;
    writeResponseInternal(std.heap.page_allocator, types.Notification.LogTrace{ .params = .{
        .message = message,
    } }) catch return;
}

pub fn traceVerbose(comptime format: []const u8, args: anytype, comptime verbose_format: []const u8, verbose_args: anytype) void {
    if (trace_value == .Off) return;

    var buf: [1024]u8 = undefined;
    var buf_verbose: [1024]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, format, args) catch return;
    const verbose = if (trace.value == .Verbose) std.fmt.bufPrint(&buf_verbose, verbose_format, verbose_args) catch null else null;
    writeResponseInternal(std.heap.page_allocator, types.Notification.Trace{ .params = .{
        .message = message,
        .verbose = verbose,
    } }) catch return;
}

pub fn fileLog(filename: []const u8) fn (
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    return struct {
        pub fn log(
            comptime level: std.log.Level,
            comptime scope: @TypeOf(.EnumLiteral),
            comptime format: []const u8,
            args: anytype,
        ) void {
            _ = scope;
            const f = struct {
                var file: ?std.fs.File = null;
            };
            if (f.file == null) {
                f.file = std.fs.cwd().createFile(filename, .{}) catch |e| std.debug.panic("Failed to open " ++ filename ++ " for logging {}", .{e});
            }

            const message_type = switch (level) {
                .err => "[Error]",
                .warn => "[Warning]",
                .info => "[Info]",
                .debug => "[Debug]",
            };

            var message_buf: [1024]u8 = undefined;

            const message = std.fmt.bufPrint(&message_buf, message_type ++ " " ++ format ++ "\n", args) catch return;

            _ = f.file.?.write(message) catch @panic("Failed write logs to " ++ filename);
        }
    }.log;
}
