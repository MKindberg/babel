const std = @import("std");
const types = @import("types.zig");

pub const Document = struct {
    allocator: std.mem.Allocator,
    uri: []const u8,
    language: []const u8,
    /// Slice pointing to the document's text.
    text: []u8,
    /// Slice pointing to the memory where the text is stored.
    data: []u8,

    pub fn init(allocator: std.mem.Allocator, uri: []const u8, language: []const u8, content: []const u8) !Document {
        const data = try allocator.alloc(u8, Document.allocationSize(content.len));
        std.mem.copyForwards(u8, data, content);
        const text = data[0..content.len];
        return Document{
            .allocator = allocator,
            .uri = try allocator.dupe(u8, uri),
            .language = try allocator.dupe(u8, language),
            .data = data,
            .text = text,
        };
    }

    pub fn deinit(self: Document) void {
        self.allocator.free(self.uri);
        self.allocator.free(self.language);
        self.allocator.free(self.data);
    }

    fn allocationSize(size: usize) usize {
        if (size < 64 * 1024) return size * 2;
        if (size < 512 * 1024) return size + size / 2;
        if (size < 1024 * 1024) return size + size / 4;
        return 64 * 1024;
    }

    fn updateFull(self: *Document, text: []const u8) !void {
        const new_len = text.len;
        if (new_len > self.data.len or new_len < self.data.len / 4) {
            self.data = try self.allocator.realloc(self.data, Document.allocationSize(new_len));
        }
        std.mem.copyForwards(u8, self.data, text);
        @memset(self.data[new_len..], 0);
        self.text = self.data[0..new_len];
    }
    pub fn update(self: *Document, change: types.ChangeEvent) !void {
        if (change.range) |r| {
            try self.updatePartial(change.text, r);
        } else {
            try self.updateFull(change.text);
        }
    }
    pub fn updateAll(self: *Document, changes: []const types.ChangeEvent) !void {
        // The LSP spec says that updates should be applied in the order that arrived.
        for (changes) |change| {
            try self.update(change);
        }
    }
    fn updatePartial(self: *Document, text: []const u8, range: types.Range) !void {
        const range_start = self.posToIdx(range.start) orelse self.text.len;
        const range_end = self.posToIdx(range.end) orelse self.text.len;
        const range_len = range_end - range_start;
        const new_len = self.text.len + text.len - range_len;
        const old_len = self.text.len;
        if (new_len > self.data.len or new_len < self.data.len / 4) {
            self.data = try self.allocator.realloc(self.data, Document.allocationSize(new_len));
        }

        if (range_len > text.len) {
            std.mem.copyForwards(u8, self.data[range_start..], text);
            std.mem.copyForwards(u8, self.data[range_start + text.len ..], self.data[range_end..]);
        } else if (range_len < text.len) {
            std.mem.copyBackwards(u8, self.data[range_end + (text.len - range_len) ..], self.data[range_end..old_len]);
            std.mem.copyForwards(u8, self.data[range_start..], text);
        } else {
            std.mem.copyForwards(u8, self.data[range_start..range_end], text);
        }
        @memset(self.data[new_len..], 0);

        self.text = self.data[0..new_len];
    }

    pub fn idxToPos(self: Document, idx: usize) ?types.Position {
        return idxToPosText(self.text, idx);
    }
    pub fn idxToPosText(text: []const u8, idx: usize) ?types.Position {
        if (idx > text.len) {
            return null;
        }
        const line = std.mem.count(u8, text[0..idx], "\n");
        if (line == 0) {
            return .{ .line = 0, .character = idx };
        }
        const col = idx - (std.mem.lastIndexOf(u8, text[0..idx], "\n") orelse 0) - 1;
        return .{ .line = line, .character = col };
    }

    pub fn posToIdx(self: Document, pos: types.Position) ?usize {
        return posToIdxText(self.text, pos);
    }
    pub fn posToIdxText(text: []const u8, pos: types.Position) ?usize {
        var offset: usize = 0;
        var i: usize = 0;
        while (i < pos.line) : (i += 1) {
            if (std.mem.indexOf(u8, text[offset..], "\n")) |idx| {
                offset += idx + 1;
            } else return null;
        }

        const line_len = std.mem.indexOf(u8, text[offset..], "\n") orelse text[offset..].len;
        if (pos.character > line_len) return null;

        return offset + pos.character;
    }

    /// Find all occurrences of pattern within the document.
    pub fn find(self: Document, pattern: []const u8) FindIterator {
        return FindIterator.init(self.text, pattern);
    }

    /// Find all occurrences of pattern within range.
    pub fn findInRange(self: Document, range: types.Range, pattern: []const u8) FindIterator {
        var start_idx = self.posToIdx(range.start).?;
        start_idx -= @min(start_idx, pattern.len);

        var end_idx = self.posToIdx(range.end).?;
        end_idx = @min(self.text.len, end_idx + pattern.len);

        return FindIterator.initWithOffset(self.text, pattern, start_idx, end_idx);
    }

    /// Get the line containing pos.
    pub fn getLine(self: Document, pos: types.Position) ?[]const u8 {
        const idx = self.posToIdx(pos) orelse return null;
        const start = if (std.mem.lastIndexOfScalar(u8, self.text[0..idx], '\n')) |s| s + 1 else 0;
        const end = idx + (std.mem.indexOfScalar(u8, self.text[idx..], '\n') orelse self.text.len - idx);

        return self.text[start..end];
    }

    /// Get the word containing pos, a word is anything surrounded by the characters in delimiter.
    pub fn getWord(self: Document, pos: types.Position, delimiter: []const u8) ?[]const u8 {
        const idx = self.posToIdx(pos) orelse return null;
        if (std.mem.indexOfScalar(u8, delimiter, self.text[idx]) != null) return null;
        const start = if (std.mem.lastIndexOfAny(u8, self.text[0..idx], delimiter)) |i| i + 1 else 0;
        const end = std.mem.indexOfAnyPos(u8, self.text, idx, delimiter) orelse self.text.len;
        return self.text[start..end];
    }

    /// Get the text in the specified range. Return null if range.start isn't in the document
    /// or if end > start. Returns the rest of the document if end is larger than document.len
    pub fn getRange(self: Document, range: types.Range) ?[]const u8 {
        const start = self.posToIdx(range.start) orelse return null;
        const end = self.posToIdx(range.end) orelse self.text.len;
        if (end < start) {
            return null;
        }
        return self.text[start..end];
    }
};

