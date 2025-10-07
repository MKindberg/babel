const std = @import("std");

pub const ID = enum(i32) { _ };

pub const Request = struct {
    pub const Request = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        method: []const u8,
    };
    pub const Initialize = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        method: []const u8 = "initialize",
        params: Params = .{},

        pub const Params = struct {
            processId: ?i32 = null,
            clientInfo: ?ClientInfo = null,
            locale: ?[]const u8 = null,
            rootPath: ?[]const u8 = null,
            rootUri: ?[]const u8 = null,
            capabilities: ClientCapabilities = .{},
            trace: ?TraceValue = null,
            workspaceFolders: ?[]WorkspaceFolder = null,

            const WorkspaceFolder = struct {
                uri: []const u8,
                name: []const u8,
            };

            const ClientInfo = struct {
                name: []u8,
                version: ?[]u8 = null,
            };

            const WorkspaceClientCapabilities = struct {};
            const WindowClientCapabilities = struct {};
            const GeneralClientCapabilities = struct {};

            const ClientCapabilities = struct {
                workspace: ?WorkspaceClientCapabilities = null,
                textDocument: ?TextDocumentClientCapabilities = null,
                window: ?WindowClientCapabilities = null,
                general: ?GeneralClientCapabilities = null,
            };

            const MarkupKind = enum {
                PlainText,
                Markdown,

                pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
                    _ = options;
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        inline .string, .allocated_string => |s| {
                            if (std.mem.eql(u8, s, "plaintext")) {
                                return .PlainText;
                            } else if (std.mem.eql(u8, s, "markdown")) {
                                return .Markdown;
                            } else {
                                return error.UnexpectedToken;
                            }
                        },
                        else => return error.UnexpectedToken,
                    }
                }
            };
            const CompletionItemTag = enum(i32) {
                Deprecated = 1,

                pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
                    _ = options;
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        .number => |n| {
                            const int = try std.fmt.parseInt(i32, n, 10);
                            return @enumFromInt(int);
                        },
                        else => return error.UnexpectedToken,
                    }
                }
            };
            const DiagnosticTag = enum(i32) {
                Unnecessary = 1,
                Deprecated = 2,

                pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
                    _ = options;
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        .number => |n| {
                            const int = try std.fmt.parseInt(i32, n, 10);
                            return @enumFromInt(int);
                        },
                        else => return error.UnexpectedToken,
                    }
                }
            };
            const SymbolKind = enum(i32) {
                File = 1,
                Module = 2,
                Namespace = 3,
                Package = 4,
                Class = 5,
                Method = 6,
                Property = 7,
                Field = 8,
                Constructor = 9,
                Enum = 10,
                Interface = 11,
                Function = 12,
                Variable = 13,
                Constant = 14,
                String = 15,
                Number = 16,
                Boolean = 17,
                Array = 18,
                Object = 19,
                Key = 20,
                Null = 21,
                EnumMember = 22,
                Struct = 23,
                Event = 24,
                Operator = 25,
                TypeParameter = 26,

                pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
                    _ = options;
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        .number => |n| {
                            const int = try std.fmt.parseInt(i32, n, 10);
                            return @enumFromInt(int);
                        },
                        else => return error.UnexpectedToken,
                    }
                }
            };
            const SymbolTag = enum(i32) {
                Deprecated = 1,

                pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
                    _ = options;
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        .number => |n| {
                            const int = try std.fmt.parseInt(i32, n, 10);
                            return @enumFromInt(int);
                        },
                        else => return error.UnexpectedToken,
                    }
                }
            };
            const PrepareSupportDefaultBehavior = enum(i32) {
                Identifier = 1,

                pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
                    _ = options;
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        .number => |n| {
                            const int = try std.fmt.parseInt(i32, n, 10);
                            return @enumFromInt(int);
                        },
                        else => return error.UnexpectedToken,
                    }
                }
            };
            const FoldingRangeKind = enum {
                Comment,
                Imports,
                Region,

                pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
                    _ = options;
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        inline .string, .allocated_string => |s| {
                            if (std.mem.eql(u8, s, "comment")) {
                                return .Comment;
                            } else if (std.mem.eql(u8, s, "imports")) {
                                return .Imports;
                            } else if (std.mem.eql(u8, s, "region")) {
                                return .Region;
                            } else {
                                return error.UnexpectedToken;
                            }
                        },
                        else => return error.UnexpectedToken,
                    }
                }
            };
            const TokenFormat = enum {
                Relative,

                pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
                    _ = options;
                    switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
                        inline .string, .allocated_string => |s| {
                            if (std.mem.eql(u8, s, "relative")) {
                                return .Relative;
                            } else {
                                return error.UnexpectedToken;
                            }
                        },
                        else => return error.UnexpectedToken,
                    }
                }
            };

            const CompletionClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                completionItem: ?struct {
                    snippetSupport: ?bool = null,
                    commitCharactersSupport: ?bool = null,
                    documentationFormat: ?[]MarkupKind = null,
                    deprecatedSupport: ?bool = null,
                    preselectSupport: ?bool = null,
                    tagSupport: ?struct {
                        valueSet: []CompletionItemTag,
                    } = null,
                    insertReplaceSupport: ?bool = null,
                    resolveSupport: ?struct {
                        properties: []const []const u8,
                    } = null,
                    insertTextModeSupport: ?struct {
                        valueSet: []CompletionItem.InsertTextMode,
                    } = null,
                    labelDetailsSupport: ?bool = null,
                } = null,
                completionItemKind: ?struct {
                    valueSet: ?[]CompletionItem.Kind = null,
                } = null,
                contextSupport: ?bool = null,
                insertTextMode: ?CompletionItem.InsertTextMode = null,
                completionList: ?struct {
                    itemDefaults: ?[]const []const u8 = null,
                } = null,
            };
            const HoverClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                contentFormat: ?[]MarkupKind = null,
            };
            const DeclarationClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                linkSupport: ?bool = null,
            };
            const DefinitionClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                linkSupport: ?bool = null,
            };
            const TypeDefinitionClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                linkSupport: ?bool = null,
            };
            const ImplementationClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                linkSupport: ?bool = null,
            };
            const ReferenceClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const CodeActionClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                codeActionLiteralSupport: ?struct {
                    codeActionKind: struct {
                        valueSet: []CodeActionKind,
                    },
                } = null,
                isPreferredSupport: ?bool = null,
                disabledSupport: ?bool = null,
                dataSupport: ?bool = null,
                resolveSupport: ?struct {
                    properties: []const []const u8,
                } = null,
                honorsChangeAnnotations: ?bool = null,
            };
            const DocumentFormattingClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const DocumentRangeFormattingClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const PublishDiagnosticsClientCapabilities = struct {
                relatedInformation: ?bool = null,
                tagSupport: ?struct {
                    valueSet: []DiagnosticTag,
                } = null,
                versionSupport: ?bool = null,
                codeDescriptionSupport: ?bool = null,
                dataSupport: ?bool = null,
            };
            const TextDocumentSyncClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                willSave: ?bool = null,
                willSaveWaitUntil: ?bool = null,
                didSave: ?bool = null,
            };
            const SignatureHelpClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                signatureInformation: ?struct {
                    documentationFormat: ?[]MarkupKind = null,
                    parameterInformation: ?struct {
                        labelOffsetSupport: ?bool = null,
                    } = null,
                    activeParameterSupport: ?bool = null,
                } = null,
                contextSupport: ?bool = null,
            };
            const DocumentHighlightClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const DocumentSymbolClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                symbolKind: ?struct {
                    valueSet: ?[]SymbolKind = null,
                } = null,
                hierarchicalDocumentSymbolSupport: ?bool = null,
                tagSupport: ?struct {
                    valueSet: []SymbolTag,
                } = null,
                labelSupport: ?bool = null,
            };
            const CodeLensClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const DocumentLinkClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                tooltipSupport: ?bool = null,
            };
            const DocumentColorClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const DocumentOnTypeFormattingClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const RenameClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                prepareSupport: ?bool = null,
                prepareSupportDefaultBehavior: ?PrepareSupportDefaultBehavior = null,
                honorsChangeAnnotations: ?bool = null,
            };
            const FoldingRangeClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                rangeLimit: ?u32 = null,
                lineFoldingOnly: ?bool = null,
                foldingRangeKind: ?struct {
                    valueSet: ?[]FoldingRangeKind = null,
                } = null,
                foldingRange: ?struct {
                    collapsedText: ?bool = null,
                } = null,
            };
            const SelectionRangeClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const LinkedEditingRangeClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const CallHierarchyClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const SemanticTokensClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                requests: ?struct {
                    range: ?union(enum) {
                        boolean: bool,
                        object: struct {},
                    } = null,
                    full: ?union(enum) {
                        boolean: bool,
                        delta_object: struct {
                            delta: ?bool = null,
                        },
                    } = null,
                } = null,
                tokenTypes: []const []const u8,
                tokenModifiers: []const []const u8,
                formats: []TokenFormat,
                overlappingTokenSupport: ?bool = null,
                multilineTokenSupport: ?bool = null,
                serverCancelSupport: ?bool = null,
                augmentsSyntaxTokens: ?bool = null,
            };
            const MonikerClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const TypeHierarchyClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const InlineValueClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };
            const InlayHintClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                resolveSupport: ?struct {
                    properties: []const []const u8,
                } = null,
            };
            const DiagnosticClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
                relatedDocumentSupport: ?bool = null,
            };
            const InlineCompletionClientCapabilities = struct {
                dynamicRegistration: ?bool = null,
            };

            const TextDocumentClientCapabilities = struct {
                synchronization: ?TextDocumentSyncClientCapabilities = null,
                completion: ?CompletionClientCapabilities = null,
                hover: ?HoverClientCapabilities = null,
                signatureHelp: ?SignatureHelpClientCapabilities = null,
                declaration: ?DeclarationClientCapabilities = null,
                definition: ?DefinitionClientCapabilities = null,
                typeDefinition: ?TypeDefinitionClientCapabilities = null,
                implementation: ?ImplementationClientCapabilities = null,
                references: ?ReferenceClientCapabilities = null,
                documentHighlight: ?DocumentHighlightClientCapabilities = null,
                documentSymbol: ?DocumentSymbolClientCapabilities = null,
                codeAction: ?CodeActionClientCapabilities = null,
                codeLens: ?CodeLensClientCapabilities = null,
                documentLink: ?DocumentLinkClientCapabilities = null,
                colorProvider: ?DocumentColorClientCapabilities = null,
                formatting: ?DocumentFormattingClientCapabilities = null,
                rangeFormatting: ?DocumentRangeFormattingClientCapabilities = null,
                onTypeFormatting: ?DocumentOnTypeFormattingClientCapabilities = null,
                rename: ?RenameClientCapabilities = null,
                publishDiagnostics: ?PublishDiagnosticsClientCapabilities = null,
                foldingRange: ?FoldingRangeClientCapabilities = null,
                selectionRange: ?SelectionRangeClientCapabilities = null,
                linkedEditingRange: ?LinkedEditingRangeClientCapabilities = null,
                callHierarchy: ?CallHierarchyClientCapabilities = null,
                semanticTokens: ?SemanticTokensClientCapabilities = null,
                // moniker: ?MonikerClientCapabilities = null,
                // typeHierarchy: ?TypeHierarchyClientCapabilities = null,
                // inlineValue: ?InlineValueClientCapabilities = null,
                // inlayHint: ?InlayHintClientCapabilities = null,
                // diagnostic: ?DiagnosticClientCapabilities = null,
            };
        };
    };

    // Used by hover, goto definition, etc.
    pub const PositionRequest = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        method: []const u8,
        params: PositionParams,
    };

    pub const CodeAction = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        method: []const u8 = "textDocument/codeAction",
        params: Params,

        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
            range: Range,
            context: CodeActionContext,
        };
    };

    pub const Shutdown = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        method: []const u8 = "shutdown",
    };

    pub const Completion = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        method: []const u8 = "textDocument/completion",
        params: Params,

        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
            position: Position,
            // context: ?CompletionContext = null,

            const CompletionContext = struct {
                triggerKind: TriggerKind,
                triggerCharacter: ?[]const u8 = null,
            };
            const TriggerKind = enum(i32) {
                Invoked = 1,
                TriggerCharacter = 2,
                TriggerForIncompleteCompletions = 3,
            };
        };
    };

    pub const Formatting = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        method: []const u8 = "textDocument/formatting",
        params: Params,

        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
            options: FormattingOptions,
        };
    };

    pub const RangeFormatting = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        method: []const u8 = "textDocument/rangeFormatting",
        params: Params,

        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
            range: Range,
            options: FormattingOptions,
        };
    };
};

