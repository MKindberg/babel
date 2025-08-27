const std = @import("std");

/// Works similar to the corresponding function in the standard library but lets
/// the delimiter be a []u8 instead of just a u8.
pub fn readUntilDelimiterOrEof(reader: *std.Io.Reader, writer: *std.Io.Writer, comptime delimiter: []const u8) !usize {
    var buffer = reader.peekArray(delimiter.len) catch |e| {
        switch (e) {
            error.EndOfStream => return 0,
            else => return e,
        }
    };
    var bytes_read: usize = 0;
    while (!std.mem.eql(u8, delimiter, buffer)) {
        reader.streamExact(writer, 1) catch |e| {
            switch (e) {
                error.EndOfStream => break,
                else => return e,
            }
        };
        bytes_read += 1;
        buffer = reader.peekArray(delimiter.len) catch |e| {
            switch (e) {
                error.EndOfStream => return 0,
                else => return e,
            }
        };
    } else {
        reader.toss(delimiter.len);
    }
    return bytes_read;
}

test "readUntilDelimiterOrEof" {
    var reader = std.Io.Reader.fixed("hello\nworld\n\n");

    var buf: ["hello\nworld".len]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);

    _ = try readUntilDelimiterOrEof(&reader, &writer, "\n\n");

    try std.testing.expectEqualStrings("hello\nworld", &buf);
}
