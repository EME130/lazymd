const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Web Clipper plugin — create markdown notes from URLs and text.
/// Creates clippings directory with captured content.
/// Commands: :clip, :clip.url, :clip.paste
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "web-clipper", .version = "0.1.0", .author = "lazy-md contributors", .description = "Clip web pages to markdown" };
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
        .{ .name = "clip", .description = "Create clip note from URL", .handler = &clipUrl },
        .{ .name = "clip.insert", .description = "Insert clip template at cursor", .handler = &clipInsert },
        .{ .name = "clip.list", .description = "List clippings", .handler = &clipList },
    };
}

fn clipUrl(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const url = event.command_args orelse {
        editor.status.set("Usage: :clip <url>", true);
        return;
    };

    std.fs.cwd().makeDir("clippings") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create clippings/ directory", true);
            return;
        },
    };

    // Generate filename from timestamp
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();

    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "clippings/clip-{d:0>4}{d:0>2}{d:0>2}-{d:0>2}{d:0>2}.md", .{
        yd.year,
        @as(u9, @intFromEnum(md.month)) + 1,
        md.day_index + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
    }) catch {
        editor.status.set("Path error", true);
        return;
    };

    const file = std.fs.cwd().createFile(path, .{}) catch {
        editor.status.set("Failed to create clip file", true);
        return;
    };

    var tpl_buf: [512]u8 = undefined;
    const tpl = std.fmt.bufPrint(&tpl_buf,
        \\---
        \\source: "{s}"
        \\clipped: {d:0>4}-{d:0>2}-{d:0>2}
        \\tags: [clipping]
        \\---
        \\
        \\# Web Clipping
        \\
        \\Source: [{s}]({s})
        \\
        \\## Notes
        \\
        \\
        \\
        \\## Highlights
        \\
        \\>
        \\
    , .{
        url,
        yd.year,
        @as(u9, @intFromEnum(md.month)) + 1,
        md.day_index + 1,
        url,
        url,
    }) catch {
        editor.status.set("Template error", true);
        file.close();
        return;
    };
    file.writeAll(tpl) catch {};
    file.close();
    editor.openFile(path) catch {};

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Clipped: {s}", .{path}) catch "Clipped";
    editor.status.set(msg, false);
}

fn clipInsert(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const url = event.command_args orelse "https://example.com";

    var buf: [256]u8 = undefined;
    const template = std.fmt.bufPrint(&buf,
        \\> **Clipping**
        \\> Source: [{s}]({s})
        \\>
        \\> (paste content here)
        \\
        \\
    , .{ url, url }) catch {
        editor.status.set("Template error", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, template) catch {
        editor.status.set("Insert failed", true);
        return;
    };
    editor.status.set("Clip template inserted", false);
}

fn clipList(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var dir = std.fs.cwd().openDir("clippings", .{ .iterate = true }) catch {
        editor.status.set("No clippings/ directory. Use :clip <url> to start", false);
        return;
    };
    defer dir.close();

    var count: usize = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".md")) {
            count += 1;
        }
    }

    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Clippings: {d} notes in clippings/", .{count}) catch "Clippings";
    editor.status.set(msg, false);
}

test "web_clipper plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("web-clipper", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