pub const Response = struct {
    pub const Initialize = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        result: ServerData,

        const Self = @This();

        pub fn init(id: ID, server_data: ServerData) Self {
            return Self{
                .jsonrpc = "2.0",
                .id = id,
                .result = server_data,
            };
        }
    };

    pub const Hover = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        result: ?Result = null,

        const Result = struct {
            contents: []const u8,
        };

        const Self = @This();
        pub fn init(id: ID, contents: []const u8) Self {
            return Self{
                .id = id,
                .result = .{
                    .contents = contents,
                },
            };
        }
    };

    pub const CodeAction = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        result: ?[]const Result = null,

        pub const Result = struct {
            title: []const u8,
            kind: ?CodeActionKind = null,
            edit: ?WorkspaceEdit = null,
            const WorkspaceEdit = struct {
                changes: std.json.ArrayHashMap([]const TextEdit),
            };
        };
    };

    // Used by goto definition, etc.
    pub const LocationResponse = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        result: ?Location = null,

        const Self = @This();
        pub fn init(id: ID, location: Location) Self {
            return Self{
                .id = id,
                .result = location,
            };
        }
    };

    pub const MultiLocationResponse = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        result: ?[]const Location = null,

        const Self = @This();
        pub fn init(id: ID, locations: []const Location) Self {
            return Self{
                .id = id,
                .result = locations,
            };
        }
    };

    pub const Shutdown = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        result: void,

        const Self = @This();
        pub fn init(request: Request.Shutdown) Self {
            return Self{
                .jsonrpc = "2.0",
                .id = request.id,
                .result = {},
            };
        }
    };

    pub const Error = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        @"error": ErrorData,

        const Self = @This();
        pub fn init(id: ID, code: ErrorCode, message: []const u8) Self {
            return Self{
                .jsonrpc = "2.0",
                .id = id,
                .@"error" = .{
                    .code = code,
                    .message = message,
                },
            };
        }
    };

    pub const Completion = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        result: ?CompletionList = null,
    };

    pub const Formatting = struct {
        jsonrpc: []const u8 = "2.0",
        id: ID,
        result: []const TextEdit = &[_]TextEdit{},
    };
};

