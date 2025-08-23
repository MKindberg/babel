const std = @import("std");

const ServerInfo = @import("../plugins.zig").ServerInfo;

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    var activation_events = std.array_list.Managed([]const u8).init(allocator);
    defer activation_events.deinit();
    defer for (activation_events.items) |a| {
        allocator.free(a);
    };
    for (info.languages) |l| {
        const str = try std.fmt.allocPrint(allocator, "onLanguage:{s}", .{l});
        try activation_events.append(str);
    }

    const content = PackageJson{
        .name = info.name,
        .displayName = info.displayName orelse info.name,
        .description = info.description,
        .repository = info.repository orelse "",
        .publisher = info.publisher orelse std.posix.getenv("USER").?,
        .activationEvents = activation_events.items,
    };
    const filename = "editors/vscode/package.json";
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    const data = try std.json.Stringify.valueAlloc(allocator, content, .{ .whitespace = .indent_2 });
    defer allocator.free(data);
    _ = try file.write(data);
}

const PackageJson = struct {
    name: []const u8,
    displayName: []const u8,
    description: []const u8,
    repository: []const u8 = "",
    version: []const u8 = "0.0.1",
    publisher: []const u8,
    engines: struct { vscode: []const u8 = "^1.90.0" } = .{},
    categories: []const []const u8 = &.{"Language Server"},
    activationEvents: []const []const u8,
    main: []const u8 = "./extension.js",
    dependencies: struct { @"vscode-languageclient": []const u8 = "^9.0.1", @"@vscode/vsce": []const u8 = "2.15.0" } = .{},
};
