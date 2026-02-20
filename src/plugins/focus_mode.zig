const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Focus Mode plugin — highlight only the current paragraph/sentence.
/// Tracks focus state globally. Shows paragraph boundaries.
/// Commands: :focus, :focus.para, :focus.sentence
active: bool = false,

var g_focus_active: bool = false;
var g_focus_type: FocusType = .paragraph;

const FocusType = enum { paragraph, sentence, off };

pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "focus-mode", .version = "0.1.0", .author = "lazy-md contributors", .description = "Highlight current paragraph/sentence" };
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
        .{ .name = "focus", .description = "Toggle focus mode", .handler = &toggleFocus },
        .{ .name = "focus.para", .description = "Focus on paragraph", .handler = &focusPara },
        .{ .name = "focus.sentence", .description = "Focus on sentence", .handler = &focusSentence },
    };
}

fn toggleFocus(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    g_focus_active = !g_focus_active;
    if (g_focus_active) {
        g_focus_type = .paragraph;
        // Show current paragraph info
        const info = getParagraphBounds(editor);
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Focus ON (paragraph L{d}-L{d}, {d} lines)", .{ info.start + 1, info.end + 1, info.end - info.start + 1 }) catch "Focus ON";
        editor.status.set(msg, false);
    } else {
        g_focus_type = .off;
        editor.status.set("Focus OFF", false);
    }
}

fn focusPara(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    g_focus_active = true;
    g_focus_type = .paragraph;
    const info = getParagraphBounds(editor);
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Paragraph focus: L{d}-L{d} ({d} lines)", .{ info.start + 1, info.end + 1, info.end - info.start + 1 }) catch "Paragraph focus";
    editor.status.set(msg, false);
}

fn focusSentence(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    g_focus_active = true;
    g_focus_type = .sentence;
    // Count sentences on current line by counting periods
    const line = editor.buffer.getLine(editor.cursor_row);
    var sentences: usize = 0;
    for (line) |ch| {
        if (ch == '.' or ch == '!' or ch == '?') sentences += 1;
    }
    if (sentences == 0) sentences = 1;
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Sentence focus ON ({d} sentence(s) on line {d})", .{ sentences, editor.cursor_row + 1 }) catch "Sentence focus";
    editor.status.set(msg, false);
}

const ParaBounds = struct { start: usize, end: usize };

fn getParagraphBounds(editor: *Editor) ParaBounds {
    const total = editor.buffer.lineCount();
    if (total == 0) return .{ .start = 0, .end = 0 };
    const cur = editor.cursor_row;

    // Find paragraph start (first blank line going up, or start of file)
    var start = cur;
    while (start > 0) {
        const line = editor.buffer.getLine(start - 1);
        if (isBlankLine(line)) break;
        start -= 1;
    }

    // Find paragraph end (first blank line going down, or end of file)
    var end = cur;
    while (end + 1 < total) {
        const line = editor.buffer.getLine(end + 1);
        if (isBlankLine(line)) break;
        end += 1;
    }

    return .{ .start = start, .end = end };
}

fn isBlankLine(line: []const u8) bool {
    for (line) |ch| {
        if (ch != ' ' and ch != '\t' and ch != '\n' and ch != '\r') return false;
    }
    return true;
}

test "focus_mode plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("focus-mode", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "isBlankLine" {
    try std.testing.expect(isBlankLine(""));
    try std.testing.expect(isBlankLine("   "));
    try std.testing.expect(!isBlankLine("hello"));
}
