const std = @import("std");

pub fn diff(allocator: std.mem.Allocator, old: []const u8, new: []const u8) !std.ArrayList(Edit) {
    var arr = try shortestEdit(allocator, old, new);
    defer {
        for (arr.items) |a| allocator.free(a);
        arr.deinit(allocator);
    }
    const edits = try backtrack(allocator, old, new, arr);
    return edits;
}

fn get(arr: []isize, i: isize) isize {
    if (i >= 0) return arr[@intCast(i)];
    return arr[arr.len - @as(usize, @intCast(-i))];
}
fn set(arr: *[]isize, i: isize, val: isize) void {
    if (i >= 0) {
        arr.*[@intCast(i)] = val;
    } else {
        arr.*[arr.len - @as(usize, @intCast(-i))] = val;
    }
}
fn shortestEdit(allocator: std.mem.Allocator, old: []const u8, new: []const u8) !std.ArrayList([]isize) {
    const n = old.len;
    const m = new.len;
    const max = n + m;
    var v = try allocator.alloc(isize, 2 * max + 1);
    defer allocator.free(v);
    @memset(v, 0);
    var trace = std.ArrayList([]isize).empty;
    var d: isize = 0;
    while (d < max + 1) : (d += 1) {
        try trace.append(allocator, try allocator.dupe(isize, v));
        var k: isize = -d;
        while (k < d + 1) : (k += 2) {
            var x: isize = 0;
            var y: isize = 0;
            if (k == -d or (k != d and get(v, k - 1) < get(v, k + 1))) {
                x = get(v, k + 1);
            } else {
                x = get(v, k - 1) + 1;
            }
            y = x - k;
            while (x < n and y < m and old[@intCast(x)] == new[@intCast(y)]) {
                x += 1;
                y += 1;
            }
            set(&v, k, x);
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

fn backtrack(allocator: std.mem.Allocator, old: []const u8, new: []const u8, trace: std.ArrayList([]isize)) !std.ArrayList(Edit) {
    var x: isize = @intCast(old.len);
    var y: isize = @intCast(new.len);
    var edits = std.ArrayList(Edit).empty;

    var i: isize = @as(isize, @intCast(trace.items.len)) - 1;
    while (i >= 0) : (i -= 1) {
        const v = trace.items[@intCast(i)];
        const k = x - y;
        const prev_k = if (k == -i or (k != i and get(v, k - 1) < get(v, k + 1))) k + 1 else k - 1;

        const prev_x = get(v, prev_k);
        const prev_y = prev_x - prev_k;
        while (x > prev_x and y > prev_y) {
            x = x - 1;
            y = y - 1;
            try edits.append(allocator, .Equal);
        }
        if (i > 0) {
            if (x == prev_x) {
                if (edits.getLastOrNull()) |e| {
                    if (e == .Insert) {
                        edits.items[edits.items.len - 1].Insert.start -= 1;
                    } else {
                        try edits.append(allocator, .{ .Insert = .{ .start = @intCast(prev_y), .end = @intCast(prev_y + 1), .idx = @intCast(prev_x) } });
                    }
                }
            } else if (y == prev_y) {
                if (edits.getLastOrNull()) |e| {
                    if (e == .Delete) {
                        edits.items[edits.items.len - 1].Delete.start -= 1;
                    } else {
                        try edits.append(allocator, .{ .Delete = .{ .start = @intCast(prev_x), .end = @intCast(prev_x + 1) } });
                    }
                }
            }
            x = prev_x;
            y = prev_y;
        }
    }
    return edits;
}
