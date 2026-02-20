const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Bookmarks plugin — vim-style marks for jumping between positions.
/// Supports up to 26 named marks (a-z) with line positions.
/// Commands: :bm.set, :bm.go, :bm.list, :bm.clear
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "bookmarks", .version = "0.1.0", .author = "lazy-md contributors", .description = "Bookmark positions in files" };
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
        .{ .name = "bm.set", .description = "Set bookmark (e.g. :bm.set a)", .handler = &setBookmark },
        .{ .name = "bm.go", .description = "Go to bookmark (e.g. :bm.go a)", .handler = &goBookmark },
        .{ .name = "bm.list", .description = "List all bookmarks", .handler = &listBookmarks },
        .{ .name = "bm.clear", .description = "Clear all bookmarks", .handler = &clearBookmarks },
    };
}

// Global bookmark storage: 26 marks (a-z), each stores a line number
var marks: [26]?usize = [_]?usize{null} ** 26;

fn setBookmark(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const args = event.command_args orelse {
        // Default: set next available mark
        for (&marks, 0..) |*m, i| {
            if (m.* == null) {
                m.* = editor.cursor_row;
                var buf: [64]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "Bookmark '{c}' set at line {d}", .{ @as(u8, @intCast(i)) + 'a', editor.cursor_row + 1 }) catch "Set";
                editor.status.set(msg, false);
                return;
            }
        }
        editor.status.set("All 26 bookmarks in use — clear some first", true);
        return;
    };

    if (args.len >= 1 and args[0] >= 'a' and args[0] <= 'z') {
        const idx = args[0] - 'a';
        marks[idx] = editor.cursor_row;
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Bookmark '{c}' set at line {d}", .{ args[0], editor.cursor_row + 1 }) catch "Set";
        editor.status.set(msg, false);
    } else {
        editor.status.set("Usage: :bm.set [a-z]", true);
    }
}

fn goBookmark(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const args = event.command_args orelse {
        editor.status.set("Usage: :bm.go <a-z>", true);
        return;
    };

    if (args.len >= 1 and args[0] >= 'a' and args[0] <= 'z') {
        const idx = args[0] - 'a';
        if (marks[idx]) |row| {
            if (row < editor.buffer.lineCount()) {
                editor.cursor_row = row;
                editor.cursor_col = 0;
                editor.desired_col = 0;
                var buf: [64]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "Jumped to bookmark '{c}' (line {d})", .{ args[0], row + 1 }) catch "Jumped";
                editor.status.set(msg, false);
            } else {
                editor.status.set("Bookmark line no longer exists", true);
            }
        } else {
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Bookmark '{c}' not set", .{args[0]}) catch "Not set";
            editor.status.set(msg, true);
        }
    } else {
        editor.status.set("Usage: :bm.go <a-z>", true);
    }
}

fn listBookmarks(event: *plugin.PluginEvent) void {
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    var count: usize = 0;

    const prefix = "Bookmarks: ";
    @memcpy(buf[0..prefix.len], prefix);
    pos = prefix.len;

    for (marks, 0..) |m, i| {
        if (m) |row| {
            const written = std.fmt.bufPrint(buf[pos..], "'{c}'=L{d} ", .{ @as(u8, @intCast(i)) + 'a', row + 1 }) catch break;
            pos += written.len;
            count += 1;
        }
    }

    if (count == 0) {
        event.editor.status.set("No bookmarks set", false);
    } else {
        event.editor.status.set(buf[0..pos], false);
    }
}

fn clearBookmarks(event: *plugin.PluginEvent) void {
    for (&marks) |*m| m.* = null;
    event.editor.status.set("All bookmarks cleared", false);
}

test "bookmarks plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("bookmarks", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 4), cmds.len);
}
