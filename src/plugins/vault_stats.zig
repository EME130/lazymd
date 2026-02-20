const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Vault Stats plugin — comprehensive vault statistics dashboard.
/// Shows note count, word count, link count, tag count, and more.
/// Commands: :vault, :vault.health, :vault.summary
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "vault-stats", .version = "0.1.0", .author = "lazy-md contributors", .description = "Vault analytics and statistics" };
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
        .{ .name = "vault", .description = "Show vault overview stats", .handler = &showStats },
        .{ .name = "vault.health", .description = "Check vault health", .handler = &checkHealth },
        .{ .name = "vault.summary", .description = "Insert vault summary at cursor", .handler = &insertSummary },
    };
}

fn showStats(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var notes: usize = 0;
    var total_words: usize = 0;
    var total_links: usize = 0;
    var total_tags: usize = 0;
    var total_tasks: usize = 0;
    var total_size: u64 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;
        notes += 1;

        const stat = dir.statFile(entry.name) catch continue;
        total_size += stat.size;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [4096]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;
        const content = read_buf[0..n];

        // Count words
        var in_word = false;
        for (content) |ch| {
            if (ch == ' ' or ch == '\n' or ch == '\t' or ch == '\r') {
                in_word = false;
            } else if (!in_word) {
                in_word = true;
                total_words += 1;
            }
        }

        // Count [[links]]
        var i: usize = 0;
        while (i + 3 < n) : (i += 1) {
            if (content[i] == '[' and content[i + 1] == '[') {
                if (std.mem.indexOf(u8, content[i + 2 ..], "]]") != null) total_links += 1;
            }
        }

        // Count #tags
        i = 0;
        while (i < n) : (i += 1) {
            if (content[i] == '#' and (i == 0 or content[i - 1] == ' ' or content[i - 1] == '\n')) {
                if (i + 1 < n and std.ascii.isAlphabetic(content[i + 1])) total_tags += 1;
            }
        }

        // Count tasks
        var j: usize = 0;
        while (j + 4 < n) : (j += 1) {
            if (std.mem.startsWith(u8, content[j..], "- [ ]") or std.mem.startsWith(u8, content[j..], "- [x]") or std.mem.startsWith(u8, content[j..], "- [X]")) {
                total_tasks += 1;
            }
        }
    }

    var buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Vault: {d} notes | {d} words | {d} [[links]] | {d} #tags | {d} tasks | {d}KB", .{ notes, total_words, total_links, total_tags, total_tasks, total_size / 1024 }) catch "Stats";
    editor.status.set(msg, false);
}

fn checkHealth(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var empty_notes: usize = 0;
    var no_heading: usize = 0;
    var total: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;
        total += 1;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [2048]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;

        if (n < 5) empty_notes += 1;
        if (std.mem.indexOf(u8, read_buf[0..n], "# ") == null) no_heading += 1;
    }

    var buf: [128]u8 = undefined;
    if (empty_notes == 0 and no_heading == 0) {
        const msg = std.fmt.bufPrint(&buf, "Vault healthy: {d} notes, all have content and headings", .{total}) catch "Healthy";
        editor.status.set(msg, false);
    } else {
        const msg = std.fmt.bufPrint(&buf, "Health: {d} empty notes, {d} missing headings (of {d} total)", .{ empty_notes, no_heading, total }) catch "Issues";
        editor.status.set(msg, true);
    }
}

fn insertSummary(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var notes: usize = 0;
    var folders: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.name[0] == '.') continue;
        if (entry.kind == .directory) folders += 1;
        if (entry.kind == .file and (std.mem.endsWith(u8, entry.name, ".md") or std.mem.endsWith(u8, entry.name, ".rndm"))) notes += 1;
    }

    var buf: [256]u8 = undefined;
    const summary = std.fmt.bufPrint(&buf, "\n## Vault Summary\n\n- **Notes**: {d}\n- **Folders**: {d}\n- **Editor**: lazy-md\n\n", .{ notes, folders }) catch {
        editor.status.set("Format error", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, summary) catch {
        editor.status.set("Insert failed", true);
        return;
    };
    editor.status.set("Vault summary inserted", false);
}

test "vault_stats plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("vault-stats", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
