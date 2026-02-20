const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Backlinks plugin — find notes that link to the current file via [[wiki-links]].
/// Scans .md and .rndm files in the current directory for [[current-filename]].
/// Commands: :backlinks
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "backlinks", .version = "0.1.0", .author = "lazy-md contributors", .description = "Find files linking to current note" };
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
        .{ .name = "backlinks", .description = "Show backlinks to current file", .handler = &showBacklinks },
    };
}

fn showBacklinks(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const file_path = editor.file_path orelse {
        editor.status.set("No file open — save first to scan backlinks", true);
        return;
    };

    // Extract base filename without extension for wiki-link matching
    const basename = std.fs.path.basename(file_path);
    const stem = blk: {
        if (std.mem.lastIndexOfScalar(u8, basename, '.')) |dot| {
            break :blk basename[0..dot];
        }
        break :blk basename;
    };

    // Build wiki-link patterns to search for: [[stem]] and [[basename]]
    var pattern_buf: [128]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buf, "[[{s}]]", .{stem}) catch {
        editor.status.set("Filename too long", true);
        return;
    };

    var match_count: usize = 0;
    var result_buf: [256]u8 = undefined;
    var result_pos: usize = 0;

    const prefix = std.fmt.bufPrint(result_buf[0..], "Backlinks: ", .{}) catch "";
    result_pos = prefix.len;

    // Scan directory
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan directory", true);
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        const is_md = std.mem.endsWith(u8, entry.name, ".md") or
            std.mem.endsWith(u8, entry.name, ".rndm");
        if (!is_md) continue;
        // Skip self
        if (std.mem.eql(u8, entry.name, basename)) continue;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [8192]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;
        const content = read_buf[0..n];

        if (containsSubstring(content, pattern)) {
            match_count += 1;
            // Append filename to result
            if (result_pos + entry.name.len + 2 < result_buf.len) {
                @memcpy(result_buf[result_pos .. result_pos + entry.name.len], entry.name);
                result_pos += entry.name.len;
                result_buf[result_pos] = ' ';
                result_pos += 1;
            }
        }
    }

    if (match_count == 0) {
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "No backlinks found for [[{s}]]", .{stem}) catch "No backlinks";
        editor.status.set(msg, false);
    } else {
        editor.status.set(result_buf[0..result_pos], false);
    }
}

fn containsSubstring(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    for (0..haystack.len - needle.len + 1) |i| {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}

test "backlinks plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("backlinks", p.pluginInfo().name);
}

test "containsSubstring" {
    try std.testing.expect(containsSubstring("see [[foo]] here", "[[foo]]"));
    try std.testing.expect(!containsSubstring("see [foo] here", "[[foo]]"));
}
