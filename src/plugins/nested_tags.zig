const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Nested Tags plugin — support for hierarchical #parent/child tags.
/// Scans vault for nested tag patterns and provides tag tree.
/// Commands: :ntag, :ntag.add, :ntag.tree
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "nested-tags", .version = "0.1.0", .author = "lazy-md contributors", .description = "Hierarchical nested tag support" };
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
        .{ .name = "ntag", .description = "Show nested tags in document", .handler = &showTags },
        .{ .name = "ntag.add", .description = "Add nested tag at cursor", .handler = &addTag },
        .{ .name = "ntag.tree", .description = "Show tag hierarchy", .handler = &showTree },
    };
}

fn isTagChar(ch: u8) bool {
    return std.ascii.isAlphanumeric(ch) or ch == '_' or ch == '-' or ch == '/';
}

fn showTags(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [256]u8 = undefined;
    const hdr = "Tags: ";
    @memcpy(buf[0..hdr.len], hdr);
    var pos: usize = hdr.len;
    var count: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        var i: usize = 0;
        while (i < line.len) : (i += 1) {
            if (line[i] == '#' and (i == 0 or line[i - 1] == ' ' or line[i - 1] == '\n')) {
                const tag_start = i;
                i += 1;
                if (i >= line.len or !std.ascii.isAlphabetic(line[i])) continue;
                while (i < line.len and isTagChar(line[i])) : (i += 1) {}
                const tag = line[tag_start..i];
                if (tag.len > 1) {
                    count += 1;
                    // Check if nested (contains /)
                    const is_nested = std.mem.indexOf(u8, tag, "/") != null;
                    if (pos + tag.len + 5 < buf.len) {
                        @memcpy(buf[pos .. pos + tag.len], tag);
                        pos += tag.len;
                        if (is_nested) {
                            buf[pos] = '*';
                            pos += 1;
                        }
                        buf[pos] = ' ';
                        pos += 1;
                    }
                    if (count >= 10) break;
                }
            }
        }
        if (count >= 10) break;
    }

    if (count == 0) {
        editor.status.set("No tags found (use #parent/child for nesting)", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

fn addTag(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const tag_input = event.command_args orelse {
        editor.status.set("Usage: :ntag.add parent/child", true);
        return;
    };

    var buf: [64]u8 = undefined;
    const tag = std.fmt.bufPrint(&buf, " #{s}", .{tag_input}) catch {
        editor.status.set("Tag too long", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, tag) catch {
        editor.status.set("Insert failed", true);
        return;
    };

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Added tag: #{s}", .{tag_input}) catch "Added";
    editor.status.set(msg, false);
}

fn showTree(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Collect unique top-level tag parents from vault
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        // Just scan current document
        showTags(event);
        return;
    };
    defer dir.close();

    var buf: [256]u8 = undefined;
    const hdr = "Tag tree: ";
    @memcpy(buf[0..hdr.len], hdr);
    var pos: usize = hdr.len;
    var count: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [4096]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;
        const content = read_buf[0..n];

        var i: usize = 0;
        while (i < n) : (i += 1) {
            if (content[i] == '#' and (i == 0 or content[i - 1] == ' ' or content[i - 1] == '\n')) {
                i += 1;
                if (i >= n or !std.ascii.isAlphabetic(content[i])) continue;
                const start = i - 1;
                while (i < n and isTagChar(content[i])) : (i += 1) {}
                const tag = content[start..i];
                // Only show nested tags in tree
                if (std.mem.indexOf(u8, tag, "/") != null) {
                    count += 1;
                    if (pos + tag.len + 2 < buf.len) {
                        @memcpy(buf[pos .. pos + tag.len], tag);
                        pos += tag.len;
                        buf[pos] = ' ';
                        pos += 1;
                    }
                    if (count >= 8) break;
                }
            }
        }
        if (count >= 8) break;
    }

    if (count == 0) {
        editor.status.set("No nested tags (#parent/child) found in vault", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

test "nested_tags plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("nested-tags", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "isTagChar" {
    try std.testing.expect(isTagChar('a'));
    try std.testing.expect(isTagChar('/'));
    try std.testing.expect(isTagChar('_'));
    try std.testing.expect(!isTagChar(' '));
}
