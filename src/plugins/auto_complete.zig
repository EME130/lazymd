const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Auto-Complete plugin — completion for wiki links and tags.
/// Scans vault for note names and suggests matches.
/// Commands: :autocomplete, :autocomplete.link, :autocomplete.tag
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "auto-complete", .version = "0.1.0", .author = "lazy-md contributors", .description = "Auto-complete for links and tags" };
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
        .{ .name = "autocomplete", .description = "Complete wiki link at cursor", .handler = &completeLink },
        .{ .name = "autocomplete.tag", .description = "Show tag completions", .handler = &completeTag },
    };
}

fn completeLink(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Get partial text before cursor
    const line = editor.buffer.getLine(editor.cursor_row);
    const col = @min(editor.cursor_col, line.len);

    // Find [[ before cursor
    var link_start: ?usize = null;
    if (col >= 2) {
        var i = col;
        while (i >= 2) {
            i -= 1;
            if (i > 0 and line[i - 1] == '[' and line[i] == '[') {
                link_start = i + 1;
                break;
            }
        }
    }

    const prefix = if (link_start) |s| line[s..col] else (event.command_args orelse "");
    if (prefix.len == 0) {
        // Show all available notes
        showNoteList(editor);
        return;
    }

    // Scan vault for matching notes
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var buf: [256]u8 = undefined;
    const hdr = "Matches: ";
    @memcpy(buf[0..hdr.len], hdr);
    var pos: usize = hdr.len;
    var count: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

        const stem = blk: {
            if (std.mem.lastIndexOfScalar(u8, entry.name, '.')) |dot| break :blk entry.name[0..dot];
            break :blk entry.name;
        };

        // Check if stem contains prefix (case-insensitive)
        if (containsIgnoreCase(stem, prefix)) {
            count += 1;
            if (pos + stem.len + 5 < buf.len) {
                @memcpy(buf[pos .. pos + 2], "[[");
                pos += 2;
                @memcpy(buf[pos .. pos + stem.len], stem);
                pos += stem.len;
                @memcpy(buf[pos .. pos + 2], "]]");
                pos += 2;
                buf[pos] = ' ';
                pos += 1;
            }
            if (count >= 5) break;
        }
    }

    if (count == 0) {
        editor.status.set("No matching notes found", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

fn completeTag(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const prefix = event.command_args orelse "";

    var buf: [256]u8 = undefined;
    const hdr = "Tags: ";
    @memcpy(buf[0..hdr.len], hdr);
    var pos: usize = hdr.len;
    var count: usize = 0;

    // Scan current document for #tags
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        var i: usize = 0;
        while (i < line.len) : (i += 1) {
            if (line[i] == '#' and (i == 0 or line[i - 1] == ' ')) {
                const tag_start = i;
                i += 1;
                while (i < line.len and (std.ascii.isAlphanumeric(line[i]) or line[i] == '_' or line[i] == '-')) : (i += 1) {}
                const tag = line[tag_start..i];
                if (tag.len > 1 and (prefix.len == 0 or containsIgnoreCase(tag, prefix))) {
                    count += 1;
                    if (pos + tag.len + 2 < buf.len) {
                        @memcpy(buf[pos .. pos + tag.len], tag);
                        pos += tag.len;
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
        editor.status.set("No tags found", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

fn showNoteList(editor: *Editor) void {
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var buf: [256]u8 = undefined;
    const hdr = "Notes: ";
    @memcpy(buf[0..hdr.len], hdr);
    var pos: usize = hdr.len;
    var count: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;
        count += 1;
        if (pos + entry.name.len + 2 < buf.len) {
            @memcpy(buf[pos .. pos + entry.name.len], entry.name);
            pos += entry.name.len;
            buf[pos] = ' ';
            pos += 1;
        }
        if (count >= 8) break;
    }

    if (count == 0) {
        editor.status.set("No notes in vault", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}

test "auto_complete plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("auto-complete", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}

test "containsIgnoreCase" {
    try std.testing.expect(containsIgnoreCase("Hello World", "world"));
    try std.testing.expect(containsIgnoreCase("README", "read"));
    try std.testing.expect(!containsIgnoreCase("abc", "xyz"));
}
