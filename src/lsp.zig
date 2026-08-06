const std = @import("std");
const builtin = @import("builtin");

const rpc = @import("rpc.zig");
const reader = @import("reader.zig");
const build_options = @import("build_options");

pub const types = @import("types.zig");
pub const logger = @import("logger.zig");
pub const log = logger.log;
pub const fileLog = logger.fileLog;
pub const BasicDocument = @import("document.zig").Document;
pub const TreeSitterDocument = if (build_options.use_tree_sitter) @import("tree-sitter-document.zig").Document else @compileError("Must set use_tree_sitter=true to use TreeSitterDocument");

pub const MethodType = rpc.MethodType;

pub const LspSettings = struct {
    /// A modifiable optional of this type is passed to each callback in the file context.
    state_type: type = void,
    /// How text changes should be passed from client to server.
    document_sync: types.TextDocumentSyncKind = .Incremental,
    /// If the full text should be passed on every save, useful when document_sync = .None
    full_text_on_save: bool = false,
    /// If the document should be updated automatically before the docChange callback is triggered.
    update_doc_on_change: bool = true,

    document_type: type = BasicDocument,
};

pub var test_input_file: ?[]const u8 = null;
pub var test_output_file: ?[]const u8 = null;

pub fn Lsp(comptime settings: LspSettings) type {
    return struct {
        pub const Document = settings.document_type;

        pub const SetupParameters = struct { server: *Lsp(settings), initialize: types.Request.Initialize.Params };
        pub const SetupReturn = void;
        pub const SetupFunction = fn (_: SetupParameters) SetupReturn;

        pub const OpenDocumentParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Notification.DidOpenTextDocument.Params };
        pub const OpenDocumentReturn = void;
        pub const OpenDocumentCallback = fn (_: OpenDocumentParameters) OpenDocumentReturn;

        pub const ChangeDocumentParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Notification.DidChangeTextDocument.Params };
        pub const ChangeDocumentReturn = void;
        pub const ChangeDocumentCallback = fn (_: ChangeDocumentParameters) ChangeDocumentReturn;

        pub const SaveDocumentParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Notification.DidSaveTextDocument.Params };
        pub const SaveDocumentReturn = void;
        pub const SaveDocumentCallback = fn (_: SaveDocumentParameters) SaveDocumentReturn;

        pub const CloseDocumentParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Notification.DidCloseTextDocument.Params };
        pub const CloseDocumentReturn = void;
        pub const CloseDocumentCallback = fn (_: CloseDocumentParameters) CloseDocumentReturn;

        pub const HoverParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.PositionParams };
        pub const HoverReturn = ?[]const u8;
        pub const HoverCallback = fn (_: HoverParameters) HoverReturn;

        pub const CodeActionParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Request.CodeAction.Params };
        pub const CodeActionReturn = ?[]const types.Response.CodeAction.Result;
        pub const CodeActionCallback = fn (_: CodeActionParameters) CodeActionReturn;

        pub const GoToDefinitionParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.PositionParams };
        pub const GoToDefinitionReturn = ?types.Location;
        pub const GoToDefinitionCallback = fn (_: GoToDefinitionParameters) GoToDefinitionReturn;

        pub const GoToDeclarationParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.PositionParams };
        pub const GoToDeclarationReturn = ?types.Location;
        pub const GoToDeclarationCallback = fn (_: GoToDeclarationParameters) GoToDeclarationReturn;

        pub const GoToTypeDefinitionParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.PositionParams };
        pub const GoToTypeDefinitionReturn = ?types.Location;
        pub const GoToTypeDefinitionCallback = fn (_: GoToTypeDefinitionParameters) GoToTypeDefinitionReturn;

        pub const GoToImplementationParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.PositionParams };
        pub const GoToImplementationReturn = ?types.Location;
        pub const GoToImplementationCallback = fn (_: GoToImplementationParameters) GoToImplementationReturn;

        pub const FindReferencesParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.PositionParams };
        pub const FindReferencesReturn = ?[]const types.Location;
        pub const FindReferencesCallback = fn (_: FindReferencesParameters) FindReferencesReturn;

        pub const CompletionParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Request.Completion.Params };
        pub const CompletionReturn = ?types.CompletionList;
        pub const CompletionCallback = fn (_: CompletionParameters) CompletionReturn;

        pub const FormattingParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Request.Formatting.Params };
        pub const FormattingReturn = ?[]const types.TextEdit;
        pub const FormattingCallback = fn (_: FormattingParameters) FormattingReturn;

        pub const RangeFormattingParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Request.RangeFormatting.Params };
        pub const RangeFormattingReturn = ?[]const types.TextEdit;
        pub const RangeFormattingCallback = fn (_: RangeFormattingParameters) RangeFormattingReturn;

        pub const ColorParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Request.Color.Params };
        pub const ColorReturn = []const types.ColorInformation;
        pub const ColorCallback = fn (_: ColorParameters) ColorReturn;

        pub const CodeLensParameters = struct { arena: *std.heap.ArenaAllocator, context: *Context, params: types.Request.CodeLens.Params };
        pub const CodeLensReturn = ?[]const types.CodeLensData;
        pub const CodeLensCallback = fn (_: CodeLensParameters) CodeLensReturn;

        setup_function: ?*const SetupFunction = null,

        callbacks: [@typeInfo(@typeInfo(Callback).@"union".tag_type.?).@"enum".fields.len]?Callback,
        contexts: std.StringHashMap(Context),
        server_data: types.ServerData,
        allocator: std.mem.Allocator,
        io: std.Io,
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

        pub const Context = struct {
            server: *Lsp(settings),
            document: Document,
            state: ?settings.state_type = null,
        };

        const RunState = enum(u8) {
            Run,
            ShutdownOk,
            ShutdownErr,
        };

        const Self = @This();
        pub fn init(allocator: std.mem.Allocator, io: std.Io, input_stream: *std.Io.Reader, output_stream: *std.Io.Writer, server_info: types.ServerInfo) Self {
            var self = Self{
                .allocator = allocator,
                .io = io,
                .input_stream = input_stream,
                .output_stream = output_stream,
                .server_data = .{
                    .serverInfo = server_info,
                    .capabilities = .{ .textDocumentSync = .{
                        .change = settings.document_sync,
                    } },
                },
                .callbacks = undefined,
                .contexts = std.StringHashMap(Context).init(allocator),
            };
            self.callbacks = std.mem.zeroes(@TypeOf(self.callbacks));
            return self;
        }

        pub fn deinit(self: *Self) void {
            var it = self.contexts.iterator();
            while (it.next()) |i| {
                self.allocator.free(i.key_ptr.*);
                i.value_ptr.document.deinit();
            }
            self.contexts.deinit();
        }

        pub const Callback = union(@typeInfo(MethodType).@"union".tag_type.?) {
            initialize: void,
            @"textDocument/hover": *const HoverCallback,
            @"textDocument/declaration": *const GoToDeclarationCallback,
            @"textDocument/definition": *const GoToDefinitionCallback,
            @"textDocument/typeDefinition": *const GoToTypeDefinitionCallback,
            @"textDocument/implementation": *const GoToImplementationCallback,
            @"textDocument/references": *const FindReferencesCallback,
            @"textDocument/codeAction": *const CodeActionCallback,
            shutdown: void,
            @"textDocument/completion": *const CompletionCallback,
            @"textDocument/formatting": *const FormattingCallback,
            @"textDocument/rangeFormatting": *const RangeFormattingCallback,
            @"textDocument/documentColor": *const ColorCallback,
            @"textDocument/codeLens": *const CodeLensCallback,
            initialized: void,
            @"textDocument/didOpen": *const OpenDocumentCallback,
            @"textDocument/didChange": *const ChangeDocumentCallback,
            @"textDocument/didSave": *const SaveDocumentCallback,
            @"textDocument/didClose": *const CloseDocumentCallback,
            exit: void,
            @"$/setTrace": void,
            @"$/cancelRequest": void,
        };
        pub fn registerCallback(self: *Self, callback: Callback) void {
            self.callbacks[@intFromEnum(callback)] = callback;
            switch (callback) {
                .@"textDocument/didSave" => {
                    self.server_data.capabilities.textDocumentSync.save = .{ .includeText = settings.full_text_on_save };
                },
                .@"textDocument/hover" => {
                    self.server_data.capabilities.hoverProvider = true;
                },
                .@"textDocument/codeAction" => {
                    self.server_data.capabilities.codeActionProvider = true;
                },
                .@"textDocument/definition" => {
                    self.server_data.capabilities.definitionProvider = true;
                },
                .@"textDocument/declaration" => {
                    self.server_data.capabilities.declarationProvider = true;
                },
                .@"textDocument/typeDefinition" => {
                    self.server_data.capabilities.typeDefinitionProvider = true;
                },
                .@"textDocument/implementation" => {
                    self.server_data.capabilities.implementationProvider = true;
                },
                .@"textDocument/references" => {
                    self.server_data.capabilities.referencesProvider = true;
                },
                .@"textDocument/completion" => {
                    self.server_data.capabilities.completionProvider = .{};
                },
                .@"textDocument/formatting" => {
                    self.server_data.capabilities.documentFormattingProvider = true;
                },
                .@"textDocument/rangeFormatting" => {
                    self.server_data.capabilities.documentRangeFormattingProvider = true;
                },
                .@"textDocument/documentColor" => {
                    self.server_data.capabilities.colorProvider = true;
                },
                .@"textDocument/codeLens" => {
                    self.server_data.capabilities.codeLensProvider = .{};
                },
                else => {},
            }
            std.log.debug("Registered callback for {s}", .{@tagName(callback)});
        }

        pub fn registerCallbacks(self: *Self, comptime callbacks: []const Callback) void {
            inline for (callbacks) |c| {
                self.registerCallback(c);
            }
        }

        pub fn start(self: *Self, setup_function: ?*const SetupFunction) !u8 {
            self.setup_function = setup_function;

            var message_queue = MessageQueue.init(self.allocator, self.io);
            defer message_queue.deinit();

            var run_state = std.atomic.Value(RunState).init(RunState.Run);

            const thread_handle = try std.Thread.spawn(.{}, receiveThread, .{ self.allocator, self.input_stream, &message_queue, &run_state });
            while (run_state.load(.monotonic) == RunState.Run) {
                var message = message_queue.pop() orelse break;
                defer message.deinit();
                run_state.store(try self.handleMessage(&message.arena, message.decoded), .monotonic);
            }
            thread_handle.join();
            if (run_state.load(.monotonic) == RunState.ShutdownOk) return 0;
            return 1;
        }

        pub fn writeResponse(self: Self, allocator: std.mem.Allocator, msg: anytype) !void {
            if (self.server_state != .Running and @TypeOf(msg) != types.Response.Error) {
                std.log.err("Cannot send message when server not in running state", .{});
                return;
            }
            try writeResponseNoCheck(allocator, self.output_stream, msg);
        }

        fn replyNoCallback(self: Self, allocator: std.mem.Allocator, request: anytype, tagName: [:0]const u8) void {
            var buf: [100]u8 = undefined;
            const str = std.fmt.bufPrint(&buf, "No callback registered for handling {s}", .{tagName}) catch return;
            self.replyInvalidRequest(allocator, request, types.ErrorCode.RequestFailed, str) catch return;
        }

        fn handleMessage(self: *Self, arena: *std.heap.ArenaAllocator, msg: rpc.MethodType) !RunState {
            std.log.debug("Received request: {s}", .{@tagName(msg)});

            const allocator = arena.allocator();

            if (!self.server_state.validMessage(msg)) {
                switch (self.server_state) {
                    .Stopped => try self.replyInvalidRequest(allocator, msg, types.ErrorCode.ServerNotInitialized, "Server not initialized"),
                    .Initialize => try self.replyInvalidRequest(allocator, msg, types.ErrorCode.ServerNotInitialized, "Server initializing"),
                    .Shutdown => try self.replyInvalidRequest(allocator, msg, types.ErrorCode.InvalidRequest, "Server shutting down"),
                    .Running => try self.replyInvalidRequest(allocator, msg, types.ErrorCode.InvalidRequest, "Server already running"),
                }
                return RunState.Run;
            }

            matcher: switch (msg) {
                rpc.MethodType.initialize => |request| {
                    if (!self.server_data.capabilities.textDocumentSync.openClose) @panic("TextDocumentSync.OpenClose must be true");
                    try self.handleInitialize(allocator, request);
                    self.server_state = .Initialize;
                },
                rpc.MethodType.initialized => {
                    self.server_state = .Running;
                },
                inline rpc.MethodType.@"textDocument/didOpen" => |notification, tag| {
                    const params = notification.params;
                    try openDocument(self, params.textDocument.uri, params.textDocument.languageId, params.textDocument.text);

                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(.{ .arena = arena, .context = context, .params = params });
                    }
                },
                inline rpc.MethodType.@"textDocument/didChange" => |notification, tag| {
                    const params = notification.params;
                    const context = self.contexts.getPtr(params.textDocument.uri).?;
                    if (settings.update_doc_on_change) {
                        try context.document.updateAll(params.contentChanges);
                    }

                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        callback(.{ .arena = arena, .context = context, .params = params });
                    }
                },
                inline rpc.MethodType.@"textDocument/didSave" => |notification, tag| {
                    const params = notification.params;
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        if (notification.params.text) |text| {
                            try context.document.update(.{ .text = text, .range = null });
                        }
                        callback(.{ .arena = arena, .context = context, .params = params });
                    }
                },
                inline rpc.MethodType.@"textDocument/didClose" => |notification, tag| {
                    const params = notification.params;

                    var entry = self.contexts.fetchRemove(params.textDocument.uri) orelse break :matcher;
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        var context = entry.value;
                        callback(.{ .arena = arena, .context = &context, .params = params });
                    }
                    entry.value.document.deinit();
                },
                inline rpc.MethodType.@"textDocument/hover" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(.{ .arena = arena, .context = context, .params = params })) |message|
                            types.Response.Hover.init(request.id, message)
                        else
                            types.Response.Hover{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/codeAction" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(.{ .arena = arena, .context = context, .params = params })) |results|
                            types.Response.CodeAction{ .id = request.id, .result = results }
                        else
                            types.Response.CodeAction{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/declaration" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        try self.handleGoTo(arena, request, callback);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/definition" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        try self.handleGoTo(arena, request, callback);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/typeDefinition" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        try self.handleGoTo(arena, request, callback);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/implementation" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        try self.handleGoTo(arena, request, callback);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/references" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        const response = if (callback(.{ .arena = arena, .context = context, .params = params })) |locations|
                            types.Response.MultiLocationResponse.init(request.id, locations)
                        else
                            types.Response.MultiLocationResponse{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                rpc.MethodType.@"$/setTrace" => |notification| {
                    logger.trace_value = notification.params.value;
                },
                rpc.MethodType.@"$/cancelRequest" => {
                    // Handled in receive thread
                    unreachable;
                },
                inline rpc.MethodType.@"textDocument/completion" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(.{ .arena = arena, .context = context, .params = params })) |items|
                            types.Response.Completion{ .id = request.id, .result = items }
                        else
                            types.Response.Completion{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/formatting" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(.{ .arena = arena, .context = context, .params = params })) |items|
                            types.Response.Formatting{ .id = request.id, .result = items }
                        else
                            types.Response.Formatting{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/rangeFormatting" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const response = if (callback(.{ .arena = arena, .context = context, .params = params })) |items|
                            types.Response.Formatting{ .id = request.id, .result = items }
                        else
                            types.Response.Formatting{ .id = request.id };
                        try self.writeResponse(allocator, response);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/documentColor" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const items = callback(.{ .arena = arena, .context = context, .params = params });
                        const response = types.Response.Color{ .id = request.id, .result = items };
                        try self.writeResponse(allocator, response);
                    } else self.replyNoCallback(allocator, request, @tagName(msg));
                },
                inline rpc.MethodType.@"textDocument/codeLens" => |request, tag| {
                    if (self.callbacks[@intFromEnum(tag)]) |c| {
                        const callback = @field(c, @tagName(tag));
                        const params = request.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        const items = callback(.{ .arena = arena, .context = context, .params = params });
                        const response = types.Response.CodeLens{ .id = request.id, .result = items };
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

        fn handleGoTo(self: *Self, arena: *std.heap.ArenaAllocator, request: anytype, callback: anytype) !void {
            const params = request.params;
            const context = self.contexts.getPtr(params.textDocument.uri).?;
            const response = if (callback(.{ .arena = arena, .context = context, .params = params })) |location|
                types.Response.LocationResponse.init(request.id, location)
            else
                types.Response.LocationResponse{ .id = request.id };
            try self.writeResponse(arena.allocator(), response);
        }

        fn handleShutdown(self: Self, allocator: std.mem.Allocator, request: types.Request.Shutdown) !void {
            const response = types.Response.Shutdown.init(request);
            try writeResponseNoCheck(allocator, self.output_stream, response);
        }

        fn replyInvalidRequest(self: Self, allocator: std.mem.Allocator, request: anytype, error_code: types.ErrorCode, error_message: []const u8) !void {
            if (@hasField(@TypeOf(request), "id")) {
                const reply = types.Response.Error.init(request.id, error_code, error_message);
                try writeResponseNoCheck(allocator, self.output_stream, reply);
            }
        }

        fn handleInitialize(self: *Self, allocator: std.mem.Allocator, request: types.Request.Initialize) !void {
            if (request.params.clientInfo) |client_info| {
                std.log.debug("Connected to {s} {s}", .{ client_info.name, client_info.version orelse "" });
            } else {
                std.log.debug("Connected to unknown server", .{});
            }

            if (request.params.trace) |trace| {
                logger.trace_value = trace;
            }

            if (self.setup_function) |s| {
                s(.{ .server = self, .initialize = request.params });
            }

            const response_msg = types.Response.Initialize.init(request.id, self.server_data);

            try writeResponseNoCheck(allocator, self.output_stream, response_msg);
        }

        fn openDocument(self: *Self, name: []const u8, language: []const u8, content: []const u8) !void {
            const context =
                Context{ .document = try Document.init(self.allocator, name, language, content), .server = self };
            try self.contexts.put(try self.allocator.dupe(u8, name), context);
        }

        fn receiveThread(
            allocator: std.mem.Allocator,
            input_stream: *std.Io.Reader,
            message_queue: *MessageQueue,
            run_state: *std.atomic.Value(RunState),
        ) void {
            var it = MessageIterator.init(allocator, input_stream);
            defer it.deinit();
            while (run_state.load(.monotonic) == .Run) {
                const message = it.next(allocator) catch |e| {
                    if (@TypeOf(e) == MessageIterator.Error) continue else unreachable;
                };
                if (message != null and message.?.decoded == rpc.MethodType.@"$/cancelRequest") {
                    const id = message.?.decoded.@"$/cancelRequest".params.id;
                    for (message_queue.queue.items, 0..) |msg, i| {
                        if (@hasField(@TypeOf(msg.?), "id") and @field(msg.?, "id") == id) {
                            message_queue.queue.orderedRemove(i);
                            break;
                        }
                    }
                    continue;
                }

                message_queue.push(message) catch unreachable;
                if (message == null or message.?.decoded == rpc.MethodType.exit) break;
            }
        }
    };
}

pub const MessageIterator = struct {
    const Self = @This();

    pub const Error = error{
        InvalidHeader,
        DecodeFailure,
    };

    input_stream: *std.Io.Reader,
    header_buf: std.Io.Writer.Allocating,
    body_buf: std.Io.Writer.Allocating,

    pub fn init(allocator: std.mem.Allocator, input_stream: *std.Io.Reader) Self {
        const header = std.Io.Writer.Allocating.init(allocator);
        const body = std.Io.Writer.Allocating.init(allocator);

        return Self{
            .input_stream = input_stream,
            .header_buf = header,
            .body_buf = body,
        };
    }
    pub fn deinit(self: *Self) void {
        self.header_buf.deinit();
        self.body_buf.deinit();
    }

    pub const Message = struct {
        decoded: rpc.MethodType,
        arena: std.heap.ArenaAllocator,

        pub fn deinit(self: Message) void {
            self.arena.deinit();
        }
    };

    pub fn next(self: *Self, allocator: std.mem.Allocator) !?Message {
        std.log.debug("Waiting for header", .{});
        const read = try reader.readUntilDelimiterOrEof(self.input_stream, &self.header_buf.writer, "\r\n\r\n");
        if (read == 0) return null;

        const content_len_str = "Content-Length: ";
        const content_len = if (std.mem.indexOf(u8, self.header_buf.written(), content_len_str)) |idx|
            try std.fmt.parseInt(usize, self.header_buf.written()[idx + content_len_str.len ..], 10)
        else {
            std.log.warn("Content-Length not found in header\n'{s}'", .{self.header_buf.written()});
            return Error.InvalidHeader;
        };
        self.header_buf.clearRetainingCapacity();

        try self.input_stream.streamExact(&self.body_buf.writer, content_len);
        defer self.body_buf.clearRetainingCapacity();

        var arena = std.heap.ArenaAllocator.init(allocator);
        const decoded = rpc.decodeMessage(arena.allocator(), self.body_buf.written()) catch |e| {
            std.log.warn("Failed to decode message: {any}\n", .{e});
            return Error.DecodeFailure;
        };
        return .{ .decoded = decoded, .arena = arena };
    }
};

const MessageQueue = struct {
    queue: std.ArrayList(?MessageIterator.Message) = .empty,
    mutex: std.Io.Mutex = .init,
    semaphore: std.Io.Semaphore = .{},
    allocator: std.mem.Allocator,
    io: std.Io,

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator, io: std.Io) Self {
        return .{ .allocator = allocator, .io = io };
    }
    pub fn deinit(self: *Self) void {
        self.mutex.lock(self.io) catch unreachable;
        defer self.mutex.unlock(self.io);
        self.queue.deinit(self.allocator);
    }
    fn push(self: *Self, message: ?MessageIterator.Message) !void {
        {
            self.mutex.lock(self.io) catch unreachable;
            defer self.mutex.unlock(self.io);
            try self.queue.append(self.allocator, message);
        }
        self.semaphore.post(self.io);
    }
    fn pop(self: *Self) ?MessageIterator.Message {
        self.semaphore.wait(self.io) catch unreachable;
        self.mutex.lock(self.io) catch unreachable;
        defer self.mutex.unlock(self.io);
        return self.queue.orderedRemove(0);
    }
};

/// Send a message to the client without checking if the server is in the correct state
/// (only log messages are allowed to be sent if the server isn't initialized)
pub fn writeResponseNoCheck(allocator: std.mem.Allocator, output_stream: *std.Io.Writer, msg: anytype) !void {
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

    arena.reset(.retain_capacity);
    _ = try server.handleMessage(&arena, decoded);
    try std.testing.expectEqual(server.server_state, .Initialize);
}

fn sendInitialized(server: *Lsp(.{})) !void {
    if (!builtin.is_test) @compileError(@src().fn_name ++ " is only for testing");

    const decoded = rpc.MethodType.initialized;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try server.handleMessage(&arena, decoded);
    try std.testing.expectEqual(server.server_state, .Running);
}

fn startServer(server: *Lsp(.{})) !void {
    if (!builtin.is_test) @compileError(@src().fn_name ++ " is only for testing");
    try sendInitialize(server);
    try sendInitialized(server);
}

fn createSave(filename: []const u8) rpc.MethodType {
    return .{ .@"textDocument/didSave" = .{ .params = .{ .textDocument = .{ .uri = filename } } } };
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
