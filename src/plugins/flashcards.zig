const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Flashcards plugin — create flashcards from markdown using Q:/A: format.
/// Scans document for "Q: question" / "A: answer" pairs.
/// Commands: :flash, :flash.add, :flash.count
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "flashcards", .version = "0.1.0", .author = "lazy-md contributors", .description = "Spaced repetition flashcards" };
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
        .{ .name = "flash", .description = "Show flashcard stats", .handler = &showStats },
        .{ .name = "flash.add", .description = "Insert Q/A template at cursor", .handler = &addCard },
        .{ .name = "flash.review", .description = "Show random question", .handler = &review },
    };
}

fn showStats(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var questions: usize = 0;
    var answers: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (std.mem.startsWith(u8, line, "Q:") or std.mem.startsWith(u8, line, "**Q:**")) {
            questions += 1;
        }
        if (std.mem.startsWith(u8, line, "A:") or std.mem.startsWith(u8, line, "**A:**")) {
            answers += 1;
        }
    }

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Flashcards: {d} questions, {d} answers", .{ questions, answers }) catch "Stats";
    editor.status.set(msg, false);
}

fn addCard(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const template = "\nQ: \nA: \n";
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, template) catch {
        editor.status.set("Failed to insert card", true);
        return;
    };
    editor.cursor_row += 1;
    editor.cursor_col = 3;
    editor.status.set("Flashcard template inserted — type question after Q:", false);
}

fn review(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Find a Q: line to show
    var q_count: usize = 0;
    var last_q_row: ?usize = null;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (std.mem.startsWith(u8, line, "Q:") or std.mem.startsWith(u8, line, "**Q:**")) {
            q_count += 1;
            // Use timestamp-based selection
            const ts: u64 = @intCast(std.time.timestamp());
            if ((ts +% q_count) % q_count == 0) {
                last_q_row = row;
            }
        }
    }

    if (last_q_row) |row| {
        editor.cursor_row = row;
        editor.cursor_col = 0;
        const line = editor.buffer.getLine(row);
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Review ({d} cards): {s}", .{ q_count, line[0..@min(line.len, 80)] }) catch "Review";
        editor.status.set(msg, false);
    } else {
        editor.status.set("No flashcards found. Use :flash.add to create Q:/A: pairs", false);
    }
}

test "flashcards plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("flashcards", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
