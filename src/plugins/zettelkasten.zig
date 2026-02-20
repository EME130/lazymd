const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Zettelkasten plugin — unique ID-based note linking system.
/// Creates timestamped notes with unique IDs and [[wiki-links]].
/// Commands: :zk.new, :zk.link, :zk.index
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "zettelkasten", .version = "0.1.0", .author = "lazy-md contributors", .description = "Zettelkasten note-taking method" };
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
        .{ .name = "zk.new", .description = "Create new zettel with unique ID", .handler = &newZettel },
        .{ .name = "zk.link", .description = "Insert [[wiki-link]] at cursor", .handler = &linkZettel },
        .{ .name = "zk.index", .description = "Show zettel index", .handler = &showIndex },
    };
}

fn newZettel(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const title = event.command_args orelse "untitled";

    // Generate timestamp-based ID: YYYYMMDDHHMMSS
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const ds = es.getDaySeconds();
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();

    var id_buf: [32]u8 = undefined;
    const zk_id = std.fmt.bufPrint(&id_buf, "{d:0>4}{d:0>2}{d:0>2}{d:0>2}{d:0>2}{d:0>2}", .{
        yd.year,
        @intFromEnum(md.month) + 1,
        md.day_index + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    }) catch "00000000000000";

    // Ensure zk/ directory
    std.fs.cwd().makeDir("zk") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create zk/ directory", true);
            return;
        },
    };

    // Create file
    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "zk/{s}.md", .{zk_id}) catch {
        editor.status.set("Path error", true);
        return;
    };

    // Build template with frontmatter
    var template_buf: [512]u8 = undefined;
    const template = std.fmt.bufPrint(&template_buf,
        \\---
        \\id: {s}
        \\title: "{s}"
        \\tags: []
        \\---
        \\
        \\# {s}
        \\
        \\
        \\
        \\## References
        \\
        \\
    , .{ zk_id, title, title }) catch {
        editor.status.set("Template error", true);
        return;
    };

    const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
        editor.status.set("Zettel already exists", true);
        return;
    };
    file.writeAll(template) catch {};
    file.close();

    editor.openFile(path) catch {
        editor.status.set("Failed to open new zettel", true);
        return;
    };

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "New zettel: {s} — {s}", .{ zk_id, title }) catch "Zettel created";
    editor.status.set(msg, false);
}

fn linkZettel(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const target = event.command_args orelse {
        editor.status.set("Usage: :zk.link <note-name>", true);
        return;
    };

    // Insert [[target]] at cursor
    var link_buf: [128]u8 = undefined;
    const link = std.fmt.bufPrint(&link_buf, "[[{s}]]", .{target}) catch {
        editor.status.set("Link too long", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, link) catch {
        editor.status.set("Failed to insert link", true);
        return;
    };
    editor.cursor_col += link.len;
    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Linked: [[{s}]]", .{target}) catch "Link inserted";
    editor.status.set(msg, false);
}

fn showIndex(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var count: usize = 0;

    // Scan zk/ directory
    var dir = std.fs.cwd().openDir("zk", .{ .iterate = true }) catch {
        editor.status.set("No zk/ directory found. Use :zk.new to create first zettel", false);
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".md")) {
            count += 1;
        }
    }

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Zettelkasten: {d} notes in zk/", .{count}) catch "Index error";
    editor.status.set(msg, false);
}

test "zettelkasten plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("zettelkasten", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