pub const Notification = struct {
    pub const Notification = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8,
    };
    pub const DidOpenTextDocument = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "textDocument/didOpen",
        params: Params,

        pub const Params = struct {
            textDocument: TextDocumentItem,
        };
    };

    pub const DidChangeTextDocument = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "textDocument/didChange",
        params: Params,

        pub const Params = struct {
            textDocument: VersionedTextDocumentIdentifier,
            contentChanges: []const ChangeEvent,

            const VersionedTextDocumentIdentifier = struct {
                uri: []const u8,
                version: i32,
            };
        };
    };

    pub const DidSaveTextDocument = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "textDocument/didSave",
        params: Params,
        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
            text: ?[]const u8 = null,
        };
    };

    pub const DidCloseTextDocument = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "textDocument/didClose",
        params: Params,
        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
        };
    };

    pub const PublishDiagnostics = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "textDocument/publishDiagnostics",
        params: Params,
        pub const Params = struct {
            uri: []const u8,
            diagnostics: []const Diagnostic = &[0]Diagnostic{},
        };
    };

    pub const Exit = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "exit",
    };

    pub const LogMessage = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "window/logMessage",
        params: Params,
        pub const Params = struct {
            type: MessageType,
            message: []const u8,
        };
    };

    pub const LogTrace = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "$/logTrace",
        params: Params,
        pub const Params = struct {
            message: []const u8,
            verbose: ?[]const u8 = null,
        };
    };

    pub const SetTrace = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "$/setTrace",
        params: Params,
        pub const Params = struct {
            value: TraceValue,
        };
    };

    pub const Cancel = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8 = "$/cancelRequest",
        params: Params,
        pub const Params = struct {
            id: ID,
        };
    };
};

