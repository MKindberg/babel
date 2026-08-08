const std = @import("std");

const types = @import("types.zig");
const rpc = @import("rpc.zig");
const LspSettings = @import("lsp.zig").LspSettings;

pub fn MethodSpecs(settings: LspSettings) type {
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
                .@"textDocument/didOpen" => struct {},
                .@"textDocument/didChange" => struct {},
                .@"textDocument/didSave" => struct {
                    pub fn setCapability(server_data: *types.ServerData) void {
                        server_data.capabilities.textDocumentSync.save = .{ .includeText = settings.full_text_on_save };
                    }
                },
                .@"textDocument/didClose" => struct {},
                .exit => struct {},
                .@"$/setTrace" => struct {},
                .@"$/cancelRequest" => struct {},
            };
        field_attrs[i] = .{ .default_value_ptr = &field_types[i]{} };
    }
    return @Struct(.auto, null, &field_names, &field_types, &field_attrs);
}
