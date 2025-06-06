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
        const data = try allocator.alloc(u8, content.len + content.len / 3);
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

    fn updateFull(self: *Document, text: []const u8) !void {
        const new_len = text.len;
        if (new_len > self.data.len) {
            self.data = try self.allocator.realloc(self.data, new_len + new_len / 3);
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
        if (new_len > self.data.len) {
            self.data = try self.allocator.realloc(self.data, new_len + new_len / 3);
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

    pub fn idxToPos(text: []const u8, idx: usize) ?types.Position {
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

    pub fn posToIdx(text: []const u8, pos: types.Position) ?usize {
        var offset: usize = 0;
        var i: usize = 0;
        while (i < pos.line) : (i += 1) {
            if (std.mem.indexOf(u8, text[offset..], "\n")) |idx| {
                offset += idx + 1;
            } else return null;
        }
        return offset + pos.character;
    }

    /// Find all occurrences of pattern within the document.
    pub fn find(self: Document, pattern: []const u8) FindIterator {
        return FindIterator.init(self.text, pattern);
    }

    /// Find all occurrences of pattern within range.
    pub fn findInRange(self: Document, range: types.Range, pattern: []const u8) FindIterator {
        var start_idx = posToIdx(self.text, range.start).?;
        start_idx -= @min(start_idx, pattern.len);

        var end_idx = posToIdx(self.text, range.end).?;
        end_idx = @min(self.text.len, end_idx + pattern.len);

        return FindIterator.initWithOffset(self.text, pattern, start_idx, end_idx);
    }

    /// Get the line containing pos.
    pub fn getLine(self: Document, pos: types.Position) ?[]const u8 {
        const idx = posToIdx(self.text, pos) orelse return null;
        const start = if (std.mem.lastIndexOfScalar(u8, self.text[0..idx], '\n')) |s| s + 1 else 0;
        const end = idx + (std.mem.indexOfScalar(u8, self.text[idx..], '\n') orelse self.text.len - idx);

        return self.text[start..end];
    }

    /// Get the word containing pos, a word is anything surrounded by the characters in delimiter.
    pub fn getWord(self: Document, pos: types.Position, delimiter: []const u8) ?[]const u8 {
        const idx = posToIdx(self.text, pos) orelse return null;
        const start = if (std.mem.lastIndexOfAny(u8, self.text[0..idx], delimiter)) |i| i + 1 else 0;
        const end = std.mem.indexOfAnyPos(u8, self.text, idx, delimiter) orelse self.text.len;
        return self.text[start..end];
    }

    /// Get the text in the specified range. Return null if range.start isn't in the document
    /// or if end > start. Returns the rest of the document if end is larger than document.len
    pub fn getRange(self: Document, range: types.Range) ?[]const u8 {
        const start = Document.posToIdx(self.text, range.start) orelse return null;
        const end = Document.posToIdx(self.text, range.end) orelse self.text.len;
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

    pub fn initWithOffset(text: []const u8, pattern: []const u8, start: usize, end: usize) Self {
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
            const start_pos = Document.idxToPos(self.text, idx).?;
            const end_pos = Document.idxToPos(self.text, idx + self.pattern.len).?;
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
