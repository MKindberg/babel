const std = @import("std");
const builtin = @import("builtin");

pub const types = @import("types.zig");
pub const logger = @import("logger.zig");
pub const log = logger.log;
pub const fileLog = logger.fileLog;
pub const Document = @import("document.zig").Document;
const rpc = @import("rpc.zig");
const reader = @import("reader.zig");

pub const LspSettings = struct {
    /// A modifiable optional of this type is passed to each callback in the file context.
    state_type: ?type = null,
    /// How text changes should be passed from client to server.
    document_sync: types.TextDocumentSyncKind = .Incremental,
    /// If the full text should be passed on every save, useful when document_sync = .None
    full_text_on_save: bool = false,
    /// If the document should be updated automatically before the docChange callback is triggered.
    update_doc_on_change: bool = true,
};

const MessageQueue = std.ArrayList(struct {
    decoded: rpc.MethodType,
    arena: std.heap.ArenaAllocator,
});

fn CreateContext(comptime settings: LspSettings) type {
    var fields: []const std.builtin.Type.StructField = &.{
        .{ .name = "server", .type = *Lsp(settings), .default_value_ptr = null, .is_comptime = false, .alignment = @alignOf(Lsp(settings)) },
        .{ .name = "document", .type = Document, .default_value_ptr = null, .is_comptime = false, .alignment = @alignOf(Document) },
    };
    if (settings.state_type) |t| {
        fields = fields ++ .{std.builtin.Type.StructField{ .name = "state", .type = ?t, .default_value_ptr = &@as(?t, null), .is_comptime = false, .alignment = @alignOf(?t) }};
    }

    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

pub var test_input_file: ?[]const u8 = null;
pub var test_output_file: ?[]const u8 = null;

pub fn Lsp(comptime settings: LspSettings) type {
    return struct {
        pub const OpenDocumentParameters = struct { arena: std.mem.Allocator, context: *Context };
        pub const OpenDocumentReturn = void;
        const OpenDocumentCallback = fn (_: OpenDocumentParameters) OpenDocumentReturn;

        pub const ChangeDocumentParameters = struct { arena: std.mem.Allocator, context: *Context, changes: []const types.ChangeEvent };
        pub const ChangeDocumentReturn = void;
        const ChangeDocumentCallback = fn (_: ChangeDocumentParameters) ChangeDocumentReturn;

        pub const SaveDocumentParameters = struct { arena: std.mem.Allocator, context: *Context };
        pub const SaveDocumentReturn = void;
        const SaveDocumentCallback = fn (_: SaveDocumentParameters) SaveDocumentReturn;

        pub const CloseDocumentParameters = struct { arena: std.mem.Allocator, context: *Context };
        pub const CloseDocumentReturn = void;
        const CloseDocumentCallback = fn (_: CloseDocumentParameters) CloseDocumentReturn;

        pub const HoverParameters = struct { arena: std.mem.Allocator, context: *Context, position: types.Position };
        pub const HoverReturn = ?[]const u8;
        const HoverCallback = fn (_: HoverParameters) HoverReturn;

        pub const CodeActionParameters = struct { arena: std.mem.Allocator, context: *Context, range: types.Range };
        pub const CodeActionReturn = ?[]const types.Response.CodeAction.Result;
        const CodeActionCallback = fn (_: CodeActionParameters) CodeActionReturn;

        pub const GoToDefinitionParameters = struct { arena: std.mem.Allocator, context: *Context, position: types.Position };
        pub const GoToDefinitionReturn = ?types.Location;
        const GoToDefinitionCallback = fn (_: GoToDefinitionParameters) GoToDefinitionReturn;

        pub const GoToDeclarationParameters = struct { arena: std.mem.Allocator, context: *Context, position: types.Position };
        pub const GoToDeclarationReturn = ?types.Location;
        const GoToDeclarationCallback = fn (_: GoToDeclarationParameters) GoToDeclarationReturn;

        pub const GoToTypeDefinitionParameters = struct { arena: std.mem.Allocator, context: *Context, position: types.Position };
        pub const GoToTypeDefinitionReturn = ?types.Location;
        const GoToTypeDefinitionCallback = fn (_: GoToTypeDefinitionParameters) GoToTypeDefinitionReturn;

        pub const GoToImplementationParameters = struct { arena: std.mem.Allocator, context: *Context, position: types.Position };
        pub const GoToImplementationReturn = ?types.Location;
        const GoToImplementationCallback = fn (_: GoToImplementationParameters) GoToImplementationReturn;

        pub const FindReferencesParameters = struct { arena: std.mem.Allocator, context: *Context, position: types.Position };
        pub const FindReferencesReturn = ?[]const types.Location;
        const FindReferencesCallback = fn (_: FindReferencesParameters) FindReferencesReturn;

        pub const CompletionParameters = struct { arena: std.mem.Allocator, context: *Context, position: types.Position };
        pub const CompletionReturn = ?types.CompletionList;
        const CompletionCallback = fn (_: CompletionParameters) CompletionReturn;

        pub const FormattingParameters = struct { arena: std.mem.Allocator, context: *Context, options: types.FormattingOptions };
        pub const FormattingReturn = ?[]const types.TextEdit;
        const FormattingCallback = fn (_: FormattingParameters) FormattingReturn;

        pub const RangeFormattingParameters = struct { arena: std.mem.Allocator, context: *Context, range: types.Range, options: types.FormattingOptions };
        pub const RangeFormattingReturn = ?[]const types.TextEdit;
        const RangeFormattingCallback = fn (_: RangeFormattingParameters) RangeFormattingReturn;

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
        input_stream: *std.Io.Reader,
        output_stream: *std.Io.Writer,

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

        pub const Context = CreateContext(settings);

        const RunState = enum {
            Run,
            ShutdownOk,
            ShutdownErr,
        };

        const Self = @This();
        pub fn init(allocator: std.mem.Allocator, input_stream: *std.Io.Reader, output_stream: *std.Io.Writer, server_info: types.ServerInfo) Self {
            return Self{
                .allocator = allocator,
                .input_stream = input_stream,
                .output_stream = output_stream,
                .server_data = .{
                    .serverInfo = server_info,
                    .capabilities = .{ .textDocumentSync = .{
                        .change = settings.document_sync,
                    } },
                },
                .contexts = std.StringHashMap(Context).init(allocator),
            };
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
            std.log.debug("Registered open doc callback", .{});
        }
        pub fn registerDocChangeCallback(self: *Self, callback: *const ChangeDocumentCallback) void {
            self.callback_doc_change = callback;
            std.log.debug("Registered change doc callback", .{});
        }
        pub fn registerDocSaveCallback(self: *Self, callback: *const SaveDocumentCallback) void {
            self.callback_doc_save = callback;
            self.server_data.capabilities.textDocumentSync.save = .{ .includeText = settings.full_text_on_save };
            std.log.debug("Registered save doc callback", .{});
        }
        pub fn registerDocCloseCallback(self: *Self, callback: *const CloseDocumentCallback) void {
            self.callback_doc_close = callback;
            std.log.debug("Registered close doc callback", .{});
        }
        pub fn registerHoverCallback(self: *Self, callback: *const HoverCallback) void {
            self.callback_hover = callback;
            self.server_data.capabilities.hoverProvider = true;
            std.log.debug("Registered hover callback", .{});
        }
        pub fn registerCodeActionCallback(self: *Self, callback: *const CodeActionCallback) void {
            self.callback_codeAction = callback;
            self.server_data.capabilities.codeActionProvider = true;
            std.log.debug("Registered code action callback", .{});
        }
        pub fn registerGoToDefinitionCallback(self: *Self, callback: *const GoToDefinitionCallback) void {
            self.callback_goto_definition = callback;
            self.server_data.capabilities.definitionProvider = true;
            std.log.debug("Registered go to definition callback", .{});
        }
        pub fn registerGoToDeclarationCallback(self: *Self, callback: *const GoToDeclarationCallback) void {
            self.callback_goto_declaration = callback;
            self.server_data.capabilities.declarationProvider = true;
            std.log.debug("Registered go to declaration callback", .{});
        }
        pub fn registerGoToTypeDefinitionCallback(self: *Self, callback: *const GoToTypeDefinitionCallback) void {
            self.callback_goto_type_definition = callback;
            self.server_data.capabilities.typeDefinitionProvider = true;
            std.log.debug("Registered go to type definition callback", .{});
        }
        pub fn registerGoToImplementationCallback(self: *Self, callback: *const GoToImplementationCallback) void {
            self.callback_goto_implementation = callback;
            self.server_data.capabilities.implementationProvider = true;
            std.log.debug("Registered go to implementation callback", .{});
        }
        pub fn registerFindReferencesCallback(self: *Self, callback: *const FindReferencesCallback) void {
            self.callback_find_references = callback;
            self.server_data.capabilities.referencesProvider = true;
            std.log.debug("Registered find references callback", .{});
        }
        pub fn registerCompletionCallback(self: *Self, callback: *const CompletionCallback) void {
            self.callback_completion = callback;
            self.server_data.capabilities.completionProvider = .{};
            std.log.debug("Registered completion callback", .{});
        }
        pub fn registerFormattingCallback(self: *Self, callback: *const FormattingCallback) void {
            self.callback_formatting = callback;
            self.server_data.capabilities.documentFormattingProvider = true;
            std.log.debug("Registered formatting callback", .{});
        }
        pub fn registerRangeFormattingCallback(self: *Self, callback: *const RangeFormattingCallback) void {
            self.callback_range_formatting = callback;
            self.server_data.capabilities.documentRangeFormattingProvider = true;
            std.log.debug("Registered range formatting callback", .{});
        }

        pub fn start(self: *Self) !u8 {
            var header = std.Io.Writer.Allocating.init(self.allocator);
            defer header.deinit();
            var body = std.Io.Writer.Allocating.init(self.allocator);
            defer body.deinit();

            var message_queue = try MessageQueue.initCapacity(self.allocator, 16);
            defer message_queue.deinit(self.allocator);

            var run_state = RunState.Run;
            outer: while (run_state == RunState.Run) {
                while (message_queue.capacity > message_queue.items.len and
                    (message_queue.items.len == 0 or self.input_stream.peekByte() != error.EndOfStream))
                {
                    std.log.debug("Waiting for header", .{});
                    const read = try reader.readUntilDelimiterOrEof(self.input_stream, &header.writer, "\r\n\r\n");
                    if (read == 0) break;

                    const content_len_str = "Content-Length: ";
                    const content_len = if (std.mem.indexOf(u8, header.written(), content_len_str)) |idx|
                        try std.fmt.parseInt(usize, header.written()[idx + content_len_str.len ..], 10)
                    else {
                        std.log.warn("Content-Length not found in header\n'{s}'", .{header.written()});
                        break :outer;
                    };
                    header.clearRetainingCapacity();

                    const bytes_read = try self.input_stream.stream(&body.writer, std.Io.Limit.limited(content_len));
                    if (bytes_read != content_len) {
                        break;
                    }
                    var arena = std.heap.ArenaAllocator.init(self.allocator);
                    defer body.clearRetainingCapacity();

                    const decoded = rpc.decodeMessage(arena.allocator(), body.written()) catch |e| {
                        std.log.warn("Failed to decode message: {any}\n", .{e});
                        continue;
                    };
                    message_queue.appendAssumeCapacity(.{ .decoded = decoded, .arena = arena });
                }
                try filterMessages(self.allocator, self.output_stream, &message_queue);
                var message = message_queue.orderedRemove(0);
                defer message.arena.deinit();
                run_state = try self.handleMessage(message.arena.allocator(), message.decoded);
            }
            if (run_state == RunState.ShutdownOk) return 0;
            return 1;
        }

        pub fn writeResponse(self: Self, allocator: std.mem.Allocator, msg: anytype) !void {
            if (self.server_state != .Running and @TypeOf(msg) != types.Response.Error) {
                std.log.err("Cannot send message when server not in running state", .{});
                return;
            }
            try writeResponseInternal(allocator, self.output_stream, msg);
        }

        fn handleMessage(self: *Self, allocator: std.mem.Allocator, msg: rpc.MethodType) !RunState {
            std.log.debug("Received request: {s}", .{msg.toString()});

            if (!self.server_state.validMessage(msg)) {
                switch (self.server_state) {
                    .Stopped => try self.replyInvalidRequest(allocator, msg, types.ErrorCode.ServerNotInitialized, "Server not initialized"),
                    .Initialize => try self.replyInvalidRequest(allocator, msg, types.ErrorCode.ServerNotInitialized, "Server initializing"),
                    .Shutdown => try self.replyInvalidRequest(allocator, msg, types.ErrorCode.InvalidRequest, "Server shutting down"),
                    .Running => try self.replyInvalidRequest(allocator, msg, types.ErrorCode.ServerNotInitialized, "Server already running"),
                }
                return RunState.Run;
            }

            switch (msg) {
                rpc.MethodType.initialize => |request| {
                    if (!self.server_data.capabilities.textDocumentSync.openClose) @panic("TextDocumentSync.OpenClose must be true");
                    try self.handleInitialize(allocator, request, self.server_data);
                    self.server_state = .Initialize;
                },
                rpc.MethodType.initialized => {
                    self.server_state = .Running;
                },
                rpc.MethodType.@"textDocument/didOpen" => |notification| {
                    const params = notification.params;
                    try openDocument(self, params.textDocument.uri, params.textDocument.languageId, params.textDocument.text);

                    if (self.callback_doc_open) |callback| {
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(.{ .arena = allocator, .context = context });
                    }
                },
                rpc.MethodType.@"textDocument/didChange" => |notification| {
                    const params = notification.params;
                    const context = self.contexts.getPtr(params.textDocument.uri).?;
                    if (settings.update_doc_on_change) {
                        try context.document.updateAll(params.contentChanges);
                    }

                    if (self.callback_doc_change) |callback| {
                        callback(.{ .arena = allocator, .context = context, .changes = params.contentChanges });
                    }
                },
                rpc.MethodType.@"textDocument/didSave" => |notification| {
                    const params = notification.params;
                    if (self.callback_doc_save) |callback| {
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        if (notification.params.text) |text| {
                            try context.document.update(.{ .text = text, .range = null });
                        }
                        callback(.{ .arena = allocator, .context = context });
                    }
                },
                rpc.MethodType.@"textDocument/didClose" => |notification| {
                    const params = notification.params;

                    if (self.callback_doc_close) |callback| {
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(.{ .arena = allocator, .context = context });
                    }

                    closeDocument(self, params.textDocument.uri);
                },
                rpc.MethodType.@"textDocument/hover" => |request| {
                    if (self.callback_hover) |callback| {
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(.{ .arena = allocator, .context = context, .position = params.position })) |message|
                            types.Response.Hover.init(request.id, message)
                        else
                            types.Response.Hover{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    }
                },
                rpc.MethodType.@"textDocument/codeAction" => |request| {
                    if (self.callback_codeAction) |callback| {
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(.{ .arena = allocator, .context = context, .range = params.range })) |results|
                            types.Response.CodeAction{ .id = request.id, .result = results }
                        else
                            types.Response.CodeAction{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    }
                },
                rpc.MethodType.@"textDocument/declaration" => |request| {
                    if (self.callback_goto_declaration) |callback| {
                        try self.handleGoTo(allocator, request, callback);
                    }
                },
                rpc.MethodType.@"textDocument/definition" => |request| {
                    if (self.callback_goto_definition) |callback| {
                        try self.handleGoTo(allocator, request, callback);
                    }
                },
                rpc.MethodType.@"textDocument/typeDefinition" => |request| {
                    if (self.callback_goto_type_definition) |callback| {
                        try self.handleGoTo(allocator, request, callback);
                    }
                },
                rpc.MethodType.@"textDocument/implementation" => |request| {
                    if (self.callback_goto_implementation) |callback| {
                        try self.handleGoTo(allocator, request, callback);
                    }
                },
                rpc.MethodType.@"textDocument/references" => |request| {
                    if (self.callback_find_references) |callback| {
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(.{ .arena = allocator, .context = context, .position = params.position })) |locations|
                            types.Response.MultiLocationResponse.init(request.id, locations)
                        else
                            types.Response.MultiLocationResponse{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    }
                },
                rpc.MethodType.@"$/setTrace" => |notification| {
                    logger.trace_value = notification.params.value;
                },
                rpc.MethodType.@"$/cancelRequest" => {
                    // Cancel is handled earlier
                    unreachable;
                },
                rpc.MethodType.@"textDocument/completion" => |request| {
                    if (self.callback_completion) |callback| {
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(.{ .arena = allocator, .context = context, .position = params.position })) |items|
                            types.Response.Completion{ .id = request.id, .result = items }
                        else
                            types.Response.Completion{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    }
                },
                rpc.MethodType.@"textDocument/formatting" => |request| {
                    if (self.callback_formatting) |callback| {
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(.{ .arena = allocator, .context = context, .options = params.options })) |items|
                            types.Response.Formatting{ .id = request.id, .result = items }
                        else
                            types.Response.Formatting{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    }
                },
                rpc.MethodType.@"textDocument/rangeFormatting" => |request| {
                    if (self.callback_range_formatting) |callback| {
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(.{ .arena = allocator, .context = context, .range = params.range, .options = params.options })) |items|
                            types.Response.Formatting{ .id = request.id, .result = items }
                        else
                            types.Response.Formatting{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    }
                },
                rpc.MethodType.shutdown => |request| {
                    try self.handleShutdown(allocator, request);
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

        fn handleGoTo(self: *Self, alloc: std.mem.Allocator, request: types.Request.PositionRequest, callback: anytype) !void {
            const params = request.params;
            const context = self.contexts.getPtr(params.textDocument.uri).?;
            const response = if (callback(.{ .arena = alloc, .context = context, .position = params.position })) |location|
                types.Response.LocationResponse.init(request.id, location)
            else
                types.Response.LocationResponse{ .id = request.id };
            try self.writeResponse(alloc, response);
        }

        fn handleShutdown(self: Self, arena: std.mem.Allocator, request: types.Request.Shutdown) !void {
            const response = types.Response.Shutdown.init(request);
            try writeResponseInternal(arena, self.output_stream, response);
        }

        fn replyInvalidRequest(self: Self, arena: std.mem.Allocator, request: anytype, error_code: types.ErrorCode, error_message: []const u8) !void {
            if (@hasField(@TypeOf(request), "id")) {
                const reply = types.Response.Error.init(request.id, error_code, error_message);
                try writeResponseInternal(arena, self.output_stream, reply);
            }
        }

        fn handleInitialize(self: Self, arena: std.mem.Allocator, request: types.Request.Initialize, server_data: types.ServerData) !void {
            if (request.params.clientInfo) |client_info| {
                std.log.debug("Connected to {s} {s}", .{ client_info.name, client_info.version });
            } else {
                std.log.debug("Connected to unknown server", .{});
            }

            if (request.params.trace) |trace| {
                logger.trace_value = trace;
            }

            const response_msg = types.Response.Initialize.init(request.id, server_data);

            try writeResponseInternal(arena, self.output_stream, response_msg);
        }

        fn openDocument(self: *Self, name: []const u8, language: []const u8, content: []const u8) !void {
            const context =
                Context{ .document = try Document.init(self.allocator, name, language, content), .server = self };
            try self.contexts.put(context.document.uri, context);
        }

        fn closeDocument(self: *Self, name: []const u8) void {
            const entry = self.contexts.fetchRemove(name);
            entry.?.value.document.deinit();
        }

        fn updateDocument(self: *Self, name: []const u8, text: []const u8, range: ?types.Range) !void {
            var context = self.contexts.getPtr(name).?;
            if (range) |r| {
                try context.document.update(text, r);
            } else {
                try context.document.updateFull(text);
            }
        }
    };
}

fn filterMessages(allocator: std.mem.Allocator, output_stream: *std.Io.Writer, message_queue: *MessageQueue) !void {
    var remove_save: std.ArrayList([]const u8) = .empty;
    defer remove_save.deinit(allocator);
    var remove_format: std.ArrayList([]const u8) = .empty;
    defer remove_format.deinit(allocator);
    var cancel_id: std.ArrayList(types.ID) = .empty;
    defer cancel_id.deinit(allocator);
    var i = message_queue.items.len;
    outer: while (i > 0) {
        i -= 1;
        const message = message_queue.items[i].decoded;
        switch (message) {
            rpc.MethodType.@"textDocument/didSave" => |msg| {
                const uri = msg.params.textDocument.uri;
                for (remove_save.items) |u| {
                    if (std.mem.eql(u8, uri, u)) {
                        const m = message_queue.orderedRemove(i);
                        m.arena.deinit();
                        continue :outer;
                    }
                } else {
                    try remove_save.append(allocator, uri);
                }
            },
            rpc.MethodType.@"textDocument/formatting" => |msg| {
                const uri = msg.params.textDocument.uri;
                for (remove_format.items) |u| {
                    if (std.mem.eql(u8, uri, u)) {
                        const m = message_queue.orderedRemove(i);
                        m.arena.deinit();
                        continue :outer;
                    }
                } else {
                    try remove_format.append(allocator, uri);
                }
            },
            rpc.MethodType.@"$/cancelRequest" => |msg| {
                try cancel_id.append(allocator, msg.params.id);
                const m = message_queue.orderedRemove(i);
                m.arena.deinit();
                continue :outer;
            },
            else => {},
        }
        if (cancel_id.items.len > 0) {
            switch (message) {
                inline else => |msg| {
                    if (@TypeOf(msg) != void and @hasField(@TypeOf(msg), "id")) {
                        const msg_id = msg.id;
                        for (cancel_id.items) |id| {
                            if (msg_id == id) {
                                var m = message_queue.orderedRemove(i);
                                const response = types.Response.Error{
                                    .id = id,
                                    .@"error" = .{
                                        .code = .RequestCancelled,
                                    },
                                };
                                try writeResponseInternal(m.arena.allocator(), output_stream, response);
                                m.arena.deinit();
                                continue :outer;
                            }
                        }
                    }
                },
            }
        }
    }
}

pub fn writeResponseInternal(allocator: std.mem.Allocator, output_stream: *std.Io.Writer, msg: anytype) !void {
    const response = try rpc.encodeMessage(allocator, msg);
    defer allocator.free(response);

    _ = try output_stream.write(response);
    try output_stream.flush();
}

// Tests

fn sendInitialize(server: *Lsp(.{})) !void {
    if (!builtin.is_test) @compileError(@src().fn_name ++ " is only for testing");

    const allocator = std.testing.allocator;

    const init_request = types.Request.Initialize{ .id = @enumFromInt(0) };
    const msg = try std.json.Stringify.valueAlloc(allocator, init_request, .{});
    defer allocator.free(msg);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const decoded = try rpc.decodeMessage(arena.allocator(), msg);

    _ = try server.handleMessage(std.testing.allocator, decoded);
    try std.testing.expectEqual(server.server_state, .Initialize);
}

fn sendInitialized(server: *Lsp(.{})) !void {
    if (!builtin.is_test) @compileError(@src().fn_name ++ " is only for testing");

    const decoded = rpc.MethodType.initialized;

    _ = try server.handleMessage(std.testing.allocator, decoded);
    try std.testing.expectEqual(server.server_state, .Running);
}

fn startServer(server: *Lsp(.{})) !void {
    if (!builtin.is_test) @compileError(@src().fn_name ++ " is only for testing");
    try sendInitialize(server);
    try sendInitialized(server);
}

test "Initialize" {
    var in_buffer: [512]u8 = undefined;
    var out_buffer: [512]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&in_buffer);
    var stdout = std.fs.File.stdout().writer(&out_buffer);

    var server = Lsp(.{}).init(std.testing.allocator, &stdin.interface, &stdout.interface, .{ .name = "testing", .version = "1" });
    defer server.deinit();
    try sendInitialize(&server);
}

test "Initialized" {
    var in_buffer: [512]u8 = undefined;
    var out_buffer: [512]u8 = undefined;
    var stdin = std.fs.File.stdin().reader(&in_buffer);
    var stdout = std.fs.File.stdout().writer(&out_buffer);

    var server = Lsp(.{}).init(std.testing.allocator, &stdin.interface, &stdout.interface, .{ .name = "testing", .version = "1" });
    defer server.deinit();
    try startServer(&server);
}

fn createSave(filename: []const u8) rpc.MethodType {
    return .{ .@"textDocument/didSave" = .{ .params = .{ .textDocument = .{ .uri = filename } } } };
}
test "FilterSaves" {
    var out_buffer: [512]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buffer);

    var queue = try MessageQueue.initCapacity(std.testing.allocator, 3);
    defer queue.deinit(std.testing.allocator);
    queue.appendAssumeCapacity(.{
        .arena = std.heap.ArenaAllocator.init(std.testing.allocator),
        .decoded = createSave("file1"),
    });
    try filterMessages(std.testing.allocator, &stdout.interface, &queue);
    try std.testing.expectEqual(1, queue.items.len);

    queue.appendAssumeCapacity(.{
        .arena = std.heap.ArenaAllocator.init(std.testing.allocator),
        .decoded = createSave("file1"),
    });
    try filterMessages(std.testing.allocator, &stdout.interface, &queue);
    try std.testing.expectEqual(1, queue.items.len);

    queue.appendAssumeCapacity(.{
        .arena = std.heap.ArenaAllocator.init(std.testing.allocator),
        .decoded = createSave("file2"),
    });
    try filterMessages(std.testing.allocator, &stdout.interface, &queue);
    try std.testing.expectEqual(2, queue.items.len);
}

fn createFormatting(filename: []const u8, id: usize) rpc.MethodType {
    return .{
        .@"textDocument/formatting" = .{
            .id = @enumFromInt(id),
            .params = .{
                .textDocument = .{ .uri = filename },
                .options = .{
                    .tabSize = 4,
                    .insertSpaces = true,
                },
            },
        },
    };
}
test "FilterFormats" {
    var out_buffer: [512]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buffer);

    var queue = try MessageQueue.initCapacity(std.testing.allocator, 3);
    defer queue.deinit(std.testing.allocator);
    queue.appendAssumeCapacity(.{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator), .decoded = createFormatting("file1", 1) });
    try filterMessages(std.testing.allocator, &stdout.interface, &queue);
    try std.testing.expectEqual(1, queue.items.len);

    queue.appendAssumeCapacity(.{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator), .decoded = createFormatting("file1", 2) });
    try filterMessages(std.testing.allocator, &stdout.interface, &queue);
    try std.testing.expectEqual(1, queue.items.len);

    queue.appendAssumeCapacity(.{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator), .decoded = createFormatting("file2", 3) });
    try filterMessages(std.testing.allocator, &stdout.interface, &queue);
    try std.testing.expectEqual(2, queue.items.len);
}

test "FilterCancel" {
    var out_buffer: [512]u8 = undefined;
    var stdout = std.fs.File.stdout().writer(&out_buffer);

    var queue = try MessageQueue.initCapacity(std.testing.allocator, 3);
    defer queue.deinit(std.testing.allocator);
    queue.appendAssumeCapacity(.{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator), .decoded = createFormatting("file1", 1) });
    queue.appendAssumeCapacity(.{ .arena = std.heap.ArenaAllocator.init(std.testing.allocator), .decoded = createFormatting("file2", 2) });
    queue.appendAssumeCapacity(
        .{
            .arena = std.heap.ArenaAllocator.init(std.testing.allocator),
            .decoded = .{
                .@"$/cancelRequest" = .{
                    .params = .{
                        .id = @enumFromInt(2),
                    },
                },
            },
        },
    );

    try filterMessages(std.testing.allocator, &stdout.interface, &queue);
    try std.testing.expectEqual(1, queue.items.len);
}
