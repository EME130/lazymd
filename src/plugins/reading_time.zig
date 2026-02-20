const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Reading Time plugin — estimates reading time for the document.
/// Uses 200 WPM average reading speed. Scans buffer line-by-line.
/// Commands: :reading-time
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "reading-time", .version = "0.1.0", .author = "lazy-md contributors", .description = "Estimate document reading time" };
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
        .{ .name = "reading-time", .description = "Show estimated reading time", .handler = &showTime },
    };
}

fn showTime(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var words: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
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

    const minutes = words / 200;
    const seconds = (words % 200) * 60 / 200;
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Reading time: ~{d} min {d} sec ({d} words @ 200 wpm)", .{ minutes, seconds, words }) catch "Error";
    event.editor.status.set(msg, false);
}

test "reading_time plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("reading-time", p.pluginInfo().name);
}
