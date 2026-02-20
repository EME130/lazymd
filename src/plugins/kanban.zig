const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Kanban plugin — markdown-based kanban board using heading columns.
/// Reads ## headings as columns and - [ ]/- [x] items as cards.
/// :kanban shows board summary, :kanban.new creates a board template.
/// Commands: :kanban, :kanban.new, :kanban.move
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "kanban", .version = "0.1.0", .author = "lazy-md contributors", .description = "Markdown-based kanban board" };
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
        .{ .name = "kanban", .description = "Show kanban board summary", .handler = &showKanban },
        .{ .name = "kanban.new", .description = "Create kanban board template", .handler = &newBoard },
        .{ .name = "kanban.add", .description = "Add card to column", .handler = &addCard },
    };
}

fn showKanban(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    var current_col: []const u8 = "";
    var col_count: usize = 0;
    var card_count: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);

        // ## heading = column
        if (line.len > 3 and line[0] == '#' and line[1] == '#' and line[2] == ' ') {
            if (col_count > 0 and pos > 0) {
                const written = std.fmt.bufPrint(buf[pos..], "({d}) ", .{card_count}) catch break;
                pos += written.len;
            }
            current_col = line[3..];
            col_count += 1;
            card_count = 0;
            const written = std.fmt.bufPrint(buf[pos..], "{s}", .{current_col[0..@min(current_col.len, 15)]}) catch break;
            pos += written.len;
        }

        // - [ ] or - [x] = card
        if (line.len > 5 and line[0] == '-' and line[1] == ' ' and line[2] == '[') {
            card_count += 1;
        }
    }

    if (col_count > 0 and pos > 0) {
        const written = std.fmt.bufPrint(buf[pos..], "({d})", .{card_count}) catch "";
        pos += written.len;
    }

    if (col_count == 0) {
        editor.status.set("No kanban board found. Use :kanban.new to create one", false);
    } else {
        var header_buf: [256]u8 = undefined;
        const header = std.fmt.bufPrint(&header_buf, "Kanban ({d} cols): {s}", .{ col_count, buf[0..pos] }) catch "Board found";
        editor.status.set(header, false);
    }
}

fn newBoard(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const template =
        \\# Kanban Board
        \\
        \\## Backlog
        \\
        \\- [ ] Task 1
        \\- [ ] Task 2
        \\
        \\## In Progress
        \\
        \\- [ ] Task 3
        \\
        \\## Done
        \\
        \\- [x] Task 4
        \\
    ;
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, template) catch {
        editor.status.set("Failed to insert board", true);
        return;
    };
    editor.status.set("Kanban board created", false);
}

fn addCard(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const title = event.command_args orelse {
        editor.status.set("Usage: :kanban.add <task title>", true);
        return;
    };

    // Insert a task after the current line
    var card_buf: [128]u8 = undefined;
    const card = std.fmt.bufPrint(&card_buf, "\n- [ ] {s}", .{title}) catch {
        editor.status.set("Title too long", true);
        return;
    };

    const line_end = editor.buffer.posToOffset(editor.cursor_row, editor.buffer.getLineLen(editor.cursor_row));
    editor.buffer.insertSlice(line_end, card) catch {
        editor.status.set("Failed to add card", true);
        return;
    };
    editor.cursor_row += 1;
    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Added: {s}", .{title}) catch "Card added";
    editor.status.set(msg, false);
}

test "kanban plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("kanban", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
