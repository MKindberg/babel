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

pub const MethodType = CreateMethodType();

/// Creates a tagged union from the Request and Notification types where
/// the method is the tag and the value is the struct.
fn CreateMethodType() type {
    var enum_fields: []const std.builtin.Type.EnumField = &.{};
    var union_fields: []const std.builtin.Type.UnionField = &.{};

    var count = 0;

    inline for (.{ types.Request, types.Notification }) |base_type| {
        const decls = @typeInfo(base_type).@"struct".decls;
        inline for (decls) |decl| {
            const field_type = (@field(base_type, decl.name));
            comptime if (@hasDecl(field_type, "outgoing") and @field(field_type, "outgoing")) continue;
            comptime if (std.meta.fieldIndex(field_type, "method")) |idx| {
                const type_info = @typeInfo(field_type).@"struct";
                const name = type_info.fields[idx].defaultValue() orelse continue;
                enum_fields = enum_fields ++ .{std.builtin.Type.EnumField{ .name = name[0.. :0], .value = count }};
                union_fields = union_fields ++ .{std.builtin.Type.UnionField{ .name = name[0.. :0], .type = field_type, .alignment = @alignOf(field_type) }};
                count += 1;
            };
        }
    }

    return @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = @Type(.{
                .@"enum" = .{
                    .tag_type = std.math.IntFittingRange(0, count),
                    .fields = enum_fields,
                    .decls = &.{},
                    .is_exhaustive = true,
                },
            }),
            .fields = union_fields,
            .decls = &.{},
        },
    });
}

const DecodeError = error{
    InvalidMessage,
    UnknownMethod,
};

const DecodedMessage = struct {
    method: MethodType,
};

pub fn decodeMessage(allocator: std.mem.Allocator, msg: []const u8) !MethodType {
    const parsed = try std.json.parseFromSlice(BaseMessage, allocator, msg, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    std.log.debug("Decoded {s}", .{parsed.value.method});
    inline for (@typeInfo(MethodType).@"union".fields) |field| {
        if (std.mem.eql(u8, parsed.value.method, field.name)) {
            return @unionInit(
                MethodType,
                field.name,
                try std.json.parseFromSliceLeaky(field.type, allocator, msg, .{
                    .ignore_unknown_fields = true,
                    .allocate = .alloc_always, // Otherwise some fields might go out of scope when the message is freed.
                }),
            );
        }
    }
    std.log.warn("Unknown method: {s}", .{parsed.value.method});
    return DecodeError.UnknownMethod;
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
    try std.testing.expectEqualStrings(@tagName(message), "initialize");
}
