const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Footnotes plugin — manage markdown footnotes.
/// Inserts [^N] references and [^N]: definitions at the end.
/// Commands: :fn.add, :fn.list
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "footnotes", .version = "0.1.0", .author = "lazy-md contributors", .description = "Markdown footnote management" };
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
        .{ .name = "fn.add", .description = "Add footnote at cursor", .handler = &addFootnote },
        .{ .name = "fn.list", .description = "List all footnotes", .handler = &listFootnotes },
    };
}

fn addFootnote(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Count existing footnotes to determine next number
    var max_fn: usize = 0;
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (std.mem.startsWith(u8, line, "[^")) {
            // Parse the number
            var i: usize = 2;
            var num: usize = 0;
            while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
                num = num * 10 + (line[i] - '0');
            }
            if (num > max_fn) max_fn = num;
        }
    }

    const next_fn = max_fn + 1;

    // Insert reference at cursor
    var ref_buf: [16]u8 = undefined;
    const ref = std.fmt.bufPrint(&ref_buf, "[^{d}]", .{next_fn}) catch return;
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, ref) catch {
        editor.status.set("Failed to insert footnote", true);
        return;
    };

    // Insert definition at end of document
    var def_buf: [64]u8 = undefined;
    const def = std.fmt.bufPrint(&def_buf, "\n[^{d}]: ", .{next_fn}) catch return;
    const end_offset = editor.buffer.length();
    editor.buffer.insertSlice(end_offset, def) catch return;

    editor.cursor_col += ref.len;
    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Footnote [^{d}] added — definition at end of file", .{next_fn}) catch "Footnote added";
    editor.status.set(msg, false);
}

fn listFootnotes(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var count: usize = 0;
    var buf: [256]u8 = undefined;
    var pos: usize = 0;

    const prefix = "Footnotes: ";
    @memcpy(buf[0..prefix.len], prefix);
    pos = prefix.len;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (std.mem.startsWith(u8, line, "[^") and std.mem.indexOf(u8, line, "]:") != null) {
            count += 1;
            const colon = std.mem.indexOf(u8, line, "]:") orelse continue;
            const ref = line[0 .. colon + 2];
            const def_start = @min(colon + 3, line.len);
            const def = line[def_start..@min(def_start + 30, line.len)];
            const written = std.fmt.bufPrint(buf[pos..], "L{d} {s}{s} ", .{ row + 1, ref, def }) catch break;
            pos += written.len;
        }
    }

    if (count == 0) {
        editor.status.set("No footnotes in document", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

test "footnotes plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("footnotes", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
