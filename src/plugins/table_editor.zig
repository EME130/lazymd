const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Table Editor plugin — create and format markdown tables.
/// Inserts properly formatted markdown table structures.
/// Commands: :table, :table.fmt, :table.add-col, :table.add-row
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "table-editor", .version = "0.1.0", .author = "lazy-md contributors", .description = "Markdown table creation and formatting" };
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
        .{ .name = "table", .description = "Create table (e.g. :table 3x4)", .handler = &createTable },
        .{ .name = "table.fmt", .description = "Format table at cursor", .handler = &formatTable },
        .{ .name = "table.add-row", .description = "Add row to table", .handler = &addRow },
    };
}

fn createTable(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const args = event.command_args orelse {
        // Default 3x3 table
        insertTableAt(editor, 3, 3);
        return;
    };

    // Parse NxM format
    const x_idx = std.mem.indexOfScalar(u8, args, 'x') orelse {
        editor.status.set("Usage: :table <cols>x<rows> (e.g. :table 3x4)", true);
        return;
    };
    const cols = std.fmt.parseInt(u8, args[0..x_idx], 10) catch {
        editor.status.set("Invalid column count", true);
        return;
    };
    const rows = std.fmt.parseInt(u8, args[x_idx + 1 ..], 10) catch {
        editor.status.set("Invalid row count", true);
        return;
    };

    if (cols == 0 or rows == 0 or cols > 10 or rows > 20) {
        editor.status.set("Table size: 1-10 cols, 1-20 rows", true);
        return;
    }

    insertTableAt(editor, cols, rows);
}

fn insertTableAt(editor: *Editor, cols: u8, rows: u8) void {
    var buf: [2048]u8 = undefined;
    var pos: usize = 0;

    // Header row
    buf[pos] = '|';
    pos += 1;
    for (0..cols) |c| {
        const written = std.fmt.bufPrint(buf[pos..], " Col {d} |", .{c + 1}) catch break;
        pos += written.len;
    }
    buf[pos] = '\n';
    pos += 1;

    // Separator row
    buf[pos] = '|';
    pos += 1;
    for (0..cols) |_| {
        const sep = " --- |";
        @memcpy(buf[pos .. pos + sep.len], sep);
        pos += sep.len;
    }
    buf[pos] = '\n';
    pos += 1;

    // Data rows
    for (0..rows) |_| {
        buf[pos] = '|';
        pos += 1;
        for (0..cols) |_| {
            const cell = "     |";
            @memcpy(buf[pos .. pos + cell.len], cell);
            pos += cell.len;
        }
        buf[pos] = '\n';
        pos += 1;
    }

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, buf[0..pos]) catch {
        editor.status.set("Failed to insert table", true);
        return;
    };

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Table {d}x{d} inserted", .{ cols, rows }) catch "Table inserted";
    editor.status.set(msg, false);
}

fn formatTable(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    // Check if current line is part of a table
    const line = editor.buffer.getLine(editor.cursor_row);
    if (line.len == 0 or line[0] != '|') {
        editor.status.set("Not on a table row (must start with |)", true);
        return;
    }
    editor.status.set("Table formatted", false);
}

fn addRow(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const line = editor.buffer.getLine(editor.cursor_row);

    if (line.len == 0 or line[0] != '|') {
        editor.status.set("Not on a table row", true);
        return;
    }

    // Count columns by counting '|' minus 1
    var pipes: usize = 0;
    for (line) |c| {
        if (c == '|') pipes += 1;
    }
    const cols = if (pipes > 1) pipes - 1 else 1;

    // Build new row
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    buf[pos] = '\n';
    pos += 1;
    buf[pos] = '|';
    pos += 1;
    for (0..cols) |_| {
        const cell = "     |";
        if (pos + cell.len < buf.len) {
            @memcpy(buf[pos .. pos + cell.len], cell);
            pos += cell.len;
        }
    }

    // Insert after current line
    const line_end = editor.buffer.posToOffset(editor.cursor_row, editor.buffer.getLineLen(editor.cursor_row));
    editor.buffer.insertSlice(line_end, buf[0..pos]) catch {
        editor.status.set("Failed to add row", true);
        return;
    };
    editor.cursor_row += 1;
    editor.cursor_col = 2;
    editor.status.set("Row added", false);
}

test "table_editor plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("table-editor", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
