const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Tag Manager plugin — manage #tags in current document and vault.
/// Scans for #tag patterns and shows tag stats.
/// Commands: :tags, :tags.search, :tags.add
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "tag-manager", .version = "0.1.0", .author = "lazy-md contributors", .description = "Manage and search #tags" };
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
        .{ .name = "tags", .description = "List all tags in document", .handler = &listTags },
        .{ .name = "tags.search", .description = "Search notes by tag", .handler = &searchTag },
        .{ .name = "tags.add", .description = "Add tag to document", .handler = &addTag },
    };
}

fn listTags(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    const prefix = "Tags: ";
    @memcpy(buf[0..prefix.len], prefix);
    pos = prefix.len;

    var tag_count: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        var i: usize = 0;
        while (i < line.len) : (i += 1) {
            if (line[i] == '#' and (i == 0 or line[i - 1] == ' ')) {
                // Check it's a tag, not a heading
                if (i == 0 and (i + 1 >= line.len or line[i + 1] == ' ')) continue;
                const tag_start = i;
                i += 1;
                while (i < line.len and line[i] != ' ' and line[i] != '\t' and line[i] != ',') : (i += 1) {}
                const tag = line[tag_start..i];
                if (tag.len > 1) {
                    tag_count += 1;
                    if (pos + tag.len + 1 < buf.len) {
                        @memcpy(buf[pos .. pos + tag.len], tag);
                        pos += tag.len;
                        buf[pos] = ' ';
                        pos += 1;
                    }
                }
            }
        }
    }

    if (tag_count == 0) {
        editor.status.set("No #tags found in document", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

fn searchTag(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const tag = event.command_args orelse {
        editor.status.set("Usage: :tags.search <tag>", true);
        return;
    };

    // Search for #tag in vault files
    var match_count: usize = 0;
    var buf: [256]u8 = undefined;
    var pos: usize = 0;

    // Build search pattern
    var search_buf: [64]u8 = undefined;
    const pattern = blk: {
        if (tag[0] == '#') break :blk tag;
        const p = std.fmt.bufPrint(&search_buf, "#{s}", .{tag}) catch {
            editor.status.set("Tag too long", true);
            return;
        };
        break :blk p;
    };

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan directory", true);
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [4096]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;

        if (std.mem.indexOf(u8, read_buf[0..n], pattern) != null) {
            match_count += 1;
            if (pos + entry.name.len + 1 < buf.len) {
                @memcpy(buf[pos .. pos + entry.name.len], entry.name);
                pos += entry.name.len;
                buf[pos] = ' ';
                pos += 1;
            }
        }
    }

    if (match_count == 0) {
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "No files with {s}", .{pattern}) catch "Not found";
        editor.status.set(msg, false);
    } else {
        var msg_buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "{s} ({d} files): {s}", .{ pattern, match_count, buf[0..pos] }) catch "Found";
        editor.status.set(msg, false);
    }
}

fn addTag(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const tag_name = event.command_args orelse {
        editor.status.set("Usage: :tags.add <tagname>", true);
        return;
    };

    // Insert #tag at cursor
    var tag_buf: [64]u8 = undefined;
    const tag = blk: {
        if (tag_name[0] == '#') break :blk tag_name;
        const t = std.fmt.bufPrint(&tag_buf, "#{s}", .{tag_name}) catch {
            editor.status.set("Tag too long", true);
            return;
        };
        break :blk t;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, tag) catch {
        editor.status.set("Failed to insert tag", true);
        return;
    };
    editor.cursor_col += tag.len;
    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Added {s}", .{tag}) catch "Tag added";
    editor.status.set(msg, false);
}

test "tag_manager plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("tag-manager", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
