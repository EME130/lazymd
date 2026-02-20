const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Slack plugin — export note content in Slack-friendly format.
/// Converts markdown to Slack mrkdwn format, copies to clipboard-ready.
/// Commands: :slack, :slack.format, :slack.share
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "slack", .version = "0.1.0", .author = "lazy-md contributors", .description = "Slack messaging integration" };
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
        .{ .name = "slack", .description = "Show Slack format preview", .handler = &showFormat },
        .{ .name = "slack.format", .description = "Convert current line to Slack mrkdwn", .handler = &formatLine },
        .{ .name = "slack.export", .description = "Export note as Slack message file", .handler = &exportSlack },
    };
}

fn showFormat(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Count formatting elements that differ between Markdown and Slack
    var headings: usize = 0;
    var bold: usize = 0;
    var links: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (line.len > 0 and line[0] == '#') headings += 1;
        if (std.mem.indexOf(u8, line, "**") != null) bold += 1;
        if (std.mem.indexOf(u8, line, "](") != null) links += 1;
    }

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Slack preview: {d} headings->bold, {d} **bold**->*bold*, {d} links->mrkdwn", .{ headings, bold, links }) catch "Format";
    editor.status.set(msg, false);
}

fn formatLine(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const line = editor.buffer.getLine(editor.cursor_row);

    // Simple conversion: # Heading -> *Heading*
    if (line.len > 2 and line[0] == '#') {
        var i: usize = 0;
        while (i < line.len and line[i] == '#') : (i += 1) {}
        while (i < line.len and line[i] == ' ') : (i += 1) {}
        var end = line.len;
        while (end > i and (line[end - 1] == '\n' or line[end - 1] == '\r')) : (end -= 1) {}
        const text = line[i..end];

        var buf: [256]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "*{s}*", .{text}) catch {
            editor.status.set("Line too long", true);
            return;
        };

        const offset = editor.buffer.posToOffset(editor.cursor_row, 0);
        const line_end = editor.buffer.posToOffset(editor.cursor_row, end);
        editor.buffer.deleteRange(offset, line_end) catch return;
        editor.buffer.insertSlice(offset, formatted) catch return;
        editor.status.set("Converted heading to Slack bold", false);
        return;
    }

    editor.status.set("Line already Slack-compatible", false);
}

fn exportSlack(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    std.fs.cwd().makeDir("exports") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {},
    };

    const stem = blk: {
        if (editor.file_path) |fp| {
            const name = if (std.mem.lastIndexOfScalar(u8, fp, '/')) |s| fp[s + 1 ..] else fp;
            if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot| break :blk name[0..dot];
            break :blk name;
        }
        break :blk "export";
    };

    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "exports/{s}-slack.txt", .{stem}) catch {
        editor.status.set("Path error", true);
        return;
    };

    const file = std.fs.cwd().createFile(path, .{}) catch {
        editor.status.set("Failed to create export", true);
        return;
    };
    defer file.close();

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        // Convert headings
        if (line.len > 2 and line[0] == '#') {
            var i: usize = 0;
            while (i < line.len and line[i] == '#') : (i += 1) {}
            while (i < line.len and line[i] == ' ') : (i += 1) {}
            file.writeAll("*") catch {};
            var end = line.len;
            while (end > i and (line[end - 1] == '\n' or line[end - 1] == '\r')) : (end -= 1) {}
            file.writeAll(line[i..end]) catch {};
            file.writeAll("*\n") catch {};
        } else {
            file.writeAll(line) catch {};
            if (line.len == 0 or line[line.len - 1] != '\n') {
                file.writeAll("\n") catch {};
            }
        }
    }

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Exported for Slack: {s}", .{path}) catch "Exported";
    editor.status.set(msg, false);
}

test "slack plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("slack", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
