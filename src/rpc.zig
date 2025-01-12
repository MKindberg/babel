const std = @import("std");
const logger = @import("logger.zig");

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

pub const MethodType = enum {
    initialize,
    initialized,
    @"textDocument/didOpen",
    @"textDocument/didChange",
    @"textDocument/didSave",
    @"textDocument/didClose",
    @"textDocument/hover",
    @"textDocument/codeAction",
    @"textDocument/declaration",
    @"textDocument/definition",
    @"textDocument/formatting",
    @"textDocument/typeDefinition",
    @"textDocument/implementation",
    @"textDocument/references",
    @"textDocument/completion",
    @"textDocument/rangeFormatting",
    @"$/setTrace",
    @"$/cancelRequest",
    shutdown,
    exit,

    pub fn toString(self: MethodType) []const u8 {
        return @tagName(self);
    }
    pub fn fromString(s: []const u8) !MethodType {
        inline for (@typeInfo(MethodType).Enum.fields) |field| {
            if (std.mem.eql(u8, s, field.name)) {
                return @enumFromInt(field.value);
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

pub fn decodeMessage(allocator: std.mem.Allocator, msg: []const u8) !DecodedMessage {
    const parsed = try std.json.parseFromSlice(BaseMessage, allocator, msg, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    std.log.debug("Decoded {s}", .{parsed.value.method});
    const method_type = try MethodType.fromString(parsed.value.method);
    return .{ .method = method_type, .content = msg };
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
    const msg = "{\"method\":\"initialize\",\"y\":37}";
    const message = try decodeMessage(std.testing.allocator, msg[0..]);
    try std.testing.expectEqual(message.method, MethodType.initialize);
}
