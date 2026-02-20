const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Mind Map plugin — generate ASCII mind maps from document headings.
/// Scans headings and creates tree-style visualization.
/// Commands: :mindmap, :mindmap.insert
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "mind-map", .version = "0.1.0", .author = "lazy-md contributors", .description = "ASCII mind map from headings" };
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
        .{ .name = "mindmap", .description = "Show heading tree", .handler = &showMap },
        .{ .name = "mindmap.insert", .description = "Insert ASCII mind map", .handler = &insertMap },
    };
}

fn headingLevel(line: []const u8) ?usize {
    var level: usize = 0;
    while (level < line.len and line[level] == '#') : (level += 1) {}
    if (level > 0 and level < line.len and line[level] == ' ') return level;
    return null;
}

fn headingText(line: []const u8) []const u8 {
    var i: usize = 0;
    while (i < line.len and line[i] == '#') : (i += 1) {}
    while (i < line.len and line[i] == ' ') : (i += 1) {}
    // Trim trailing whitespace/newline
    var end = line.len;
    while (end > i and (line[end - 1] == '\n' or line[end - 1] == '\r' or line[end - 1] == ' ')) : (end -= 1) {}
    return line[i..end];
}

fn showMap(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var count: usize = 0;
    var min_level: usize = 7;

    // Count headings and find structure
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (headingLevel(line)) |lvl| {
            count += 1;
            if (lvl < min_level) min_level = lvl;
        }
    }

    if (count == 0) {
        editor.status.set("No headings found for mind map", false);
        return;
    }

    var buf: [256]u8 = undefined;
    var pos: usize = 0;

    // Build compact tree preview
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (headingLevel(line)) |lvl| {
            const text = headingText(line);
            const depth = lvl - min_level;
            // Add indent
            var d: usize = 0;
            while (d < depth and pos + 2 < buf.len) : (d += 1) {
                buf[pos] = ' ';
                pos += 1;
                buf[pos] = ' ';
                pos += 1;
            }
            // Add branch marker
            if (pos + 2 < buf.len) {
                if (depth == 0) {
                    buf[pos] = '*';
                } else {
                    buf[pos] = '-';
                }
                pos += 1;
                buf[pos] = ' ';
                pos += 1;
            }
            // Add text
            const max_text = @min(text.len, buf.len - pos - 2);
            if (max_text > 0) {
                @memcpy(buf[pos .. pos + max_text], text[0..max_text]);
                pos += max_text;
            }
            if (pos + 1 < buf.len) {
                buf[pos] = ' ';
                pos += 1;
                buf[pos] = '|';
                pos += 1;
            }
            if (pos + 1 >= buf.len - 5) break;
        }
    }

    if (pos > 0 and buf[pos - 1] == '|') pos -= 1;
    editor.status.set(buf[0..pos], false);
}

fn insertMap(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [1024]u8 = undefined;
    var pos: usize = 0;

    // Header
    const header = "```\n";
    @memcpy(buf[pos .. pos + header.len], header);
    pos += header.len;

    var min_level: usize = 7;
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (headingLevel(line)) |lvl| {
            if (lvl < min_level) min_level = lvl;
        }
    }

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (headingLevel(line)) |lvl| {
            const text = headingText(line);
            const depth = lvl - min_level;
            // Indent
            var d: usize = 0;
            while (d < depth and pos + 4 < buf.len) : (d += 1) {
                @memcpy(buf[pos .. pos + 4], "    ");
                pos += 4;
            }
            // Branch
            if (depth == 0) {
                if (pos + 2 < buf.len) {
                    @memcpy(buf[pos .. pos + 2], "* ");
                    pos += 2;
                }
            } else {
                if (pos + 4 < buf.len) {
                    @memcpy(buf[pos .. pos + 4], "+-- ");
                    pos += 4;
                }
            }
            // Text
            const max = @min(text.len, buf.len - pos - 5);
            if (max > 0) {
                @memcpy(buf[pos .. pos + max], text[0..max]);
                pos += max;
            }
            buf[pos] = '\n';
            pos += 1;
            if (pos >= buf.len - 20) break;
        }
    }

    const footer = "```\n";
    if (pos + footer.len < buf.len) {
        @memcpy(buf[pos .. pos + footer.len], footer);
        pos += footer.len;
    }

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, buf[0..pos]) catch {
        editor.status.set("Failed to insert mind map", true);
        return;
    };
    editor.status.set("Mind map inserted", false);
}

test "mind_map plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("mind-map", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}

test "headingLevel" {
    try std.testing.expectEqual(@as(?usize, 1), headingLevel("# Hello"));
    try std.testing.expectEqual(@as(?usize, 2), headingLevel("## Sub"));
    try std.testing.expectEqual(@as(?usize, null), headingLevel("Not a heading"));
}
