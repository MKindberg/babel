const std = @import("std");

const ts = @import("tree-sitter");

const types = @import("types.zig");
const BasicDocument = @import("document.zig").Document;

pub const Document = struct {
    language: ?*ts.Language,
    parser: *ts.Parser,
    tree: ?*ts.Tree,
    doc: BasicDocument,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, uri: []const u8, language_str: []const u8, content: []const u8) !Self {
        return .{
            .language = null,
            .parser = ts.Parser.create(),
            .tree = null,
            .doc = try BasicDocument.init(allocator, uri, language_str, content),
        };
    }
    pub fn init_ts(self: *Self, language: *ts.Language) !void {
        self.language = language;
        try self.parser.setLanguage(language);
        self.tree = self.parser.parseString(self.doc.text, null);
    }

    pub fn deinit(self: *Self) void {
        if (self.tree) |t| t.destroy();
        self.parser.destroy();
        if (self.language) |l| l.destroy();
        self.doc.deinit();
    }

    fn posToPoint(p: types.Position) ts.Point {
        return .{ .row = @intCast(p.line), .column = @intCast(p.character) };
    }

    pub fn update(self: *Self, change: types.ChangeEvent) !void {
        var doc = &self.doc;
        var tree: *ts.Tree = self.tree.?;
        var parser: *ts.Parser = self.parser;

        var edit = ts.InputEdit{
            .start_byte = @intCast(doc.posToIdx(change.range.?.start).?),
            .old_end_byte = @intCast(doc.posToIdx(change.range.?.end).?),
            .start_point = posToPoint(change.range.?.start),
            .old_end_point = posToPoint(change.range.?.end),
            .new_end_byte = 0,
            .new_end_point = .{ .row = 0, .column = 0 },
        };
        try doc.update(change);
        edit.new_end_byte = @intCast(edit.start_byte + change.text.len);
        edit.new_end_point = posToPoint(doc.idxToPos(edit.new_end_byte).?);

        tree.edit(edit);
        tree = parser.parseString(doc.text, tree).?;
        self.tree.?.destroy();
        self.tree = tree;
    }

    pub fn updateAll(self: *Self, changes: []const types.ChangeEvent) !void {
        // The LSP spec says that updates should be applied in the order that arrived.
        for (changes) |change| {
            try self.update(change);
        }
    }

    pub fn nodeText(self: Self, node: ts.Node) []const u8 {
        return self.doc.text[node.startByte()..node.endByte()];
    }
};
