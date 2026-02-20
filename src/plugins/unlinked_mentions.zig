const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Unlinked Mentions plugin — find mentions of note titles that aren't linked.
/// Scans vault for occurrences of the current note's name that aren't wrapped in [[...]].
/// Commands: :unlinked, :unlinked.link
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "unlinked-mentions", .version = "0.1.0", .author = "lazy-md contributors", .description = "Find unlinked mentions of current note" };
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
        .{ .name = "unlinked", .description = "Find unlinked mentions across vault", .handler = &findUnlinked },
        .{ .name = "unlinked.link", .description = "Convert mention on line to [[link]]", .handler = &linkMention },
    };
}

fn findUnlinked(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Get current file stem (the "note title")
    const stem = blk: {
        if (editor.file_path) |fp| {
            const name = if (std.mem.lastIndexOfScalar(u8, fp, '/')) |s| fp[s + 1 ..] else fp;
            if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot| break :blk name[0..dot];
            break :blk name;
        }
        editor.status.set("No file open — save first", true);
        return;
    };

    if (stem.len == 0) {
        editor.status.set("Cannot determine note title", true);
        return;
    }

    // Build linked pattern [[stem]]
    var linked_buf: [128]u8 = undefined;
    const linked_pattern = std.fmt.bufPrint(&linked_buf, "[[{s}]]", .{stem}) catch {
        editor.status.set("Name too long", true);
        return;
    };

    // Scan vault
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var unlinked_files: usize = 0;
    var total_mentions: usize = 0;
    var results_buf: [256]u8 = undefined;
    const hdr = "Unlinked in: ";
    @memcpy(results_buf[0..hdr.len], hdr);
    var pos: usize = hdr.len;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;
        // Skip self
        if (editor.file_path) |fp| {
            const self_name = if (std.mem.lastIndexOfScalar(u8, fp, '/')) |s| fp[s + 1 ..] else fp;
            if (std.mem.eql(u8, entry.name, self_name)) continue;
        }

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [4096]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;
        const content = read_buf[0..n];

        // Check if stem appears but NOT as [[stem]]
        var has_mention = false;
        var has_link = false;

        if (containsIgnoreCase(content, stem)) has_mention = true;
        if (std.mem.indexOf(u8, content, linked_pattern) != null) has_link = true;

        if (has_mention and !has_link) {
            unlinked_files += 1;
            total_mentions += 1;
            if (pos + entry.name.len + 2 < results_buf.len) {
                @memcpy(results_buf[pos .. pos + entry.name.len], entry.name);
                pos += entry.name.len;
                results_buf[pos] = ' ';
                pos += 1;
            }
        }
    }

    if (unlinked_files == 0) {
        editor.status.set("No unlinked mentions found", false);
    } else {
        editor.status.set(results_buf[0..pos], false);
    }
}

fn linkMention(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const word = event.command_args orelse {
        editor.status.set("Usage: :unlinked.link <note-name>", true);
        return;
    };

    // Find word on current line and wrap in [[ ]]
    const line = editor.buffer.getLine(editor.cursor_row);
    if (containsIgnoreCasePos(line, word)) |idx| {
        const offset = editor.buffer.posToOffset(editor.cursor_row, idx);
        // Insert ]] after
        editor.buffer.insertSlice(offset + word.len, "]]") catch {
            editor.status.set("Link failed", true);
            return;
        };
        // Insert [[ before
        editor.buffer.insertSlice(offset, "[[") catch {
            editor.status.set("Link failed", true);
            return;
        };
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Linked: [[{s}]]", .{word}) catch "Linked";
        editor.status.set(msg, false);
    } else {
        editor.status.set("Word not found on current line", true);
    }
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return containsIgnoreCasePos(haystack, needle) != null;
}

fn containsIgnoreCasePos(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len > haystack.len) return null;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}

test "unlinked_mentions plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("unlinked-mentions", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}

test "containsIgnoreCase" {
    try std.testing.expect(containsIgnoreCase("Hello World", "world"));
    try std.testing.expect(!containsIgnoreCase("abc", "xyz"));
}
