const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Search plugin — find text in current file and across vault.
/// Commands: :search, :search.next, :search.vault
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "search", .version = "0.1.0", .author = "lazy-md contributors", .description = "Full-text search in file and vault" };
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
        .{ .name = "search", .description = "Search in current file", .handler = &searchFile },
        .{ .name = "search.replace", .description = "Search and replace", .handler = &searchReplace },
        .{ .name = "search.vault", .description = "Search across all files", .handler = &searchVault },
    };
}

fn searchFile(event: *plugin.PluginEvent) void {
    const term = event.command_args orelse {
        event.editor.status.set("Usage: :search <term>", true);
        return;
    };
    if (term.len == 0) {
        event.editor.status.set("Usage: :search <term>", true);
        return;
    }

    const editor = event.editor;
    const start_row = editor.cursor_row;
    const line_count = editor.buffer.lineCount();
    var matches: usize = 0;
    var first_match_row: ?usize = null;
    var first_match_col: ?usize = null;

    // Search from current line forward, wrapping around
    for (0..line_count) |offset| {
        const row = (start_row + offset) % line_count;
        const line = editor.buffer.getLine(row);
        if (indexOf(line, term)) |col| {
            matches += 1;
            // Skip if we're on the same position as cursor (search for next)
            if (first_match_row == null) {
                if (row == start_row and col <= editor.cursor_col and offset == 0) {
                    // Try further in the same line
                    if (col + term.len < line.len) {
                        if (indexOf(line[col + 1 ..], term)) |col2| {
                            first_match_row = row;
                            first_match_col = col + 1 + col2;
                            continue;
                        }
                    }
                    continue; // skip current position
                }
                first_match_row = row;
                first_match_col = col;
            }
        }
    }

    if (first_match_row) |row| {
        editor.cursor_row = row;
        editor.cursor_col = first_match_col orelse 0;
        editor.desired_col = editor.cursor_col;
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Found '{s}' ({d} matches)", .{ term, matches }) catch "Found";
        editor.status.set(msg, false);
    } else {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Pattern not found: '{s}'", .{term}) catch "Not found";
        editor.status.set(msg, true);
    }
}

fn searchReplace(event: *plugin.PluginEvent) void {
    const args = event.command_args orelse {
        event.editor.status.set("Usage: :search.replace <find>/<replace>", true);
        return;
    };

    // Parse find/replace pattern
    const sep_idx = std.mem.indexOfScalar(u8, args, '/') orelse {
        event.editor.status.set("Usage: :search.replace <find>/<replace>", true);
        return;
    };
    const find = args[0..sep_idx];
    const replace = args[sep_idx + 1 ..];

    if (find.len == 0) {
        event.editor.status.set("Empty search pattern", true);
        return;
    }

    const editor = event.editor;
    var replacements: usize = 0;

    // Replace in current line
    const line = editor.buffer.getLine(editor.cursor_row);
    if (indexOf(line, find)) |col| {
        const offset = editor.buffer.posToOffset(editor.cursor_row, col);
        editor.buffer.deleteRange(offset, find.len) catch return;
        editor.buffer.insertSlice(offset, replace) catch return;
        replacements += 1;
    }

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Replaced {d} occurrence(s)", .{replacements}) catch "Replaced";
    editor.status.set(msg, false);
}

fn searchVault(event: *plugin.PluginEvent) void {
    const term = event.command_args orelse {
        event.editor.status.set("Usage: :search.vault <term>", true);
        return;
    };

    var matches: usize = 0;
    var first_file: ?[]const u8 = null;

    // Scan current directory for .md and .rndm files
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        event.editor.status.set("Cannot open directory", true);
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        const is_md = std.mem.endsWith(u8, entry.name, ".md") or
            std.mem.endsWith(u8, entry.name, ".rndm");
        if (!is_md) continue;

        // Read file and search
        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [4096]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;
        const content = read_buf[0..n];

        if (indexOf(content, term) != null) {
            matches += 1;
            if (first_file == null) first_file = entry.name;
        }
    }

    var buf: [256]u8 = undefined;
    if (matches > 0) {
        const msg = std.fmt.bufPrint(&buf, "Vault search: {d} file(s) match '{s}'", .{ matches, term }) catch "Found";
        event.editor.status.set(msg, false);
    } else {
        const msg = std.fmt.bufPrint(&buf, "No files contain '{s}'", .{term}) catch "Not found";
        event.editor.status.set(msg, true);
    }
}

fn indexOf(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0 or needle.len > haystack.len) return null;
    for (0..haystack.len - needle.len + 1) |i| {
        if (std.mem.eql(u8, haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}

test "search plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("search", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "indexOf" {
    try std.testing.expectEqual(@as(?usize, 0), indexOf("hello", "hello"));
    try std.testing.expectEqual(@as(?usize, 2), indexOf("xxhello", "hello"));
    try std.testing.expectEqual(@as(?usize, null), indexOf("hi", "hello"));
}
