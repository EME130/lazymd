const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Recent Files plugin — tracks recently opened files via .lazy-md/recent.
/// Commands: :recent, :recent.clear
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "recent-files", .version = "0.1.0", .author = "lazy-md contributors", .description = "Recently opened files list" };
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
        .{ .name = "recent", .description = "Show recently opened files", .handler = &showRecent },
        .{ .name = "recent.clear", .description = "Clear recent files list", .handler = &clearRecent },
    };
}

const recent_path = ".lazy-md/recent";

fn showRecent(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Read recent file list
    const file = std.fs.cwd().openFile(recent_path, .{}) catch {
        // No recent file exists, scan directory for .md files as fallback
        showVaultFiles(editor);
        return;
    };
    defer file.close();

    var buf: [512]u8 = undefined;
    const n = file.readAll(&buf) catch {
        editor.status.set("Failed to read recent files", true);
        return;
    };

    if (n == 0) {
        showVaultFiles(editor);
        return;
    }

    // Show first few entries
    var msg_buf: [256]u8 = undefined;
    const prefix = "Recent: ";
    @memcpy(msg_buf[0..prefix.len], prefix);
    var pos: usize = prefix.len;

    var lines = std.mem.splitScalar(u8, buf[0..n], '\n');
    var count: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        count += 1;
        if (count > 5) break;
        const max = @min(line.len, msg_buf.len - pos - 3);
        if (max == 0) break;
        @memcpy(msg_buf[pos .. pos + max], line[0..max]);
        pos += max;
        msg_buf[pos] = ' ';
        pos += 1;
    }

    if (count == 0) {
        showVaultFiles(editor);
    } else {
        editor.status.set(msg_buf[0..pos], false);
    }
}

fn showVaultFiles(editor: *Editor) void {
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("No recent files", false);
        return;
    };
    defer dir.close();

    var msg_buf: [256]u8 = undefined;
    const prefix = "Files: ";
    @memcpy(msg_buf[0..prefix.len], prefix);
    var pos: usize = prefix.len;
    var count: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;
        count += 1;
        if (count > 8) break;
        if (pos + entry.name.len + 2 < msg_buf.len) {
            @memcpy(msg_buf[pos .. pos + entry.name.len], entry.name);
            pos += entry.name.len;
            msg_buf[pos] = ' ';
            pos += 1;
        }
    }

    if (count == 0) {
        editor.status.set("No .md or .rndm files in vault", false);
    } else {
        editor.status.set(msg_buf[0..pos], false);
    }
}

fn clearRecent(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    std.fs.cwd().deleteFile(recent_path) catch {
        editor.status.set("No recent file to clear", false);
        return;
    };
    editor.status.set("Recent files cleared", false);
}

test "recent_files plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("recent-files", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
