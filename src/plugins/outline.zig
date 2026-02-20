const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Outline / Table of Contents plugin — shows document heading structure.
/// Scans buffer for markdown headings and shows them with line numbers.
/// :outline shows headings, :toc inserts a table of contents.
/// Commands: :outline, :toc
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "outline", .version = "0.1.0", .author = "lazy-md contributors", .description = "Document outline / table of contents" };
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
        .{ .name = "outline", .description = "Show document outline", .handler = &showOutline },
        .{ .name = "toc", .description = "Insert table of contents", .handler = &insertToc },
        .{ .name = "outline.next", .description = "Jump to next heading", .handler = &nextHeading },
        .{ .name = "outline.prev", .description = "Jump to previous heading", .handler = &prevHeading },
    };
}

fn showOutline(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    var heading_count: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        const level = headingLevel(line);
        if (level > 0) {
            heading_count += 1;
            // Format: "L<row>:<title> "
            const title = std.mem.trimLeft(u8, line[level..], " ");
            const short_title = if (title.len > 20) title[0..20] else title;
            const written = std.fmt.bufPrint(buf[pos..], "L{d}:{s} ", .{ row + 1, short_title }) catch break;
            pos += written.len;
            if (pos > 230) break; // leave room
        }
    }

    if (heading_count == 0) {
        editor.status.set("No headings found", false);
    } else {
        var header_buf: [256]u8 = undefined;
        const header = std.fmt.bufPrint(&header_buf, "Outline ({d}): {s}", .{ heading_count, buf[0..pos] }) catch "Outline";
        editor.status.set(header, false);
    }
}

fn insertToc(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var toc_buf: [1024]u8 = undefined;
    var pos: usize = 0;

    // Write TOC header
    const header = "## Table of Contents\n\n";
    @memcpy(toc_buf[pos .. pos + header.len], header);
    pos += header.len;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        const level = headingLevel(line);
        if (level > 0) {
            const title = std.mem.trimLeft(u8, line[level..], " ");
            // Indent based on level
            const indent = if (level > 1) level - 1 else 0;
            for (0..indent * 2) |_| {
                if (pos < toc_buf.len) {
                    toc_buf[pos] = ' ';
                    pos += 1;
                }
            }
            const written = std.fmt.bufPrint(toc_buf[pos..], "- {s}\n", .{title}) catch break;
            pos += written.len;
        }
    }

    if (pos == header.len) {
        editor.status.set("No headings to generate TOC", false);
        return;
    }

    // Insert newline after
    if (pos < toc_buf.len) {
        toc_buf[pos] = '\n';
        pos += 1;
    }

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, toc_buf[0..pos]) catch {
        editor.status.set("Failed to insert TOC", true);
        return;
    };
    editor.status.set("Table of contents inserted", false);
}

fn nextHeading(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    for (editor.cursor_row + 1..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (headingLevel(line) > 0) {
            editor.cursor_row = row;
            editor.cursor_col = 0;
            editor.desired_col = 0;
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Heading at line {d}", .{row + 1}) catch "Heading";
            editor.status.set(msg, false);
            return;
        }
    }
    editor.status.set("No more headings below", false);
}

fn prevHeading(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    if (editor.cursor_row == 0) {
        editor.status.set("No headings above", false);
        return;
    }
    var row = editor.cursor_row - 1;
    while (true) {
        const line = editor.buffer.getLine(row);
        if (headingLevel(line) > 0) {
            editor.cursor_row = row;
            editor.cursor_col = 0;
            editor.desired_col = 0;
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Heading at line {d}", .{row + 1}) catch "Heading";
            editor.status.set(msg, false);
            return;
        }
        if (row == 0) break;
        row -= 1;
    }
    editor.status.set("No headings above", false);
}

fn headingLevel(line: []const u8) usize {
    var level: usize = 0;
    for (line) |c| {
        if (c == '#') {
            level += 1;
        } else break;
    }
    if (level > 0 and level < line.len and line[level] == ' ') return level;
    return 0;
}

test "outline plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("outline", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 4), cmds.len);
}

test "headingLevel" {
    try std.testing.expectEqual(@as(usize, 1), headingLevel("# Title"));
    try std.testing.expectEqual(@as(usize, 2), headingLevel("## Subtitle"));
    try std.testing.expectEqual(@as(usize, 3), headingLevel("### Section"));
    try std.testing.expectEqual(@as(usize, 0), headingLevel("Not a heading"));
    try std.testing.expectEqual(@as(usize, 0), headingLevel("#NoSpace"));
    try std.testing.expectEqual(@as(usize, 0), headingLevel(""));
}
