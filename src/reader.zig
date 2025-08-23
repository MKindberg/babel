const std = @import("std");

pub const Reader = struct {
    buffer: std.array_list.Managed(u8),
    stream: std.fs.File.Reader,

    pub fn init(allocator: std.mem.Allocator, stream: std.fs.File.Reader) Reader {
        return Reader{
            .buffer = std.array_list.Managed(u8).init(allocator),
            .stream = stream,
        };
    }
    pub fn deinit(self: *Reader) void {
        self.buffer.deinit();
    }

    const ReadError = error{EOF};
    /// Works similar to the corresponding function in the standard library but lets
    /// the delimiter be a []u8 instead of just a u8.
    pub fn readUntilDelimiterOrEof(self: *Reader, writer: anytype, delimiter: []const u8) !usize {
        defer self.buffer.clearRetainingCapacity();
        var buf: [1]u8 = undefined;
        while (self.buffer.items.len < delimiter.len or
            !std.mem.eql(u8, delimiter, self.buffer.items[self.buffer.items.len - delimiter.len ..]))
        {
            const r = self.stream.read(&buf) catch |e| {
                switch (e) {
                    error.EndOfStream => break,
                    else => return e,
                }
            };
            if (r == 0) break;
            try self.buffer.append(buf[0]);
        } else {
            return try writer.write(self.buffer.items[0 .. self.buffer.items.len - delimiter.len]);
        }
        return try writer.write(self.buffer.items);
    }

    pub fn readN(self: *Reader, writer: anytype, n: usize) !usize {
        defer self.buffer.clearRetainingCapacity();
        try self.buffer.resize(n);
        _ = try self.stream.read(self.buffer.items);

        return try writer.write(self.buffer.items);
    }
};

test "readUntilDelimiterOrEof" {
    const allocator = std.testing.allocator;

    const filename = "test.txt";

    const file = try std.fs.cwd().createFile(filename, .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile(filename) catch unreachable;

    _ = try file.write("hello\nworld\n\n");
    try file.seekTo(0);

    var reader = Reader.init(allocator, file.reader(&.{}));
    defer reader.deinit();

    var res = std.array_list.Managed(u8).init(allocator);
    defer res.deinit();

    _ = try reader.readUntilDelimiterOrEof(res.writer(), "\n\n");

    try std.testing.expect(std.mem.eql(u8, res.items, "hello\nworld"));
}

test "readN" {
    const allocator = std.testing.allocator;

    const filename = "test.txt";

    const file = try std.fs.cwd().createFile(filename, .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile(filename) catch unreachable;

    _ = try file.write("hello\nworld\n\n");
    try file.seekTo(0);

    var reader = Reader.init(allocator, file.reader(&.{}));
    defer reader.deinit();

    var res = std.array_list.Managed(u8).init(allocator);
    defer res.deinit();

    _ = try reader.readN(res.writer(), 5);

    try std.testing.expect(std.mem.eql(u8, res.items, "hello"));
}
