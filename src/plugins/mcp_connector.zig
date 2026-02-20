const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// MCP Connector plugin — Model Context Protocol for AI agent integration.
/// Exposes vault contents and editor state via MCP-compatible JSON.
/// Commands: :mcp, :mcp.export, :mcp.context
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "mcp-connector", .version = "0.1.0", .author = "lazy-md contributors", .description = "MCP protocol for AI agent access" };
}
pub fn pluginInit(self: *Self, editor: *Editor) void {
    _ = self;
    _ = editor;
}
pub fn pluginDeinit(self: *Self) void {
    _ = self;
}
pub fn onEvent(self: *Self, event: *plugin.PluginEvent) void {
    _ = self;
    _ = event;
}
pub fn getCommands(self: *Self) []const plugin.CommandDef {
    _ = self;
    return &[_]plugin.CommandDef{
        .{ .name = "mcp", .description = "Show MCP status and vault info", .handler = &mcpStatus },
        .{ .name = "mcp.export", .description = "Export buffer as MCP context JSON", .handler = &mcpExport },
        .{ .name = "mcp.context", .description = "Insert AI context block", .handler = &mcpContext },
    };
}

fn mcpStatus(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Show vault stats for MCP context
    var file_count: usize = 0;
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("MCP: vault scan failed", true);
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and (std.mem.endsWith(u8, entry.name, ".md") or std.mem.endsWith(u8, entry.name, ".rndm"))) {
            file_count += 1;
        }
    }

    const lines = editor.buffer.lineCount();
    const file_name = editor.file_path orelse "untitled";

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "MCP: {d} vault notes, current: {s} ({d} lines)", .{ file_count, file_name, lines }) catch "MCP ready";
    editor.status.set(msg, false);
}

fn mcpExport(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    std.fs.cwd().makeDir(".lazy-md") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {},
    };

    const file = std.fs.cwd().createFile(".lazy-md/mcp-context.json", .{}) catch {
        editor.status.set("Failed to create MCP context file", true);
        return;
    };
    defer file.close();

    // Write JSON context
    const file_name = editor.file_path orelse "untitled";

    var header_buf: [256]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf,
        \\{{
        \\  "type": "mcp-context",
        \\  "file": "{s}",
        \\  "lines": {d},
        \\  "cursor_row": {d},
        \\  "cursor_col": {d},
        \\  "content": "
    , .{ file_name, editor.buffer.lineCount(), editor.cursor_row, editor.cursor_col }) catch {
        editor.status.set("Export error", true);
        return;
    };
    file.writeAll(header) catch {};

    // Write content (escaped for JSON)
    for (0..@min(editor.buffer.lineCount(), 100)) |row| {
        const line = editor.buffer.getLine(row);
        for (line) |ch| {
            switch (ch) {
                '"' => file.writeAll("\\\"") catch {},
                '\\' => file.writeAll("\\\\") catch {},
                '\n' => file.writeAll("\\n") catch {},
                '\r' => {},
                '\t' => file.writeAll("\\t") catch {},
                else => file.writeAll(&[_]u8{ch}) catch {},
            }
        }
        file.writeAll("\\n") catch {};
    }

    file.writeAll("\"\n}\n") catch {};

    editor.status.set("MCP context exported to .lazy-md/mcp-context.json", false);
}

fn mcpContext(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const context = event.command_args orelse "general";

    var buf: [256]u8 = undefined;
    const block = std.fmt.bufPrint(&buf,
        \\
        \\<!-- MCP Context: {s} -->
        \\<!-- AI agents can read this block for context -->
        \\<!-- vault: lazy-md, format: markdown -->
        \\
        \\
    , .{context}) catch {
        editor.status.set("Context error", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, block) catch {
        editor.status.set("Insert failed", true);
        return;
    };
    editor.status.set("MCP context block inserted", false);
}

test "mcp_connector plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("mcp-connector", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