pub const FindIterator = struct {
    /// The text to search in.
    text: []const u8,
    /// The pattern to search for.
    pattern: []const u8,
    /// The current offset in the text.
    offset: usize = 0,
    end: ?usize = null,

    const Self = @This();
    pub fn init(text: []const u8, pattern: []const u8) Self {
        return FindIterator{
            .text = text,
            .pattern = pattern,
        };
    }

    pub fn initWithOffset(text: []const u8, pattern: []const u8, start: usize, end: ?usize) Self {
        return FindIterator{
            .text = text,
            .pattern = pattern,
            .offset = start,
            .end = end,
        };
    }

    pub fn next(self: *Self) ?types.Range {
        if (self.offset >= self.text.len) {
            return null;
        }
        if (std.mem.indexOf(u8, self.text[self.offset..(self.end orelse self.text.len)], self.pattern)) |i| {
            const idx = i + self.offset;
            const start_pos = Document.idxToPosText(self.text, idx).?;
            const end_pos = Document.idxToPosText(self.text, idx + self.pattern.len).?;
            self.offset = idx + self.pattern.len;
            const res = types.Range{
                .start = start_pos,
                .end = end_pos,
            };
            return res;
        }
        return null;
    }
};

test "addText" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world");
    defer doc.deinit();

    try doc.updatePartial(",", .{
        .start = .{ .line = 0, .character = 5 },
        .end = .{ .line = 0, .character = 5 },
    });
    try std.testing.expectEqualStrings("hello, world", doc.text);
}

test "addTextAtEnd" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world");
    defer doc.deinit();

    try doc.updatePartial("!", .{
        .start = .{ .line = 0, .character = 11 },
        .end = .{ .line = 0, .character = 11 },
    });
    try std.testing.expectEqualStrings("hello world!", doc.text);
}

test "addTextAtStart" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "ello world");
    defer doc.deinit();

    try doc.updatePartial("H", .{
        .start = .{ .line = 0, .character = 0 },
        .end = .{ .line = 0, .character = 0 },
    });
    try std.testing.expectEqualStrings("Hello world", doc.text);
}

test "ChangeText" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world");
    defer doc.deinit();
    try doc.updatePartial("H", .{
        .start = .{ .line = 0, .character = 0 },
        .end = .{ .line = 0, .character = 1 },
    });
    try std.testing.expectEqualStrings("Hello world", doc.text);
}

