const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Dataview plugin — query notes by frontmatter fields.
/// Scans vault for markdown files and queries their YAML frontmatter.
/// Commands: :dv, :dv.list, :dv.tasks
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "dataview", .version = "0.1.0", .author = "lazy-md contributors", .description = "Query note metadata and frontmatter" };
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
        .{ .name = "dv", .description = "Dataview vault scan", .handler = &dvScan },
        .{ .name = "dv.list", .description = "List files with field", .handler = &dvList },
        .{ .name = "dv.tasks", .description = "List all tasks across vault", .handler = &dvTasks },
    };
}

fn dvScan(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var total_files: usize = 0;
    var with_fm: usize = 0;

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
        var buf: [64]u8 = undefined;
        const n = file.readAll(&buf) catch continue;
        if (n >= 3 and std.mem.eql(u8, buf[0..3], "---")) {
            with_fm += 1;
        }
    }

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Dataview: {d} notes, {d} with frontmatter", .{ total_files, with_fm }) catch "Scanned";
    editor.status.set(msg, false);
}

fn dvList(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const field = event.command_args orelse {
        editor.status.set("Usage: :dv.list <field> (e.g. :dv.list tags)", true);
        return;
    };

    var match_count: usize = 0;
    var buf: [256]u8 = undefined;
    var pos: usize = 0;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [2048]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;
        const content = read_buf[0..n];

        // Check if file has the specified field in frontmatter
        if (n >= 3 and std.mem.eql(u8, content[0..3], "---")) {
            // Build "field:" pattern
            var pattern_buf: [64]u8 = undefined;
            const pattern = std.fmt.bufPrint(&pattern_buf, "{s}:", .{field}) catch continue;
            if (std.mem.indexOf(u8, content, pattern) != null) {
                match_count += 1;
                if (pos + entry.name.len + 1 < buf.len) {
                    @memcpy(buf[pos .. pos + entry.name.len], entry.name);
                    pos += entry.name.len;
                    buf[pos] = ' ';
                    pos += 1;
                }
            }
        }
    }

    if (match_count == 0) {
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "No notes with '{s}' field", .{field}) catch "Not found";
        editor.status.set(msg, false);
    } else {
        var msg_buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "{s}: ({d}) {s}", .{ field, match_count, buf[0..pos] }) catch "Found";
        editor.status.set(msg, false);
    }
}

fn dvTasks(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var total_tasks: usize = 0;
    var done_tasks: usize = 0;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
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
        const content = read_buf[0..n];

        var i: usize = 0;
        while (i + 5 < n) : (i += 1) {
            if (std.mem.startsWith(u8, content[i..], "- [ ]")) total_tasks += 1;
            if (std.mem.startsWith(u8, content[i..], "- [x]") or std.mem.startsWith(u8, content[i..], "- [X]")) {
                total_tasks += 1;
                done_tasks += 1;
            }
        }
    }

    var msg_buf: [128]u8 = undefined;
    if (total_tasks == 0) {
        editor.status.set("No tasks found in vault", false);
    } else {
        const pct = (done_tasks * 100) / total_tasks;
        const msg = std.fmt.bufPrint(&msg_buf, "Vault tasks: {d}/{d} complete ({d}%)", .{ done_tasks, total_tasks, pct }) catch "Tasks";
        editor.status.set(msg, false);
    }
}

test "dataview plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("dataview", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
