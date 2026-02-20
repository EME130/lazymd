const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Word Count plugin — displays word, line, and character counts.
/// Scans buffer line-by-line for accurate counts.
/// Commands: :wc
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "word-count", .version = "0.1.0", .author = "lazy-md contributors", .description = "Word, line, and character counts" };
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
        .{ .name = "wc", .description = "Show word/line/char count", .handler = &wordCount },
    };
}

fn wordCount(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var words: usize = 0;
    var chars: usize = 0;
    const lines = editor.buffer.lineCount();

    for (0..lines) |row| {
        const line = editor.buffer.getLine(row);
        chars += line.len;
        var in_word = false;
        for (line) |c| {
            if (c == ' ' or c == '\t') {
                in_word = false;
            } else if (!in_word) {
                in_word = true;
                words += 1;
            }
        }
    }
    // Add newlines to char count
    if (lines > 1) chars += lines - 1;

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "{d} words, {d} lines, {d} chars", .{ words, lines, chars }) catch "Count error";
    event.editor.status.set(msg, false);
}

test "word_count plugin info" {
    var p = Self{};
    const info = p.pluginInfo();
    try std.testing.expectEqualStrings("word-count", info.name);
}