test "RemoveText" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "Hello world");
    defer doc.deinit();
    try doc.updatePartial("", .{
        .start = .{ .line = 0, .character = 5 },
        .end = .{ .line = 0, .character = 6 },
    });
    try std.testing.expectEqualStrings("Helloworld", doc.text);
}

test "RemoveTextAtStart" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "Hello world");
    defer doc.deinit();
    try doc.updatePartial("", .{
        .start = .{ .line = 0, .character = 0 },
        .end = .{ .line = 0, .character = 1 },
    });
    try std.testing.expectEqualStrings("ello world", doc.text);
}

test "RemoveTextAtEnd" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "Hello world");
    defer doc.deinit();
    try doc.updatePartial("", .{
        .start = .{ .line = 0, .character = 10 },
        .end = .{ .line = 0, .character = 11 },
    });
    try std.testing.expectEqualStrings("Hello worl", doc.text);
}

test "RemoveTextBothEnds" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "Hello world");
    defer doc.deinit();
    try doc.updateAll(&[_]types.ChangeEvent{
        .{
            .range = .{
                .start = .{ .line = 0, .character = 10 },
                .end = .{ .line = 0, .character = 11 },
            },
            .text = "",
        },
        .{
            .range = .{
                .start = .{ .line = 0, .character = 0 },
                .end = .{ .line = 0, .character = 1 },
            },
            .text = "",
        },
    });
    try std.testing.expectEqualStrings("ello worl", doc.text);
}

test "ReplaceText" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "Hello world");
    defer doc.deinit();
    try doc.updateFull("Hi");
    try std.testing.expectEqualStrings("Hi", doc.text);
}

test "ReplaceText2" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "Hello world");
    defer doc.deinit();
    try doc.updateFull("Longer text to overwrite");
    try std.testing.expectEqualStrings("Longer text to overwrite", doc.text);
}

test "idxToPosText" {
    const text = "hello\nworld\nzig";
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 0 }, Document.idxToPosText(text, 0));
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 5 }, Document.idxToPosText(text, 5));
    try std.testing.expectEqual(types.Position{ .line = 1, .character = 0 }, Document.idxToPosText(text, 6));
    try std.testing.expectEqual(types.Position{ .line = 1, .character = 5 }, Document.idxToPosText(text, 11));
    try std.testing.expectEqual(types.Position{ .line = 2, .character = 0 }, Document.idxToPosText(text, 12));
    try std.testing.expectEqual(types.Position{ .line = 2, .character = 3 }, Document.idxToPosText(text, 15));
    try std.testing.expectEqual(null, Document.idxToPosText(text, 20));
}

test "posToIdxText" {
    const text = "hello\nworld\nzig";
    try std.testing.expectEqual(0, Document.posToIdxText(text, .{ .line = 0, .character = 0 }));
    try std.testing.expectEqual(5, Document.posToIdxText(text, .{ .line = 0, .character = 5 }));
    try std.testing.expectEqual(6, Document.posToIdxText(text, .{ .line = 1, .character = 0 }));
    try std.testing.expectEqual(11, Document.posToIdxText(text, .{ .line = 1, .character = 5 }));
    try std.testing.expectEqual(12, Document.posToIdxText(text, .{ .line = 2, .character = 0 }));
    try std.testing.expectEqual(15, Document.posToIdxText(text, .{ .line = 2, .character = 3 }));
    try std.testing.expectEqual(null, Document.posToIdxText(text, .{ .line = 5, .character = 0 }));
    try std.testing.expectEqual(null, Document.posToIdxText(text, .{ .line = 0, .character = 20 }));
}

test "idxToPos" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello\nworld\nzig");
    defer doc.deinit();

    try std.testing.expectEqual(types.Position{ .line = 0, .character = 0 }, doc.idxToPos(0));
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 5 }, doc.idxToPos(5));
    try std.testing.expectEqual(types.Position{ .line = 1, .character = 0 }, doc.idxToPos(6));
    try std.testing.expectEqual(types.Position{ .line = 2, .character = 3 }, doc.idxToPos(15));
    try std.testing.expectEqual(null, doc.idxToPos(20));
}