const TextDocumentItem = struct {
    uri: []const u8,
    languageId: []const u8,
    version: i32,
    text: []const u8,
};

const TextDocumentIdentifier = struct {
    uri: []const u8,
};

pub const ServerData = struct {
    capabilities: ServerCapabilities = .{},
    serverInfo: ?ServerInfo = null,

    const ServerCapabilities = struct {
        textDocumentSync: TextDocumentSyncOptions = .{},
        hoverProvider: bool = false,
        codeActionProvider: bool = false,
        declarationProvider: bool = false,
        definitionProvider: bool = false,
        typeDefinitionProvider: bool = false,
        implementationProvider: bool = false,
        referencesProvider: bool = false,
        documentFormattingProvider: bool = false,
        documentRangeFormattingProvider: bool = false,
        completionProvider: ?struct {} = .{},
    };
};

pub const Range = struct {
    start: Position,
    end: Position,
};
pub const Position = struct {
    line: usize,
    character: usize,
};

pub const PositionParams = struct {
    textDocument: TextDocumentIdentifier,
    position: Position,
};

pub const Location = struct {
    uri: []const u8,
    range: Range,
};

pub const TextEdit = struct {
    range: Range,
    newText: []const u8,
};

pub const ChangeEvent = struct {
    range: ?Range = null,
    text: []const u8,
};

