const std = @import("std");
const logger = @import("logger.zig");
const types = @import("types.zig");

pub fn encodeMessage(allocator: std.mem.Allocator, msg: anytype) ![]u8 {
    const data = try std.json.Stringify.valueAlloc(allocator, msg, .{});
    defer allocator.free(data);

    const length = data.len;
    var buf: [32]u8 = undefined;
    const content_len = try std.fmt.bufPrint(&buf, "Content-Length: {any}\r\n\r\n", .{length});

    const res = std.mem.join(allocator, "", &[_][]const u8{ content_len, data });
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
    @"$/cancelRequest": types.Notification.Cancel,
    shutdown: types.Request.Shutdown,
    exit,

    pub fn toString(self: MethodType) []const u8 {
        return @tagName(self);
    }
    pub fn parseMessage(arena: std.mem.Allocator, method: []const u8, msg: []const u8) !MethodType {
        inline for (@typeInfo(MethodType).@"union".fields) |field| {
            if (std.mem.eql(u8, method, "initialized")) return .initialized;
            if (std.mem.eql(u8, method, "exit")) return .exit;
            if (std.mem.eql(u8, method, field.name) and (field.type) != void) {
                return @unionInit(MethodType, field.name, try std.json.parseFromSliceLeaky(field.type, arena, msg, .{ .ignore_unknown_fields = true, .allocate = .alloc_always }));
            }
        }
        std.log.warn("Unknown method: {s}", .{method});
        return DecodeError.UnknownMethod;
    }
};

const DecodeError = error{
    InvalidMessage,
    UnknownMethod,
};

pub const DecodedMessage = struct {
    method: MethodType,
};

pub fn decodeMessage(allocator: std.mem.Allocator, msg: []const u8) !MethodType {
    const parsed = try std.json.parseFromSlice(BaseMessage, allocator, msg, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    std.log.debug("Decoded {s}", .{parsed.value.method});
    return try MethodType.parseMessage(allocator, parsed.value.method, msg);
}

test "encodeMessage" {
    const allocator = std.testing.allocator;
    const Foo = struct {
        x: u32,
        y: u32,
    };
    const foo = Foo{ .x = 42, .y = 37 };
    const encoded = try encodeMessage(allocator, foo);
    defer allocator.free(encoded);
    try std.testing.expect(std.mem.eql(u8, "Content-Length: 15\r\n\r\n{\"x\":42,\"y\":37}", encoded));
}

test "decodeMessage" {
    const msg = "{\"method\":\"initialize\",\"id\":37, \"params\": {}}";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const message = try decodeMessage(arena.allocator(), msg[0..]);
    try std.testing.expectEqualStrings(message.toString(), "initialize");
}
