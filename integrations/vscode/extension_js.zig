const std = @import("std");

const ServerInfo = @import("../plugins.zig").ServerInfo;

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    var document_selector = std.array_list.Managed(u8).init(allocator);
    defer document_selector.deinit();
    for (info.languages) |l| {
        try document_selector.writer().print("      {{ scheme: \"file\", language: \"{s}\" }},\n", .{l});
    }

    const content = try std.fmt.allocPrint(allocator, extension_js, .{
        .name = info.name,
        .selector = document_selector.items,
        .displayName = info.displayName orelse info.name,
    });
    defer allocator.free(content);
    const filename = "editors/vscode/extension.js";
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(content);
}

const extension_js =
    \\const vscode = require('vscode');
    \\const {{ LanguageClient, TransportKind }} = require('vscode-languageclient/node');
    \\let client;
    \\function activate(context) {{
    \\  let serverOptions = {{
    \\    run: {{ command: "{[name]s}", transport: TransportKind.stdio }},
    \\  }};
    \\  let clientOptions = {{
    \\    documentSelector: [
    \\{[selector]s}
    \\    ],
    \\  }};
    \\  client = new LanguageClient(
    \\    "{[name]s}",
    \\    "{[displayName]s}",
    \\    serverOptions,
    \\    clientOptions
    \\  );
    \\  return client.start();
    \\}}
    \\function deactivate() {{
    \\  if (!client || !client.needsStop) {{
    \\    return undefined;
    \\  }}
    \\  return client.stop();
    \\}}
    \\module.exports = {{
    \\  activate,
    \\  deactivate
    \\}}
;
