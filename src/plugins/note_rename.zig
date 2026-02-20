const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Note Rename plugin — rename notes with automatic link update across vault.
/// When you rename a file, all [[old-name]] references become [[new-name]].
/// Commands: :rename, :rename.preview
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "note-rename", .version = "0.1.0", .author = "lazy-md contributors", .description = "Rename notes with auto link updates" };
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
        .{ .name = "rename", .description = "Rename current note and update links", .handler = &renameNote },
        .{ .name = "rename.preview", .description = "Preview which files would be updated", .handler = &previewRename },
    };
}

fn getStem(editor: *Editor) ?[]const u8 {
    const fp = editor.file_path orelse return null;
    const name = if (std.mem.lastIndexOfScalar(u8, fp, '/')) |s| fp[s + 1 ..] else fp;
    if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot| return name[0..dot];
    return name;
}

fn previewRename(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const old_stem = getStem(editor) orelse {
        editor.status.set("No file open — save first", true);
        return;
    };

    var linked_buf: [128]u8 = undefined;
    const pattern = std.fmt.bufPrint(&linked_buf, "[[{s}]]", .{old_stem}) catch {
        editor.status.set("Name too long", true);
        return;
    };

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var affected: usize = 0;
    var buf: [256]u8 = undefined;
    const hdr = "Would update: ";
    @memcpy(buf[0..hdr.len], hdr);
    var pos: usize = hdr.len;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [4096]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;

        if (std.mem.indexOf(u8, read_buf[0..n], pattern) != null) {
            affected += 1;
            if (pos + entry.name.len + 2 < buf.len) {
                @memcpy(buf[pos .. pos + entry.name.len], entry.name);
                pos += entry.name.len;
                buf[pos] = ' ';
                pos += 1;
            }
        }
    }

    if (affected == 0) {
        editor.status.set("No files link to this note", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

fn renameNote(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const new_name = event.command_args orelse {
        editor.status.set("Usage: :rename <new-name> (without extension)", true);
        return;
    };

    const old_stem = getStem(editor) orelse {
        editor.status.set("No file open — save first", true);
        return;
    };

    if (std.mem.eql(u8, old_stem, new_name)) {
        editor.status.set("Name unchanged", false);
        return;
    }

    // Build search/replace patterns
    var old_link_buf: [128]u8 = undefined;
    const old_link = std.fmt.bufPrint(&old_link_buf, "[[{s}]]", .{old_stem}) catch {
        editor.status.set("Name too long", true);
        return;
    };
    var new_link_buf: [128]u8 = undefined;
    const new_link = std.fmt.bufPrint(&new_link_buf, "[[{s}]]", .{new_name}) catch {
        editor.status.set("Name too long", true);
        return;
    };

    // Update links in all vault files
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var updated_files: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

        const file = dir.openFile(entry.name, .{}) catch continue;
        var read_buf: [8192]u8 = undefined;
        const n = file.readAll(&read_buf) catch {
            file.close();
            continue;
        };
        file.close();

        const content = read_buf[0..n];
        if (std.mem.indexOf(u8, content, old_link) == null) continue;

        // Replace all occurrences
        var out_buf: [8192]u8 = undefined;
        var out_pos: usize = 0;
        var i: usize = 0;
        while (i < n) {
            if (i + old_link.len <= n and std.mem.eql(u8, content[i .. i + old_link.len], old_link)) {
                if (out_pos + new_link.len <= out_buf.len) {
                    @memcpy(out_buf[out_pos .. out_pos + new_link.len], new_link);
                    out_pos += new_link.len;
                }
                i += old_link.len;
            } else {
                if (out_pos < out_buf.len) {
                    out_buf[out_pos] = content[i];
                    out_pos += 1;
                }
                i += 1;
            }
        }

        // Write back
        const out_file = dir.createFile(entry.name, .{}) catch continue;
        out_file.writeAll(out_buf[0..out_pos]) catch {};
        out_file.close();
        updated_files += 1;
    }

    // Rename the actual file
    const fp = editor.file_path orelse "";
    const dir_prefix = if (std.mem.lastIndexOfScalar(u8, fp, '/')) |s| fp[0 .. s + 1] else "";
    const old_ext = blk: {
        if (std.mem.lastIndexOfScalar(u8, fp, '.')) |dot| break :blk fp[dot..];
        break :blk ".md";
    };

    var new_path_buf: [256]u8 = undefined;
    const new_path = std.fmt.bufPrint(&new_path_buf, "{s}{s}{s}", .{ dir_prefix, new_name, old_ext }) catch {
        editor.status.set("Path too long", true);
        return;
    };

    std.fs.cwd().rename(fp, new_path) catch {
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "Updated {d} files, but rename failed (file may be locked)", .{updated_files}) catch "Partial";
        editor.status.set(msg, true);
        return;
    };

    // Reopen the renamed file
    editor.openFile(new_path) catch {};

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Renamed to {s}, updated {d} files", .{ new_name, updated_files }) catch "Renamed";
    editor.status.set(msg, false);
}

test "note_rename plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("note-rename", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
