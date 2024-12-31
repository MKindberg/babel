const std = @import("std");
const builtin = @import("builtin");

pub const types = @import("types.zig");
pub const logger = @import("logger.zig");
pub const log = logger.log;
pub const Document = @import("document.zig").Document;
const rpc = @import("rpc.zig");
const Reader = @import("reader.zig").Reader;

pub fn Lsp(comptime StateType: type) type {
    return struct {
        const OpenDocumentCallback = fn (arena: std.mem.Allocator, context: *Context) void;
        const ChangeDocumentCallback = fn (arena: std.mem.Allocator, context: *Context, changes: []types.ChangeEvent) void;
        const SaveDocumentCallback = fn (arena: std.mem.Allocator, context: *Context) void;
        const CloseDocumentCallback = fn (arena: std.mem.Allocator, context: *Context) void;

        const HoverCallback = fn (arena: std.mem.Allocator, context: *Context, position: types.Position) ?[]const u8;
        const CodeActionCallback = fn (arena: std.mem.Allocator, context: *Context, range: types.Range) ?[]const types.Response.CodeAction.Result;

        const GoToDefinitionCallback = fn (arena: std.mem.Allocator, context: *Context, position: types.Position) ?types.Location;
        const GoToDeclarationCallback = fn (arena: std.mem.Allocator, context: *Context, position: types.Position) ?types.Location;
        const GoToTypeDefinitionCallback = fn (arena: std.mem.Allocator, context: *Context, position: types.Position) ?types.Location;
        const GoToImplementationCallback = fn (arena: std.mem.Allocator, context: *Context, position: types.Position) ?types.Location;
        const FindReferencesCallback = fn (arena: std.mem.Allocator, context: *Context, position: types.Position) ?[]const types.Location;

        const CompletionCallback = fn (arena: std.mem.Allocator, context: *Context, position: types.Position) ?types.CompletionList;

        const FormattingCallback = fn (arena: std.mem.Allocator, context: *Context, options: types.FormattingOptions) ?[]const types.TextEdit;
        const RangeFormattingCallback = fn (arena: std.mem.Allocator, context: *Context, range: types.Range, options: types.FormattingOptions) ?[]const types.TextEdit;

        callback_doc_open: ?*const OpenDocumentCallback = null,
        callback_doc_change: ?*const ChangeDocumentCallback = null,
        callback_doc_save: ?*const SaveDocumentCallback = null,
        callback_doc_close: ?*const CloseDocumentCallback = null,
        callback_hover: ?*const HoverCallback = null,
        callback_codeAction: ?*const CodeActionCallback = null,

        callback_goto_definition: ?*const GoToDefinitionCallback = null,
        callback_goto_declaration: ?*const GoToDeclarationCallback = null,
        callback_goto_type_definition: ?*const GoToTypeDefinitionCallback = null,
        callback_goto_implementation: ?*const GoToImplementationCallback = null,
        callback_find_references: ?*const FindReferencesCallback = null,

        callback_completion: ?*const CompletionCallback = null,

        callback_formatting: ?*const FormattingCallback = null,
        callback_range_formatting: ?*const RangeFormattingCallback = null,

        contexts: std.StringHashMap(Context),
        server_data: types.ServerData,
        allocator: std.mem.Allocator,

        server_state: ServerState = .Stopped,
        const ServerState = enum {
            Stopped,
            Initialize,
            Running,
            Shutdown,

            fn validMessage(self: ServerState, message_type: rpc.MethodType) bool {
                switch (self) {
                    .Stopped => return message_type == .initialize,
                    .Initialize => return message_type == .initialized or message_type == .exit,
                    .Shutdown => return message_type == .exit,
                    .Running => return message_type != .initialize and message_type != .initialized,
                }
            }
        };

        pub const Context = struct {
            server: *Lsp(StateType),
            document: Document,
            state: ?StateType,
        };

        const RunState = enum {
            Run,
            ShutdownOk,
            ShutdownErr,
        };

        const Self = @This();
        pub fn init(allocator: std.mem.Allocator, server_data: types.ServerData) Self {
            return Self{ .allocator = allocator, .server_data = server_data, .contexts = std.StringHashMap(Context).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            var it = self.contexts.iterator();
            while (it.next()) |i| {
                i.value_ptr.document.deinit();
            }
            self.contexts.deinit();
        }

        pub fn registerDocOpenCallback(self: *Self, callback: *const OpenDocumentCallback) void {
            self.callback_doc_open = callback;
            logger.trace("Registered open doc callback", .{});
        }
        pub fn registerDocChangeCallback(self: *Self, callback: *const ChangeDocumentCallback) void {
            self.callback_doc_change = callback;
            logger.trace("Registered change doc callback", .{});
        }
        pub fn registerDocSaveCallback(self: *Self, callback: *const SaveDocumentCallback) void {
            self.callback_doc_save = callback;
            self.server_data.capabilities.textDocumentSync.save = true;
            logger.trace("Registered save doc callback", .{});
        }
        pub fn registerDocCloseCallback(self: *Self, callback: *const CloseDocumentCallback) void {
            self.callback_doc_close = callback;
            logger.trace("Registered close doc callback", .{});
        }
        pub fn registerHoverCallback(self: *Self, callback: *const HoverCallback) void {
            self.callback_hover = callback;
            self.server_data.capabilities.hoverProvider = true;
            logger.trace("Registered hover callback", .{});
        }
        pub fn registerCodeActionCallback(self: *Self, callback: *const CodeActionCallback) void {
            self.callback_codeAction = callback;
            self.server_data.capabilities.codeActionProvider = true;
            logger.trace("Registered code action callback", .{});
        }
        pub fn registerGoToDefinitionCallback(self: *Self, callback: *const GoToDefinitionCallback) void {
            self.callback_goto_definition = callback;
            self.server_data.capabilities.definitionProvider = true;
            logger.trace("Registered go to definition callback", .{});
        }
        pub fn registerGoToDeclarationCallback(self: *Self, callback: *const GoToDeclarationCallback) void {
            self.callback_goto_declaration = callback;
            self.server_data.capabilities.declarationProvider = true;
            logger.trace("Registered go to declaration callback", .{});
        }
        pub fn registerGoToTypeDefinitionCallback(self: *Self, callback: *const GoToTypeDefinitionCallback) void {
            self.callback_goto_type_definition = callback;
            self.server_data.capabilities.typeDefinitionProvider = true;
            logger.trace("Registered go to type definition callback", .{});
        }
        pub fn registerGoToImplementationCallback(self: *Self, callback: *const GoToImplementationCallback) void {
            self.callback_goto_implementation = callback;
            self.server_data.capabilities.implementationProvider = true;
            logger.trace("Registered go to implementation callback", .{});
        }
        pub fn registerFindReferencesCallback(self: *Self, callback: *const FindReferencesCallback) void {
            self.callback_find_references = callback;
            self.server_data.capabilities.referencesProvider = true;
            logger.trace("Registered find references callback", .{});
        }
        pub fn registerCompletionCallback(self: *Self, callback: *const CompletionCallback) void {
            self.callback_completion = callback;
            self.server_data.capabilities.completionProvider = .{};
            logger.trace("Registered completion callback", .{});
        }
        pub fn registerFormattingCallback(self: *Self, callback: *const FormattingCallback) void {
            self.callback_formatting = callback;
            self.server_data.capabilities.documentFormattingProvider = true;
            logger.trace("Registered formatting callback", .{});
        }
        pub fn registerRangeFormattingCallback(self: *Self, callback: *const RangeFormattingCallback) void {
            self.callback_range_formatting = callback;
            self.server_data.capabilities.documentRangeFormattingProvider = true;
            logger.trace("Registered range formatting callback", .{});
        }

        pub fn start(self: *Self) !u8 {
            const stdin = std.io.getStdIn().reader();
            var reader = Reader.init(self.allocator, stdin);
            defer reader.deinit();

            var header = std.ArrayList(u8).init(self.allocator);
            defer header.deinit();
            var content = std.ArrayList(u8).init(self.allocator);
            defer content.deinit();

            var run_state = RunState.Run;
            while (run_state == RunState.Run) {
                logger.trace("Waiting for header", .{});
                _ = try reader.readUntilDelimiterOrEof(header.writer(), "\r\n\r\n");

                const content_len_str = "Content-Length: ";
                const content_len = if (std.mem.indexOf(u8, header.items, content_len_str)) |idx|
                    try std.fmt.parseInt(usize, header.items[idx + content_len_str.len ..], 10)
                else {
                    std.log.warn("Content-Length not found in header\n", .{});
                    break;
                };
                header.clearRetainingCapacity();

                const bytes_read = try reader.readN(content.writer(), content_len);
                if (bytes_read != content_len) {
                    break;
                }
                defer content.clearRetainingCapacity();

                const decoded = rpc.decodeMessage(self.allocator, content.items) catch |e| {
                    std.log.warn("Failed to decode message: {any}\n", .{e});
                    continue;
                };
                run_state = try self.handleMessage(self.allocator, decoded);
            }
            return @intFromBool(run_state == RunState.ShutdownOk);
        }

        pub fn writeResponse(self: Self, allocator: std.mem.Allocator, msg: anytype) !void {
            if (self.server_state != .Running and @TypeOf(msg) != types.Response.Error) {
                std.log.err("Cannot send message when server not in running state", .{});
                return;
            }
            try writeResponseInternal(allocator, msg);
        }

        fn handleMessage(self: *Self, allocator: std.mem.Allocator, msg: rpc.DecodedMessage) !RunState {
            logger.trace("Received request: {s}", .{msg.method.toString()});

            if (!self.server_state.validMessage(msg.method)) {
                switch (self.server_state) {
                    .Stopped => try self.replyInvalidRequest(allocator, msg.content, types.ErrorCode.ServerNotInitialized, "Server not initialized"),
                    .Initialize => try self.replyInvalidRequest(allocator, msg.content, types.ErrorCode.ServerNotInitialized, "Server initializing"),
                    .Shutdown => try self.replyInvalidRequest(allocator, msg.content, types.ErrorCode.InvalidRequest, "Server shutting down"),
                    .Running => try self.replyInvalidRequest(allocator, msg.content, types.ErrorCode.ServerNotInitialized, "Server already running"),
                }
                return RunState.Run;
            }

            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            switch (msg.method) {
                rpc.MethodType.initialize => {
                    if (!self.server_data.capabilities.textDocumentSync.openClose) @panic("TextDocumentSync.OpenClose must be true");
                    try self.handleInitialize(allocator, msg.content, self.server_data);
                    self.server_state = .Initialize;
                },
                rpc.MethodType.initialized => {
                    self.server_state = .Running;
                },
                rpc.MethodType.@"textDocument/didOpen" => {
                    const parsed = try std.json.parseFromSliceLeaky(types.Notification.DidOpenTextDocument, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });

                    const params = parsed.params;
                    try openDocument(self, params.textDocument.uri, params.textDocument.languageId, params.textDocument.text);

                    if (self.callback_doc_open) |callback| {
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(arena.allocator(), context);
                    }
                },
                rpc.MethodType.@"textDocument/didChange" => {
                    const parsed = try std.json.parseFromSliceLeaky(types.Notification.DidChangeTextDocument, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });

                    const params = parsed.params;
                    for (params.contentChanges) |change| {
                        try updateDocument(self, params.textDocument.uri, change.text, change.range);
                    }

                    if (self.callback_doc_change) |callback| {
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(arena.allocator(), context, params.contentChanges);
                    }
                },
                rpc.MethodType.@"textDocument/didSave" => {
                    const parsed = try std.json.parseFromSliceLeaky(types.Notification.DidSaveTextDocument, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });

                    const params = parsed.params;
                    if (self.callback_doc_save) |callback| {
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(arena.allocator(), context);
                    }
                },
                rpc.MethodType.@"textDocument/didClose" => {
                    const parsed = try std.json.parseFromSliceLeaky(types.Notification.DidCloseTextDocument, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });

                    const params = parsed.params;

                    if (self.callback_doc_close) |callback| {
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(arena.allocator(), context);
                    }

                    closeDocument(self, params.textDocument.uri);
                },
                rpc.MethodType.@"textDocument/hover" => {
                    if (self.callback_hover) |callback| {
                        const parsed = try std.json.parseFromSliceLeaky(types.Request.PositionRequest, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });

                        const params = parsed.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(arena.allocator(), context, params.position)) |message|
                            types.Response.Hover.init(parsed.id, message)
                        else
                            types.Response.Hover{ .id = parsed.id };
                        try self.writeResponse(allocator, response);
                    }
                },
                rpc.MethodType.@"textDocument/codeAction" => {
                    if (self.callback_codeAction) |callback| {
                        const parsed = try std.json.parseFromSliceLeaky(types.Request.CodeAction, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });

                        const params = parsed.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(arena.allocator(), context, params.range)) |results|
                            types.Response.CodeAction{ .id = parsed.id, .result = results }
                        else
                            types.Response.CodeAction{ .id = parsed.id };
                        try self.writeResponse(allocator, response);
                    }
                },
                rpc.MethodType.@"textDocument/declaration" => {
                    if (self.callback_goto_declaration) |callback| {
                        try self.handleGoTo(msg, callback);
                    }
                },
                rpc.MethodType.@"textDocument/definition" => {
                    if (self.callback_goto_definition) |callback| {
                        try self.handleGoTo(msg, callback);
                    }
                },
                rpc.MethodType.@"textDocument/typeDefinition" => {
                    if (self.callback_goto_type_definition) |callback| {
                        try self.handleGoTo(msg, callback);
                    }
                },
                rpc.MethodType.@"textDocument/implementation" => {
                    if (self.callback_goto_implementation) |callback| {
                        try self.handleGoTo(msg, callback);
                    }
                },
                rpc.MethodType.@"textDocument/references" => {
                    if (self.callback_find_references) |callback| {
                        const parsed = try std.json.parseFromSliceLeaky(types.Request.PositionRequest, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });
                        const params = parsed.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(arena.allocator(), context, params.position)) |locations|
                            types.Response.MultiLocationResponse.init(parsed.id, locations)
                        else
                            types.Response.MultiLocationResponse{ .id = parsed.id };
                        try self.writeResponse(arena.allocator(), response);
                    }
                },
                rpc.MethodType.@"$/setTrace" => {
                    const parsed = try std.json.parseFromSliceLeaky(types.Notification.SetTrace, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });
                    logger.trace_value = parsed.params.value;
                },
                rpc.MethodType.@"$/cancelRequest" => {
                    // No way to cancel a request in a single threaded server
                },
                rpc.MethodType.@"textDocument/completion" => {
                    if (self.callback_completion) |callback| {
                        const parsed = try std.json.parseFromSliceLeaky(types.Request.Completion, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });
                        const params = parsed.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(arena.allocator(), context, params.position)) |items|
                            types.Response.Completion{ .id = parsed.id, .result = items }
                        else
                            types.Response.Completion{ .id = parsed.id };
                        try self.writeResponse(arena.allocator(), response);
                    }
                },
                rpc.MethodType.@"textDocument/formatting" => {
                    if (self.callback_formatting) |callback| {
                        const parsed = try std.json.parseFromSliceLeaky(types.Request.Formatting, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });
                        const params = parsed.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(arena.allocator(), context, params.options)) |items|
                            types.Response.Formatting{ .id = parsed.id, .result = items }
                        else
                            types.Response.Formatting{ .id = parsed.id };
                        try self.writeResponse(arena.allocator(), response);
                    }
                },
                rpc.MethodType.@"textDocument/rangeFormatting" => {
                    if (self.callback_range_formatting) |callback| {
                        const parsed = try std.json.parseFromSliceLeaky(types.Request.RangeFormatting, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });
                        const params = parsed.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(arena.allocator(), context, params.range, params.options)) |items|
                            types.Response.Formatting{ .id = parsed.id, .result = items }
                        else
                            types.Response.Formatting{ .id = parsed.id };
                        try self.writeResponse(arena.allocator(), response);
                    }
                },
                rpc.MethodType.shutdown => {
                    try self.handleShutdown(allocator, msg.content);
                    self.server_state = .Shutdown;
                },
                rpc.MethodType.exit => {
                    if (self.server_state == .Shutdown) {
                        return RunState.ShutdownOk;
                    }
                    return RunState.ShutdownErr;
                },
            }
            return RunState.Run;
        }

        fn handleGoTo(self: *Self, msg: rpc.DecodedMessage, callback: anytype) !void {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const parsed = try std.json.parseFromSliceLeaky(types.Request.PositionRequest, arena.allocator(), msg.content, .{ .ignore_unknown_fields = true });
            const params = parsed.params;
            const context = self.contexts.getPtr(params.textDocument.uri).?;
            const response = if (callback(arena.allocator(), context, params.position)) |location|
                types.Response.LocationResponse.init(parsed.id, location)
            else
                types.Response.LocationResponse{ .id = parsed.id };
            try self.writeResponse(arena.allocator(), response);
        }

        fn handleShutdown(_: Self, allocator: std.mem.Allocator, msg: []const u8) !void {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const parsed = try std.json.parseFromSliceLeaky(types.Request.Shutdown, arena.allocator(), msg, .{ .ignore_unknown_fields = true });
            const response = types.Response.Shutdown.init(parsed);
            try writeResponseInternal(allocator, response);
        }

        fn replyInvalidRequest(_: Self, allocator: std.mem.Allocator, msg: []const u8, error_code: types.ErrorCode, error_message: []const u8) !void {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const request = std.json.parseFromSliceLeaky(types.Request.Request, arena.allocator(), msg, .{ .ignore_unknown_fields = true }) catch return;

            const reply = types.Response.Error.init(request.id, error_code, error_message);
            try writeResponseInternal(allocator, reply);
        }

        fn handleInitialize(_: Self, allocator: std.mem.Allocator, msg: []const u8, server_data: types.ServerData) !void {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();
            const request = try std.json.parseFromSliceLeaky(types.Request.Initialize, arena.allocator(), msg, .{ .ignore_unknown_fields = true });

            if (request.params.clientInfo) |client_info| {
                logger.trace("Connected to {s} {s}", .{ client_info.name, client_info.version });
            } else {
                logger.trace("Connected to unknown server", .{});
            }

            if (request.params.trace) |trace| {
                logger.trace_value = trace;
            }

            const response_msg = types.Response.Initialize.init(request.id, server_data);

            try writeResponseInternal(allocator, response_msg);
        }

        fn openDocument(self: *Self, name: []const u8, language: []const u8, content: []const u8) !void {
            const context = Context{ .document = try Document.init(self.allocator, name, language, content), .state = null, .server = self };

            try self.contexts.put(context.document.uri, context);
        }

        fn closeDocument(self: *Self, name: []const u8) void {
            const entry = self.contexts.fetchRemove(name);
            entry.?.value.document.deinit();
        }

        fn updateDocument(self: *Self, name: []const u8, text: []const u8, range: types.Range) !void {
            var context = self.contexts.getPtr(name).?;
            try context.document.update(text, range);
        }
    };
}
pub fn writeResponseInternal(allocator: std.mem.Allocator, msg: anytype) !void {
    const response = try rpc.encodeMessage(allocator, msg);
    defer response.deinit();

    const writer = std.io.getStdOut().writer();
    _ = try writer.write(response.items);
}

