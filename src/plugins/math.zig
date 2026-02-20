const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Math plugin — insert LaTeX math blocks and inline math.
/// Uses $...$ for inline and $$...$$ for display math.
/// Commands: :math, :math.inline, :math.block
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "math", .version = "0.1.0", .author = "lazy-md contributors", .description = "LaTeX math expression support" };
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
        .{ .name = "math", .description = "Insert inline math $...$", .handler = &insertInline },
        .{ .name = "math.block", .description = "Insert display math block", .handler = &insertBlock },
        .{ .name = "math.count", .description = "Count math expressions", .handler = &countMath },
    };
}

fn insertInline(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const expr = event.command_args orelse "\\text{}";

    var buf: [128]u8 = undefined;
    const math = std.fmt.bufPrint(&buf, "${s}$", .{expr}) catch {
        editor.status.set("Expression too long", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, math) catch {
        editor.status.set("Failed to insert math", true);
        return;
    };
    editor.cursor_col += math.len;
    editor.status.set("Inline math inserted", false);
}

fn insertBlock(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const template = "\n$$\n\n$$\n";
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, template) catch {
        editor.status.set("Failed to insert math block", true);
        return;
    };
    editor.status.set("Math block inserted — enter expression between $$", false);
}

fn countMath(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var inline_count: usize = 0;
    var block_count: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        // Count $...$ (inline)
        var i: usize = 0;
        while (i < line.len) : (i += 1) {
            if (line[i] == '$') {
                if (i + 1 < line.len and line[i + 1] == '$') {
                    block_count += 1;
                    i += 1;
                } else {
                    inline_count += 1;
                }
            }
        }
    }

    // Divide by 2 (open + close pairs)
    inline_count /= 2;
    block_count /= 2;

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Math: {d} inline, {d} display blocks", .{ inline_count, block_count }) catch "Math counted";
    editor.status.set(msg, false);
}

test "math plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("math", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