pub const Diagnostic = struct {
    range: Range,
    severity: DiagnosticSeverity,
    source: ?[]const u8 = null,
    message: []const u8,
};

pub const DiagnosticSeverity = enum(i32) {
    Error = 1,
    Warning = 2,
    Information = 3,
    Hint = 4,

    const Self = @This();
    pub fn jsonStringify(self: Self, out: anytype) !void {
        return out.print("{}", .{@intFromEnum(self)});
    }
};

pub const ErrorData = struct {
    code: ErrorCode,
    message: []const u8 = "",
};

pub const ErrorCode = enum(i32) {
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
    jsonrpcReservedErrorRangeStart = -32099,
    ServerNotInitialized = -32002,
    UnknownErrorCode = -32001,
    jsonrpcReservedErrorRangeEnd = -32000,
    lspReservedErrorRangeStart = -32899,
    RequestFailed = -32803,
    ServerCancelled = -32802,
    ContentModified = -32801,
    RequestCancelled = -32800,
    // lspReservedErrorRangeEnd = -32800,

    const Self = @This();
    pub fn jsonStringify(self: Self, out: anytype) !void {
        return out.print("{}", .{@intFromEnum(self)});
    }
};

pub const MessageType = enum(i32) {
    Error = 1,
    Warning = 2,
    Info = 3,
    Log = 4,
    Debug = 5,

    const Self = @This();
    pub fn jsonStringify(self: Self, out: anytype) !void {
        return out.print("{}", .{@intFromEnum(self)});
    }
};

pub const TextDocumentSyncKind = enum(i32) {
    None = 0,
    Full = 1,
    Incremental = 2,

    const Self = @This();
    pub fn jsonStringify(self: Self, out: anytype) !void {
        return out.print("{}", .{@intFromEnum(self)});
    }
};

pub const TraceValue = enum {
    Off,
    Messages,
    Verbose,

    const Self = @This();
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Self {
        _ = options;
        switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
            inline .string, .allocated_string => |s| {
                if (std.mem.eql(u8, s, "off")) {
                    return .Off;
                } else if (std.mem.eql(u8, s, "messages")) {
                    return .Messages;
                } else if (std.mem.eql(u8, s, "verbose")) {
                    return .Verbose;
                } else {
                    return error.UnexpectedToken;
                }
            },
            else => return error.UnexpectedToken,
        }
    }
};

pub const TextDocumentSyncOptions = struct {
    openClose: bool = true,
    change: TextDocumentSyncKind = .Incremental,
    save: SaveOptions = .{},

    const SaveOptions = struct {
        includeText: ?bool = null,
    };
};

pub const CompletionList = struct {
    isIncomplete: bool = false,
    itemDefaults: ?CompletionItemDefaults = null,
    items: []CompletionItem = &.{},
};

