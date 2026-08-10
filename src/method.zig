const std = @import("std");

const types = @import("types.zig");
const rpc = @import("rpc.zig");
const logger = @import("logger.zig");
const LspSettings = @import("lsp.zig").LspSettings;

pub fn MethodSpecs(Lsp: type, settings: LspSettings) type {
    const tag_type = @typeInfo(rpc.MethodType).@"union".tag_type.?;
    const tags = @typeInfo(tag_type).@"enum".fields;
    var field_names: [tags.len][]const u8 = undefined;
    var field_types: [tags.len]type = undefined;
    var field_attrs: [tags.len]std.builtin.Type.StructField.Attributes = undefined;
    inline for (tags, 0..) |t, i| {
        field_names[i] = t.name;
        const tag: tag_type = @enumFromInt(t.value);
        field_types[i] =
            switch (tag) {
                .initialize => struct {},
                .@"textDocument/hover" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.hoverProvider = true;
                    }
                },
                .@"textDocument/declaration" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.declarationProvider = true;
                    }
                },
                .@"textDocument/definition" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.definitionProvider = true;
                    }
                },
                .@"textDocument/typeDefinition" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.typeDefinitionProvider = true;
                    }
                },
                .@"textDocument/implementation" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.implementationProvider = true;
                    }
                },
                .@"textDocument/references" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.referencesProvider = true;
                    }
                },
                .@"textDocument/codeAction" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.codeActionProvider = true;
                    }
                },
                .shutdown => struct {},
                .@"textDocument/completion" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.completionProvider = .{};
                    }
                },
                .@"textDocument/formatting" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.documentFormattingProvider = true;
                    }
                },
                .@"textDocument/rangeFormatting" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.documentRangeFormattingProvider = true;
                    }
                },
                .@"textDocument/documentColor" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.colorProvider = true;
                    }
                },
                .@"textDocument/codeLens" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.codeLensProvider = .{};
                    }
                },
                .initialized => struct {},
                .@"textDocument/didOpen" => struct {
                    pub fn preCallback(lsp: *Lsp, params: types.Notification.DidOpenTextDocument.Params) !void {
                        try lsp.openDocument(params.textDocument.uri, params.textDocument.languageId, params.textDocument.text);
                    }
                },
                .@"textDocument/didChange" => struct {
                    pub fn preCallback(lsp: *Lsp, params: types.Notification.DidChangeTextDocument.Params) !void {
                        const context = lsp.contexts.getPtr(params.textDocument.uri).?;
                        if (settings.update_doc_on_change) {
                            try context.document.updateAll(params.contentChanges);
                        }
                    }
                },
                .@"textDocument/didSave" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.textDocumentSync.save = .{ .includeText = settings.full_text_on_save };
                    }
                    pub fn preCallback(lsp: *Lsp, params: types.Notification.DidSaveTextDocument.Params) !void {
                        const context = lsp.contexts.getPtr(params.textDocument.uri).?;
                        if (params.text) |text| {
                            try context.document.update(.{ .text = text, .range = null });
                        }
                    }
                },
                .@"textDocument/didClose" => struct {
                    pub fn postCallback(lsp: *Lsp, params: types.Notification.DidCloseTextDocument.Params) !void {
                        var entry = lsp.contexts.fetchRemove(params.textDocument.uri).?;
                        lsp.allocator.free(entry.key);
                        entry.value.document.deinit();
                    }
                },
                .exit => struct {},
                .@"$/setTrace" => struct {
                    pub fn preCallback(_: *Lsp, params: types.Notification.SetTrace.Params) !void {
                        logger.trace_value = params.value;
                    }
                },
                .@"$/cancelRequest" => struct {},
            };
        field_attrs[i] = .{ .default_value_ptr = &field_types[i]{} };
    }
    return @Struct(.auto, null, &field_names, &field_types, &field_attrs);
}
