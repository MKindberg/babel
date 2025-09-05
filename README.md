# babel
A framework for writing, or at least prototyping, language servers in Zig.
It allows you to register callbacks that will be called when notifications or
requests are received. In addition to this it will also keep track of and automatically
update the documents being edited.

## Usage

### Creating the server
```zig
const std = @import("std");
const lsp = @import("lsp");
const builtin = @import("builtin");

// Set the global log function to lsp.log in order to use the lsp protocol
// for logging
pub const std_options = std.Options{ .log_level = if (builtin.mode == .Debug) .debug else .info, .logFn = lsp.log };

// File specific state
const State = struct {
    fn init() State {
        return .{};
    }
};
// Create an alias for the server type. An instance of State will be available
// in each callback.
const Lsp = lsp.Lsp(State);

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // Information about the server that will be passed to the client.
    const server_data = lsp.types.ServerData{
        .serverInfo = .{ .name = "server_name", .version = "0.1.0" },
    };

    var server = Lsp.init(allocator, server_data);
    defer server.deinit();

    // Register wanted callbacks. They need to be registered before the server starts.
    server.registerDocOpenCallback(handleOpenDoc);
    server.registerDocCloseCallback(handleCloseDoc);
    server.registerDocChangeCallback(handleChangeDoc);
    server.registerHoverCallback(handleHover);

    // Start the server, it will run until it gets a shutdown signal from the client.
    const res = server.start();

    return res;
}

// All callbacks take one parameter which is a struct containing an arena
// allocator that's freed when the callback returns, the current document
// and state, and any additional data that might be useful.
// The return values are just aliases for regular types and it doesn't matter
// if the alias or real type is used.
fn handleOpenDoc(p: Lsp.OpenDocumentParameters) Lsp.CloseDocumentReturn {
    std.log.info("Opened {s}", .{p.context.document.uri});
    // The file local state should be initialized when a document is opened.
    p.context.state = State.init();
}

// Most resources related to the document will be freed automatically, but the
// user provided state needs to be handled manually.
fn handleCloseDoc(p: Lsp.CloseDocumentParameters) Lsp.CloseDocumentReturn {
    // Deinitialize the state when the file is closed.
    p.context.state.deinit();
}

// An example of additional data that can be included in the parameters struct
// is the changes that triggered a changeDocument event.
fn handleChangeDoc(p: Lsp.ChangeDocumentParameters) void {
    for (p.changes) |change| {
        std.log.info("New text: {s}", .{change.text});
    }
}

// Callbacks handling requests will have a non-void return value that will
// be sent back to the client after the callback returns.
fn handleHover(p: Lsp.HoverParameters) ?[]const u8 {
    // A document provides some helper function that can be useful.
    std.log.info("Hovering the word {s} at {d}:{d}", .{ p.context.document.getWord(p.position, "\n .,"), p.position.line, p.position.character });
}
```

### Build the server
```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Build the server
    const exe = b.addExecutable(.{
        .name = "server_name",
        .root_source_file = b.path("src/main.zig"),
    });

    // Add the dependency towards babel
    const babel = b.dependency("babel", .{});

    // Allow the server to import the lsp module from babel
    const lsp = babel.module("lsp");
    exe.root_module.addImport("lsp", lsp);

    b.installArtifact(exe);
}
```
