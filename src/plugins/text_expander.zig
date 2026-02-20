const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Text Expander plugin — shorthand text expansion.
/// Built-in expansions for dates, times, common markdown.
/// Commands: :expand, :expand.add, :expand.date, :expand.time
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "text-expander", .version = "0.1.0", .author = "lazy-md contributors", .description = "Shorthand text expansion" };
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
        .{ .name = "expand", .description = "Expand shorthand at cursor", .handler = &expandAtCursor },
        .{ .name = "expand.list", .description = "Show available expansions", .handler = &showRules },
        .{ .name = "expand.date", .description = "Insert today's date", .handler = &insertDate },
        .{ .name = "expand.time", .description = "Insert current time", .handler = &insertTime },
    };
}

const Expansion = struct {
    trigger: []const u8,
    replacement: []const u8,
};

const builtin_expansions = [_]Expansion{
    .{ .trigger = ";sig", .replacement = "---\n*lazy-md user*\n" },
    .{ .trigger = ";br", .replacement = "<br>\n" },
    .{ .trigger = ";hr", .replacement = "\n---\n\n" },
    .{ .trigger = ";todo", .replacement = "- [ ] " },
    .{ .trigger = ";done", .replacement = "- [x] " },
    .{ .trigger = ";cb", .replacement = "```\n\n```\n" },
    .{ .trigger = ";note", .replacement = "> [!note]\n> " },
    .{ .trigger = ";warn", .replacement = "> [!warning]\n> " },
    .{ .trigger = ";tip", .replacement = "> [!tip]\n> " },
    .{ .trigger = ";toc", .replacement = "## Table of Contents\n\n" },
    .{ .trigger = ";fm", .replacement = "---\ntitle: \"\"\ndate: \ntags: []\n---\n\n" },
};

fn expandAtCursor(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Check word before cursor on current line
    const line = editor.buffer.getLine(editor.cursor_row);
    const col = @min(editor.cursor_col, line.len);

    // Find word start
    var word_start = col;
    while (word_start > 0 and line[word_start - 1] != ' ' and line[word_start - 1] != '\t') {
        word_start -= 1;
    }
    const word = line[word_start..col];

    // Check builtins
    for (&builtin_expansions) |*exp| {
        if (std.mem.eql(u8, word, exp.trigger)) {
            // Delete trigger and insert replacement
            const offset = editor.buffer.posToOffset(editor.cursor_row, word_start);
            const end_offset = editor.buffer.posToOffset(editor.cursor_row, col);
            editor.buffer.deleteRange(offset, end_offset) catch {
                editor.status.set("Expand failed", true);
                return;
            };
            editor.buffer.insertSlice(offset, exp.replacement) catch {
                editor.status.set("Expand insert failed", true);
                return;
            };
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Expanded: {s}", .{exp.trigger}) catch "Expanded";
            editor.status.set(msg, false);
            return;
        }
    }

    // Try date/time shorthands
    if (std.mem.eql(u8, word, ";date") or std.mem.eql(u8, word, ";d")) {
        const offset = editor.buffer.posToOffset(editor.cursor_row, word_start);
        const end_offset = editor.buffer.posToOffset(editor.cursor_row, col);
        editor.buffer.deleteRange(offset, end_offset) catch return;
        var date_buf: [16]u8 = undefined;
        const date_str = getDateStr(&date_buf);
        editor.buffer.insertSlice(offset, date_str) catch return;
        editor.status.set("Date inserted", false);
        return;
    }

    if (std.mem.eql(u8, word, ";time") or std.mem.eql(u8, word, ";t")) {
        const offset = editor.buffer.posToOffset(editor.cursor_row, word_start);
        const end_offset = editor.buffer.posToOffset(editor.cursor_row, col);
        editor.buffer.deleteRange(offset, end_offset) catch return;
        var time_buf: [16]u8 = undefined;
        const time_str = getTimeStr(&time_buf);
        editor.buffer.insertSlice(offset, time_str) catch return;
        editor.status.set("Time inserted", false);
        return;
    }

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Unknown expansion: '{s}' (use :expand.list)", .{word}) catch "Unknown";
    editor.status.set(msg, true);
}

fn showRules(event: *plugin.PluginEvent) void {
    event.editor.status.set("Expansions: ;sig ;br ;hr ;todo ;done ;cb ;note ;warn ;tip ;toc ;fm ;date ;time", false);
}

fn getDateStr(buf: []u8) []const u8 {
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{ yd.year, @as(u9, @intFromEnum(md.month)) + 1, md.day_index + 1 }) catch "date";
}

fn getTimeStr(buf: []u8) []const u8 {
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const ds = es.getDaySeconds();
    return std.fmt.bufPrint(buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{ ds.getHoursIntoDay(), ds.getMinutesIntoHour(), ds.getSecondsIntoMinute() }) catch "time";
}

fn insertDate(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [16]u8 = undefined;
    const date_str = getDateStr(&buf);
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, date_str) catch {
        editor.status.set("Insert failed", true);
        return;
    };
    editor.status.set("Date inserted", false);
}

fn insertTime(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [16]u8 = undefined;
    const time_str = getTimeStr(&buf);
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, time_str) catch {
        editor.status.set("Insert failed", true);
        return;
    };
    editor.status.set("Time inserted", false);
}

test "text_expander plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("text-expander", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 4), cmds.len);
}