test "posToIdx" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello\nworld\nzig");
    defer doc.deinit();

    try std.testing.expectEqual(0, doc.posToIdx(.{ .line = 0, .character = 0 }));
    try std.testing.expectEqual(5, doc.posToIdx(.{ .line = 0, .character = 5 }));
    try std.testing.expectEqual(6, doc.posToIdx(.{ .line = 1, .character = 0 }));
    try std.testing.expectEqual(15, doc.posToIdx(.{ .line = 2, .character = 3 }));
    try std.testing.expectEqual(null, doc.posToIdx(.{ .line = 5, .character = 0 }));
}

test "update with range" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world");
    defer doc.deinit();

    try doc.update(.{
        .range = .{
            .start = .{ .line = 0, .character = 5 },
            .end = .{ .line = 0, .character = 6 },
        },
        .text = ",",
    });
    try std.testing.expectEqualStrings("hello,world", doc.text);
}

test "update without range (full update)" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world");
    defer doc.deinit();

    try doc.update(.{
        .range = null,
        .text = "new text",
    });
    try std.testing.expectEqualStrings("new text", doc.text);
}

test "getLine" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello\nworld\nzig");
    defer doc.deinit();

    try std.testing.expectEqualStrings("hello", doc.getLine(.{ .line = 0, .character = 2 }).?);
    try std.testing.expectEqualStrings("world", doc.getLine(.{ .line = 1, .character = 3 }).?);
    try std.testing.expectEqualStrings("zig", doc.getLine(.{ .line = 2, .character = 1 }).?);
    try std.testing.expectEqual(null, doc.getLine(.{ .line = 5, .character = 0 }));
}

test "getWord" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world zig");
    defer doc.deinit();

    try std.testing.expectEqualStrings("hello", doc.getWord(.{ .line = 0, .character = 2 }, " \n\t").?);
    try std.testing.expectEqualStrings("world", doc.getWord(.{ .line = 0, .character = 7 }, " \n\t").?);
    try std.testing.expectEqualStrings("zig", doc.getWord(.{ .line = 0, .character = 13 }, " \n\t").?);
    try std.testing.expectEqual(null, doc.getWord(.{ .line = 0, .character = 5 }, " \n\t"));
    try std.testing.expectEqual(null, doc.getWord(.{ .line = 5, .character = 0 }, " \n\t"));
}

test "getRange" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world zig");
    defer doc.deinit();

    try std.testing.expectEqualStrings("hello", doc.getRange(.{
        .start = .{ .line = 0, .character = 0 },
        .end = .{ .line = 0, .character = 5 },
    }).?);
    try std.testing.expectEqualStrings("world", doc.getRange(.{
        .start = .{ .line = 0, .character = 6 },
        .end = .{ .line = 0, .character = 11 },
    }).?);
    try std.testing.expectEqual(null, doc.getRange(.{
        .start = .{ .line = 0, .character = 10 },
        .end = .{ .line = 0, .character = 5 },
    })); // end < start
    try std.testing.expectEqual(null, doc.getRange(.{
        .start = .{ .line = 5, .character = 0 },
        .end = .{ .line = 5, .character = 5 },
    })); // start out of bounds
}

test "find" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world hello zig hello");
    defer doc.deinit();

    var iter = doc.find("hello");
    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "findInRange" {
    const allocator = std.testing.allocator;
    var doc = try Document.init(allocator, "", "", "hello world hello zig hello");
    defer doc.deinit();

    var iter = doc.findInRange(.{
        .start = .{ .line = 0, .character = 0 },
        .end = .{ .line = 0, .character = 12 },
    }, "hello");
    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 2), count); // Should find "hello" at pos 0 and in "world"
}

test "FindIterator init and next" {
    const text = "hello world hello zig";
    var iter = FindIterator.init(text, "hello");

    const first = iter.next().?;
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 0 }, first.start);
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 5 }, first.end);

    const second = iter.next().?;
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 12 }, second.start);
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 17 }, second.end);

    try std.testing.expectEqual(null, iter.next());
}

test "FindIterator initWithOffset" {
    const text = "hello world hello zig hello";
    var iter = FindIterator.initWithOffset(text, "hello", 6, null);

    const first = iter.next().?;
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 12 }, first.start);
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 17 }, first.end);

    const second = iter.next().?;
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 22 }, second.start);
    try std.testing.expectEqual(types.Position{ .line = 0, .character = 27 }, second.end);

    try std.testing.expectEqual(null, iter.next());
}
