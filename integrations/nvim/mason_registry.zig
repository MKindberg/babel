const std = @import("std");

const ServerInfo = @import("../plugins.zig").ServerInfo;

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    const version = info.version orelse try getVersion(allocator) orelse @panic("Version is mandatory for mason registry");
    defer if (info.version == null) allocator.free(version);

    const source_id: []const u8 = id: {
        if (info.source_id) |id| {
            break :id try allocator.dupe(u8, id);
        } else {
            @panic("ServerInfo must contain either source_id for mason registry");
        }
    };
    defer allocator.free(source_id);

    var languages: std.Io.Writer.Allocating = .init(allocator);
    defer languages.deinit();
    for (info.languages) |l| {
        try languages.writer.print("\"{s}\", ", .{l});
    }
    if (languages.written().len > 1) languages.writer.undo(2);

    const content = try std.fmt.allocPrint(allocator, mason_registry, .{
        .name = info.name,
        .description = info.description,
        .homepage = info.homepage orelse info.repository orelse "",
        .license = info.license orelse "",
        .languages = languages.written(),
        .source_id = source_id,
        .version = version,
    });

    var registry_file = try std.fs.cwd().createFile("editors/nvim/registry.json", .{});
    defer registry_file.close();

    _ = try registry_file.write(content);
}

fn getVersion(allocator: std.mem.Allocator) !?[]const u8 {
    const res = try std.process.Child.run(.{ .allocator = allocator, .argv = &[_][]const u8{ "git", "tag", "-l" } });
    defer allocator.free(res.stdout);
    defer allocator.free(res.stderr);
    const stdout = std.mem.trim(u8, res.stdout, "\n");
    var it = std.mem.splitBackwardsScalar(u8, stdout, '\n');
    const version = while (it.next()) |tag| {
        if (tag[0] != 'v') continue;
        break tag;
    } else return null;

    return allocator.dupe(u8, version) catch unreachable;
}

const mason_registry =
    \\[
    \\  {{
    \\    "name": "{[name]s}",
    \\    "description": "{[description]s}",
    \\    "homepage": "{[homepage]s}",
    \\    "licenses": [ "{[license]s}" ],
    \\    "languages": [{[languages]s}],
    \\    "categories": [
    \\      "LSP"
    \\    ],
    \\    "source": {{
    \\      "id": "{[source_id]s}@{[version]s}",
    \\      "asset": [
    \\        {{
    \\          "target": "linux_x64",
    \\          "file": "{[name]s}",
    \\          "bin": "{[name]s}"
    \\        }}
    \\      ]
    \\    }},
    \\    "bin": {{
    \\      "{[name]s}": "{{{{source.asset.bin}}}}"
    \\    }}
    \\  }}
    \\]
;