// Tests

fn sendInitialize(server: *Lsp(void)) !void {
    if (!builtin.is_test) @compileError(@src().fn_name ++ " is only for testing");

    var msg = std.ArrayList(u8).init(std.testing.allocator);
    defer msg.deinit();

    const init_request = types.Request.Initialize{ .id = 0, .params = .{} };
    try std.json.stringify(init_request, .{}, msg.writer());
    const decoded = try rpc.decodeMessage(std.testing.allocator, msg.items);

    _ = try server.handleMessage(std.testing.allocator, decoded);
    try std.testing.expectEqual(server.server_state, .Initialize);
}

fn sendInitialized(server: *Lsp(void)) !void {
    if (!builtin.is_test) @compileError(@src().fn_name ++ " is only for testing");

    const decoded = rpc.DecodedMessage{ .method = rpc.MethodType.initialized };

    _ = try server.handleMessage(std.testing.allocator, decoded);
    try std.testing.expectEqual(server.server_state, .Running);
}

fn startServer(server: *Lsp(void)) !void {
    if (!builtin.is_test) @compileError(@src().fn_name ++ " is only for testing");
    try sendInitialize(server);
    try sendInitialized(server);
}

test "Initialize" {
    var server = Lsp(void).init(std.testing.allocator, .{ .serverInfo = .{ .name = "testing", .version = "1" } });
    defer server.deinit();
    try sendInitialize(&server);
}

test "Initialized" {
    var server = Lsp(void).init(std.testing.allocator, .{});
    defer server.deinit();
    try startServer(&server);
}
