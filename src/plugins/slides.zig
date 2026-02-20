const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Slides plugin — present markdown as terminal slides.
/// Uses --- (horizontal rule) as slide delimiters.
/// Commands: :slides, :slides.next, :slides.prev, :slides.new
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "slides", .version = "0.1.0", .author = "lazy-md contributors", .description = "Terminal presentation slides" };
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
        .{ .name = "slides", .description = "Show slide info", .handler = &slideInfo },
        .{ .name = "slides.next", .description = "Jump to next slide", .handler = &nextSlide },
        .{ .name = "slides.prev", .description = "Jump to previous slide", .handler = &prevSlide },
        .{ .name = "slides.new", .description = "Insert slide delimiter", .handler = &newSlide },
    };
}

fn countSlides(editor: *Editor) usize {
    var count: usize = 1; // First slide is implicit
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (isSlideDelimiter(line)) count += 1;
    }
    return count;
}

fn currentSlide(editor: *Editor) usize {
    var slide: usize = 1;
    for (0..editor.cursor_row) |row| {
        const line = editor.buffer.getLine(row);
        if (isSlideDelimiter(line)) slide += 1;
    }
    return slide;
}

fn isSlideDelimiter(line: []const u8) bool {
    const trimmed = std.mem.trimLeft(u8, line, " ");
    if (trimmed.len < 3) return false;
    var dashes: usize = 0;
    for (trimmed) |c| {
        if (c == '-') dashes += 1 else if (c != ' ') return false;
    }
    return dashes >= 3;
}

fn slideInfo(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const total = countSlides(editor);
    const current = currentSlide(editor);
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Slide {d}/{d}", .{ current, total }) catch "Slides";
    editor.status.set(msg, false);
}

fn nextSlide(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    for (editor.cursor_row + 1..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (isSlideDelimiter(line) and row + 1 < editor.buffer.lineCount()) {
            editor.cursor_row = row + 1;
            editor.cursor_col = 0;
            editor.desired_col = 0;
            const total = countSlides(editor);
            const current = currentSlide(editor);
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Slide {d}/{d}", .{ current, total }) catch "Next";
            editor.status.set(msg, false);
            return;
        }
    }
    editor.status.set("Last slide", false);
}

fn prevSlide(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    if (editor.cursor_row < 2) {
        editor.status.set("First slide", false);
        return;
    }
    var row = editor.cursor_row - 1;
    while (row > 0) : (row -= 1) {
        const line = editor.buffer.getLine(row);
        if (isSlideDelimiter(line)) {
            // Jump to content before this delimiter
            if (row > 0) {
                editor.cursor_row = row - 1;
                // Find the previous delimiter or start of file
                while (editor.cursor_row > 0) {
                    const prev = editor.buffer.getLine(editor.cursor_row - 1);
                    if (isSlideDelimiter(prev)) break;
                    editor.cursor_row -= 1;
                }
            }
            editor.cursor_col = 0;
            editor.desired_col = 0;
            editor.status.set("Previous slide", false);
            return;
        }
    }
    editor.cursor_row = 0;
    editor.cursor_col = 0;
    editor.status.set("First slide", false);
}

fn newSlide(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const delimiter = "\n\n---\n\n";
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.buffer.getLineLen(editor.cursor_row));
    editor.buffer.insertSlice(offset, delimiter) catch {
        editor.status.set("Failed to insert slide", true);
        return;
    };
    editor.status.set("New slide delimiter inserted", false);
}

test "slides plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("slides", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 4), cmds.len);
}
