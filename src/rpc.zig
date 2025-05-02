const std = @import("std");
const logger = @import("logger.zig");
const types = @import("types.zig");

pub fn encodeMessage(allocator: std.mem.Allocator, msg: anytype) !std.ArrayList(u8) {
    var res = std.ArrayList(u8).init(allocator);
    errdefer res.deinit();
    try std.json.stringify(msg, .{}, res.writer());

    const length = res.items.len;
    var buf: [32]u8 = undefined;
    const content_len = try std.fmt.bufPrint(&buf, "Content-Length: {any}\r\n\r\n", .{length});

    try res.insertSlice(0, content_len);
    return res;
}

const BaseMessage = struct {
    method: []const u8,
};

pub const MethodType = union(enum) {
    initialize: types.Request.Initialize,
    initialized,
    @"textDocument/didOpen": types.Notification.DidOpenTextDocument,
    @"textDocument/didChange": types.Notification.DidChangeTextDocument,
    @"textDocument/didSave": types.Notification.DidSaveTextDocument,
    @"textDocument/didClose": types.Notification.DidCloseTextDocument,
    @"textDocument/hover": types.Request.PositionRequest,
    @"textDocument/codeAction": types.Request.CodeAction,
    @"textDocument/declaration": types.Request.PositionRequest,
    @"textDocument/definition": types.Request.PositionRequest,
    @"textDocument/formatting": types.Request.Formatting,
    @"textDocument/typeDefinition": types.Request.PositionRequest,
    @"textDocument/implementation": types.Request.PositionRequest,
    @"textDocument/references": types.Request.PositionRequest,
    @"textDocument/completion": types.Request.Completion,
    @"textDocument/rangeFormatting": types.Request.RangeFormatting,
    @"$/setTrace": types.Notification.SetTrace,
    @"$/cancelRequest",
    shutdown: types.Request.Shutdown,
    exit,

    pub fn toString(self: MethodType) []const u8 {
        return @tagName(self);
    }
    pub fn parseMessage(arena: std.mem.Allocator, s: []const u8, msg: []const u8) !MethodType {
        inline for (@typeInfo(MethodType).@"union".fields) |field| {
            if (std.mem.eql(u8, s, "initialized")) return .initialized;
            if (std.mem.eql(u8, s, "$/cancelRequest")) return .@"$/cancelRequest";
            if (std.mem.eql(u8, s, "exit")) return .exit;
            if (std.mem.eql(u8, s, field.name) and (field.type) != void) {
                return @unionInit(MethodType, field.name, try std.json.parseFromSliceLeaky(field.type, arena, msg, .{ .ignore_unknown_fields = true }));
            }
        }
        std.log.warn("Unknown method: {s}", .{s});
        return DecodeError.UnknownMethod;
    }
};

const DecodeError = error{
    InvalidMessage,
    UnknownMethod,
};

pub const DecodedMessage = struct {
    method: MethodType,
    content: []const u8 = "",
};

pub fn decodeMessage(allocator: std.mem.Allocator, msg: []const u8) !MethodType {
    const parsed = try std.json.parseFromSlice(BaseMessage, allocator, msg, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    std.log.debug("Decoded {s}", .{parsed.value.method});
    return try MethodType.parseMessage(allocator, parsed.value.method, msg);
}

test "encodeMessage" {
    const Foo = struct {
        x: u32,
        y: u32,
    };
    const foo = Foo{ .x = 42, .y = 37 };
    const encoded = try encodeMessage(std.testing.allocator, foo);
    defer encoded.deinit();
    try std.testing.expect(std.mem.eql(u8, "Content-Length: 15\r\n\r\n{\"x\":42,\"y\":37}", encoded.items));
}

test "decodeMessage" {
    const msg = "{\"method\":\"initialize\",\"id\":37, \"params\": {}}";
    const message = try decodeMessage(std.testing.allocator, msg[0..]);
    try std.testing.expectEqual(message.toString(), "initialize");
}