pub const CompletionItemDefaults = struct {
    commitCharacters: ?[]u8 = null,
    editRange: ?Range = null,
    insertTextFormat: ?CompletionItem.InsertTextFormat = null,
    insertTextMode: ?CompletionItem.InsertTextMode = null,
};
pub const CompletionItem = struct {
    label: []const u8,
    kind: ?Kind = null,
    detail: ?[]const u8 = null,
    documentation: ?[]const u8 = null,
    presentation: ?bool = null,
    sortText: ?[]const u8 = null,
    filterText: ?[]const u8 = null,
    insertText: ?[]const u8 = null,
    insertTextFormat: ?InsertTextFormat = null,
    insertTextMode: ?InsertTextMode = null,
    textEdits: ?[]TextEdit = null,
    additionalTextEdits: ?[]TextEdit = null,
    commitCharacters: ?[]const u8 = null,

    const Kind = enum(i32) {
        Text = 1,
        Method = 2,
        Function = 3,
        Constructor = 4,
        Field = 5,
        Variable = 6,
        Class = 7,
        Interface = 8,
        Module = 9,
        Property = 10,
        Unit = 11,
        Value = 12,
        Enum = 13,
        Keyword = 14,
        Snippet = 15,
        Color = 16,
        File = 17,
        Reference = 18,
        Folder = 19,
        EnumMember = 20,
        Constant = 21,
        Struct = 22,
        Event = 23,
        Operator = 24,
        TypeParameter = 25,

        const Self = @This();
        pub fn jsonStringify(self: Self, out: anytype) !void {
            return out.print("{}", .{@intFromEnum(self)});
        }
    };

    const InsertTextFormat = enum(i32) {
        PlainText = 1,
        Snippet = 2,

        const Self = @This();
        pub fn jsonStringify(self: Self, out: anytype) !void {
            return out.print("{}", .{@intFromEnum(self)});
        }
    };

    const InsertTextMode = enum(i32) {
        AsIs = 1,
        AdjustIndentation = 2,

        const Self = @This();
        pub fn jsonStringify(self: Self, out: anytype) !void {
            return out.print("{}", .{@intFromEnum(self)});
        }
    };
};
pub const CodeActionKind = enum {
    Empty,
    QuickFix,
    Refactor,
    RefactorExtract,
    RefactorInline,
    RefactorRewrite,
    Source,
    SourceOrganizeImports,
    SourceFixAll,

    const Self = @This();
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Self {
        _ = options;
        switch (try source.nextAlloc(allocator, .alloc_if_needed)) {
            inline .string, .allocated_string => |s| {
                if (std.mem.eql(u8, s, "")) {
                    return .Empty;
                } else if (std.mem.eql(u8, s, "quickfix")) {
                    return .QuickFix;
                } else if (std.mem.eql(u8, s, "refactor")) {
                    return .Refactor;
                } else if (std.mem.eql(u8, s, "refactor.extract")) {
                    return .RefactorExtract;
                } else if (std.mem.eql(u8, s, "refactor.inline")) {
                    return .RefactorInline;
                } else if (std.mem.eql(u8, s, "refactor.rewrite")) {
                    return .RefactorRewrite;
                } else if (std.mem.eql(u8, s, "source")) {
                    return .Source;
                } else if (std.mem.eql(u8, s, "source.organizeImports")) {
                    return .SourceOrganizeImports;
                } else if (std.mem.eql(u8, s, "source.fixAll")) {
                    return .SourceFixAll;
                } else {
                    return error.UnexpectedToken;
                }
            },
            else => return error.UnexpectedToken,
        }
    }
    pub fn jsonStringify(self: Self, out: anytype) !void {
        switch (self) {
            .Empty => return out.print("\"\"", .{}),
            .QuickFix => return out.print("\"quickfix\"", .{}),
            .Refactor => return out.print("\"refactor\"", .{}),
            .RefactorExtract => return out.print("\"refactor.extract\"", .{}),
            .RefactorInline => return out.print("\"refactor.inline\"", .{}),
            .RefactorRewrite => return out.print("\"refactor.rewrite\"", .{}),
            .Source => return out.print("\"source\"", .{}),
            .SourceOrganizeImports => return out.print("\"source.organizeImports\"", .{}),
            .SourceFixAll => return out.print("\"source.fixAll\"", .{}),
        }
    }
};

pub const CodeActionContext = struct {
    diagnostics: []const Diagnostic,
    only: ?[]CodeActionKind = null,
};

pub const FormattingOptions = struct {
    tabSize: u32,
    insertSpaces: bool,
    trimTrailingWhitespace: ?bool = null,
    insertFinalNewline: ?bool = null,
    trimFinalNewlines: ?bool = null,
};

pub const ServerInfo = struct {
    name: []const u8,
    version: ?[]const u8 = null,
};
