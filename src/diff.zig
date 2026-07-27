const std = @import("std");

pub fn diff(
    allocator: std.mem.Allocator,
    old: []const u8,
    new: []const u8,
) !std.ArrayList(Edit) {
    var arr = try shortestEdit(allocator, old, new);
    defer {
        for (arr.items) |a| allocator.free(a);
        arr.deinit(allocator);
    }
    const edits = try backtrack(allocator, old, new, arr.items);
    return edits;
}

fn shortestEdit(
    allocator: std.mem.Allocator,
    old: []const u8,
    new: []const u8,
) !std.ArrayList([]isize) {
    const n = old.len;
    const m = new.len;
    const max = n + m;
    const offset: isize = @intCast(max);

    var v = try allocator.alloc(isize, 2 * max + 1);
    defer allocator.free(v);
    @memset(v, 0);

    var trace = std.ArrayList([]isize).empty;
    errdefer trace.deinit(allocator);

    var d: isize = 0;
    while (d < max + 1) : (d += 1) {
        try trace.append(allocator, try allocator.dupe(isize, v));
        var k: isize = -d;
        while (k < d + 1) : (k += 2) {
            var x = if (k == -d or (k != d and v[@intCast(k - 1 + offset)] < v[@intCast(k + 1 + offset)]))
                v[@intCast(k + 1 + offset)]
            else
                v[@intCast(k - 1 + offset)] + 1;
            var y = x - k;

            while (x < n and y < m and old[@intCast(x)] == new[@intCast(y)]) {
                x += 1;
                y += 1;
            }
            v[@intCast(k + offset)] = x;
            if (x >= n and y >= m) {
                return trace;
            }
        }
    }
    unreachable;
}

const Edit = union(enum) {
    Insert: struct { start: usize, end: usize, idx: usize },
    Equal,
    Delete: struct { start: usize, end: usize },
};

fn backtrack(
    allocator: std.mem.Allocator,
    old: []const u8,
    new: []const u8,
    trace: []const []const isize,
) !std.ArrayList(Edit) {
    var x: isize = @intCast(old.len);
    var y: isize = @intCast(new.len);
    const offset = x + y;
    var edits = std.ArrayList(Edit).empty;

    var i: isize = @as(isize, @intCast(trace.len)) - 1;
    while (i >= 0) : (i -= 1) {
        const v = trace[@intCast(i)];
        const k = x - y;
        const prev_k = if (k == -i or
            (k != i and
                v[@intCast(k - 1 + offset)] < v[@intCast(k + 1 + offset)]))
            k + 1
        else
            k - 1;

        const prev_x = v[@intCast(prev_k + offset)];
        const prev_y = prev_x - prev_k;
        while (x > prev_x and y > prev_y) {
            x = x - 1;
            y = y - 1;
            try edits.append(allocator, .Equal);
        }
        if (i > 0) {
            if (x == prev_x) {
                if (edits.items.len > 0 and edits.getLast() == .Insert) {
                    edits.items[edits.items.len - 1].Insert.start -= 1;
                } else {
                    try edits.append(allocator, .{ .Insert = .{
                        .start = @intCast(prev_y),
                        .end = @intCast(prev_y + 1),
                        .idx = @intCast(prev_x),
                    } });
                }
            } else if (y == prev_y) {
                if (edits.items.len > 0 and edits.getLast() == .Delete) {
                    edits.items[edits.items.len - 1].Delete.start -= 1;
                } else {
                    try edits.append(allocator, .{ .Delete = .{
                        .start = @intCast(prev_x),
                        .end = @intCast(prev_x + 1),
                    } });
                }
            }
            x = prev_x;
            y = prev_y;
        }
    }
    return edits;
}
