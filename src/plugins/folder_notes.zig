const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Folder Notes plugin — auto-create index notes for folders.
/// Scans directory and generates markdown index with links.
/// Commands: :folder.index, :folder.create
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "folder-notes", .version = "0.1.0", .author = "lazy-md contributors", .description = "Auto-generate folder index notes" };
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
        .{ .name = "folder.index", .description = "Generate index for current directory", .handler = &genIndex },
        .{ .name = "folder.create", .description = "Create new folder with index note", .handler = &createFolder },
    };
}

fn genIndex(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const target = event.command_args orelse ".";

    var dir = std.fs.cwd().openDir(target, .{ .iterate = true }) catch {
        editor.status.set("Cannot open directory", true);
        return;
    };
    defer dir.close();

    var buf: [1024]u8 = undefined;
    var pos: usize = 0;

    // Header
    const header = std.fmt.bufPrint(buf[pos..], "# Index: {s}\n\n", .{target}) catch {
        editor.status.set("Format error", true);
        return;
    };
    pos += header.len;

    var file_count: usize = 0;
    var dir_count: usize = 0;

    // List directories first
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.name[0] == '.') continue;
        if (entry.kind == .directory) {
            dir_count += 1;
            const line = std.fmt.bufPrint(buf[pos..], "- [[{s}/]] (folder)\n", .{entry.name}) catch break;
            pos += line.len;
            if (pos >= buf.len - 80) break;
        }
    }

    // List files
    var iter2 = dir.iterate();
    while (iter2.next() catch null) |entry| {
        if (entry.name[0] == '.') continue;
        if (entry.kind == .file and (std.mem.endsWith(u8, entry.name, ".md") or std.mem.endsWith(u8, entry.name, ".rndm"))) {
            file_count += 1;
            // Get stem
            const stem = blk: {
                if (std.mem.lastIndexOfScalar(u8, entry.name, '.')) |dot| break :blk entry.name[0..dot];
                break :blk entry.name;
            };
            const line = std.fmt.bufPrint(buf[pos..], "- [[{s}]]\n", .{stem}) catch break;
            pos += line.len;
            if (pos >= buf.len - 80) break;
        }
    }

    if (file_count == 0 and dir_count == 0) {
        editor.status.set("No notes or folders found", false);
        return;
    }

    // Add summary
    const summary = std.fmt.bufPrint(buf[pos..], "\n---\n*{d} notes, {d} folders*\n", .{ file_count, dir_count }) catch "";
    pos += summary.len;

    // Insert at cursor
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, buf[0..pos]) catch {
        editor.status.set("Failed to insert index", true);
        return;
    };

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Index: {d} notes, {d} folders", .{ file_count, dir_count }) catch "Index generated";
    editor.status.set(msg, false);
}

fn createFolder(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const name = event.command_args orelse {
        editor.status.set("Usage: :folder.create <name>", true);
        return;
    };

    // Create directory
    std.fs.cwd().makeDir(name) catch |err| switch (err) {
        error.PathAlreadyExists => {
            editor.status.set("Folder already exists", true);
            return;
        },
        else => {
            editor.status.set("Cannot create folder", true);
            return;
        },
    };

    // Create index note inside
    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}.md", .{ name, name }) catch {
        editor.status.set("Path too long", true);
        return;
    };

    const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
        editor.status.set("Failed to create index note", true);
        return;
    };
    var tpl_buf: [256]u8 = undefined;
    const tpl = std.fmt.bufPrint(&tpl_buf, "# {s}\n\nFolder index for **{s}/**.\n\n## Notes\n\n", .{ name, name }) catch "";
    file.writeAll(tpl) catch {};
    file.close();
    editor.openFile(path) catch {};

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Created folder: {s}/", .{name}) catch "Created";
    editor.status.set(msg, false);
}

test "folder_notes plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("folder-notes", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
