const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Paste Image plugin — insert image references and manage attachments.
/// Creates attachments/ directory for images, inserts markdown references.
/// Commands: :paste.img, :paste.link
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "paste-image", .version = "0.1.0", .author = "lazy-md contributors", .description = "Paste images from clipboard" };
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
        .{ .name = "paste.img", .description = "Insert image reference", .handler = &pasteImg },
        .{ .name = "paste.link", .description = "Insert image link", .handler = &pasteLink },
        .{ .name = "paste.list", .description = "List attachments", .handler = &listAttachments },
    };
}

fn pasteImg(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const name = event.command_args orelse "image";

    // Ensure attachments directory
    std.fs.cwd().makeDir("attachments") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {},
    };

    // Generate image reference with timestamp
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();

    var buf: [128]u8 = undefined;
    const img_ref = std.fmt.bufPrint(&buf, "\n![{s}](attachments/{s}-{d:0>4}{d:0>2}{d:0>2}.png)\n", .{
        name,
        name,
        yd.year,
        @as(u9, @intFromEnum(md.month)) + 1,
        md.day_index + 1,
    }) catch {
        editor.status.set("Name too long", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, img_ref) catch {
        editor.status.set("Failed to insert image reference", true);
        return;
    };
    editor.status.set("Image reference inserted (save image to attachments/)", false);
}

fn pasteLink(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const url = event.command_args orelse {
        editor.status.set("Usage: :paste.link <url> [alt text]", true);
        return;
    };

    var buf: [256]u8 = undefined;
    const img_md = std.fmt.bufPrint(&buf, "\n![image]({s})\n", .{url}) catch {
        editor.status.set("URL too long", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, img_md) catch {
        editor.status.set("Failed to insert image link", true);
        return;
    };
    editor.status.set("Image link inserted", false);
}

fn listAttachments(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var dir = std.fs.cwd().openDir("attachments", .{ .iterate = true }) catch {
        editor.status.set("No attachments/ directory", false);
        return;
    };
    defer dir.close();

    var count: usize = 0;
    var total_size: u64 = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file) {
            count += 1;
            const stat = dir.statFile(entry.name) catch continue;
            total_size += stat.size;
        }
    }

    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Attachments: {d} files ({d}KB)", .{ count, total_size / 1024 }) catch "Attachments";
    editor.status.set(msg, false);
}

test "paste_image plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("paste-image", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
