const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Graph View plugin — show vault note connections via [[wiki-links]].
/// Scans all .md/.rndm files for [[links]] and shows connection stats.
/// Commands: :graph, :graph.local, :graph.orphans
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "graph-view", .version = "0.1.0", .author = "lazy-md contributors", .description = "ASCII graph of note connections" };
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
        .{ .name = "graph", .description = "Show vault connection stats", .handler = &showGraph },
        .{ .name = "graph.local", .description = "Show links in current file", .handler = &showLocal },
        .{ .name = "graph.orphans", .description = "Find orphan notes", .handler = &findOrphans },
    };
}

fn showGraph(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var total_files: usize = 0;
    var total_links: usize = 0;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;
        total_files += 1;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [4096]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;
        total_links += countWikiLinks(read_buf[0..n]);
    }

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Graph: {d} notes, {d} [[links]]", .{ total_files, total_links }) catch "Graph stats";
    editor.status.set(msg, false);
}

fn showLocal(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    var link_count: usize = 0;

    const prefix = "Links: ";
    @memcpy(buf[0..prefix.len], prefix);
    pos = prefix.len;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        var i: usize = 0;
        while (i + 3 < line.len) : (i += 1) {
            if (line[i] == '[' and line[i + 1] == '[') {
                const end = std.mem.indexOf(u8, line[i + 2 ..], "]]") orelse continue;
                const target = line[i + 2 .. i + 2 + end];
                link_count += 1;
                if (pos + target.len + 3 < buf.len) {
                    @memcpy(buf[pos .. pos + 2], "[[");
                    pos += 2;
                    @memcpy(buf[pos .. pos + target.len], target);
                    pos += target.len;
                    @memcpy(buf[pos .. pos + 2], "]]");
                    pos += 2;
                    buf[pos] = ' ';
                    pos += 1;
                }
                i += 2 + end + 1;
            }
        }
    }

    if (link_count == 0) {
        editor.status.set("No [[wiki-links]] in current file", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

fn findOrphans(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Collect all filenames and all [[link]] targets, find files with no inlinks
    var total: usize = 0;
    var orphan_count: usize = 0;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    // Simple approach: count files that are never referenced by [[]] in other files
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;
        total += 1;

        // Check if any other file links to this one
        const stem = blk: {
            if (std.mem.lastIndexOfScalar(u8, entry.name, '.')) |dot| break :blk entry.name[0..dot];
            break :blk entry.name;
        };
        var pattern_buf: [128]u8 = undefined;
        const pattern = std.fmt.bufPrint(&pattern_buf, "[[{s}]]", .{stem}) catch continue;

        var found = false;
        var inner_iter = dir.iterate();
        while (inner_iter.next() catch null) |other| {
            if (other.kind != .file) continue;
            if (std.mem.eql(u8, other.name, entry.name)) continue;
            if (!std.mem.endsWith(u8, other.name, ".md") and !std.mem.endsWith(u8, other.name, ".rndm")) continue;

            const file = dir.openFile(other.name, .{}) catch continue;
            defer file.close();
            var read_buf: [4096]u8 = undefined;
            const n = file.readAll(&read_buf) catch continue;
            if (std.mem.indexOf(u8, read_buf[0..n], pattern) != null) {
                found = true;
                break;
            }
        }
        if (!found) orphan_count += 1;
    }

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Orphan notes: {d}/{d} have no incoming links", .{ orphan_count, total }) catch "Orphans";
    editor.status.set(msg, false);
}

fn countWikiLinks(content: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i + 3 < content.len) : (i += 1) {
        if (content[i] == '[' and content[i + 1] == '[') {
            if (std.mem.indexOf(u8, content[i + 2 ..], "]]") != null) count += 1;
        }
    }
    return count;
}

test "graph_view plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("graph-view", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "countWikiLinks" {
    try std.testing.expectEqual(@as(usize, 2), countWikiLinks("see [[foo]] and [[bar]]"));
    try std.testing.expectEqual(@as(usize, 0), countWikiLinks("no links"));
}
