const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Note Refactor plugin — split notes and extract sections.
/// :refactor.split splits at cursor, moving everything below into a new file.
/// :refactor.extract extracts current heading section to a new file.
/// Commands: :refactor.extract, :refactor.split
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "note-refactor", .version = "0.1.0", .author = "lazy-md contributors", .description = "Extract and split notes" };
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
        .{ .name = "refactor.extract", .description = "Extract heading section to new note", .handler = &extract },
        .{ .name = "refactor.split", .description = "Split note at cursor into two", .handler = &split },
    };
}

fn extract(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const target = event.command_args orelse {
        editor.status.set("Usage: :refactor.extract <new-filename.md>", true);
        return;
    };

    // Find current heading and its section
    var heading_row: ?usize = null;
    var heading_level: usize = 0;

    // Search backwards for heading
    var search_row = editor.cursor_row;
    while (true) {
        const line = editor.buffer.getLine(search_row);
        const level = headingLevel(line);
        if (level > 0) {
            heading_row = search_row;
            heading_level = level;
            break;
        }
        if (search_row == 0) break;
        search_row -= 1;
    }

    if (heading_row == null) {
        editor.status.set("No heading found above cursor", true);
        return;
    }

    // Find end of section (next heading of same or higher level)
    var end_row = editor.buffer.lineCount();
    for (heading_row.? + 1..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        const level = headingLevel(line);
        if (level > 0 and level <= heading_level) {
            end_row = row;
            break;
        }
    }

    // Collect section content
    var content_buf: [4096]u8 = undefined;
    var pos: usize = 0;
    for (heading_row.?..end_row) |row| {
        const line = editor.buffer.getLine(row);
        if (pos + line.len + 1 < content_buf.len) {
            @memcpy(content_buf[pos .. pos + line.len], line);
            pos += line.len;
            content_buf[pos] = '\n';
            pos += 1;
        }
    }

    // Write to new file
    const file = std.fs.cwd().createFile(target, .{ .exclusive = true }) catch {
        editor.status.set("File already exists", true);
        return;
    };
    file.writeAll(content_buf[0..pos]) catch {
        file.close();
        editor.status.set("Failed to write file", true);
        return;
    };
    file.close();

    // Delete section from current document
    const start_offset = editor.buffer.posToOffset(heading_row.?, 0);
    const end_offset = editor.buffer.posToOffset(end_row, 0);
    if (end_offset > start_offset) {
        editor.buffer.deleteRange(start_offset, end_offset - start_offset) catch {};
    }

    // Insert wiki-link in place
    var link_buf: [128]u8 = undefined;
    const stem = blk: {
        if (std.mem.lastIndexOfScalar(u8, target, '.')) |dot| break :blk target[0..dot];
        break :blk target;
    };
    const link = std.fmt.bufPrint(&link_buf, "[[{s}]]\n", .{stem}) catch "";
    editor.buffer.insertSlice(start_offset, link) catch {};

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Section extracted to {s}", .{target}) catch "Extracted";
    editor.status.set(msg, false);
}

fn split(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const target = event.command_args orelse {
        editor.status.set("Usage: :refactor.split <new-filename.md>", true);
        return;
    };

    // Everything from cursor_row to end goes to new file
    var content_buf: [4096]u8 = undefined;
    var pos: usize = 0;

    for (editor.cursor_row..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (pos + line.len + 1 < content_buf.len) {
            @memcpy(content_buf[pos .. pos + line.len], line);
            pos += line.len;
            content_buf[pos] = '\n';
            pos += 1;
        }
    }

    // Write new file
    const file = std.fs.cwd().createFile(target, .{ .exclusive = true }) catch {
        editor.status.set("File already exists", true);
        return;
    };
    file.writeAll(content_buf[0..pos]) catch {
        file.close();
        editor.status.set("Failed to write file", true);
        return;
    };
    file.close();

    // Delete from cursor to end
    const start_offset = editor.buffer.posToOffset(editor.cursor_row, 0);
    const end_offset = editor.buffer.length();
    if (end_offset > start_offset) {
        editor.buffer.deleteRange(start_offset, end_offset - start_offset) catch {};
    }

    // Insert link to new file
    var link_buf: [128]u8 = undefined;
    const stem = blk: {
        if (std.mem.lastIndexOfScalar(u8, target, '.')) |dot| break :blk target[0..dot];
        break :blk target;
    };
    const link = std.fmt.bufPrint(&link_buf, "\n[[{s}]]\n", .{stem}) catch "";
    editor.buffer.insertSlice(start_offset, link) catch {};

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Note split — continued in {s}", .{target}) catch "Split";
    editor.status.set(msg, false);
}

fn headingLevel(line: []const u8) usize {
    var level: usize = 0;
    for (line) |c| {
        if (c == '#') level += 1 else break;
    }
    if (level > 0 and level < line.len and line[level] == ' ') return level;
    return 0;
}

test "note_refactor plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("note-refactor", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
