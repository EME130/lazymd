const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Journal plugin — chronological journal entries with timestamps.
/// Creates journal/ directory with timestamped entries.
/// :journal.new inserts a timestamped entry at cursor.
/// Commands: :journal, :journal.new, :journal.timestamp
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "journal", .version = "0.1.0", .author = "lazy-md contributors", .description = "Chronological journal entries" };
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
        .{ .name = "journal", .description = "Open today's journal", .handler = &openJournal },
        .{ .name = "journal.new", .description = "New timestamped entry at cursor", .handler = &newEntry },
        .{ .name = "journal.timestamp", .description = "Insert timestamp at cursor", .handler = &insertTimestamp },
    };
}

fn getTimestamp(buf: []u8) []const u8 {
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const ds = es.getDaySeconds();
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();

    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        yd.year,
        @intFromEnum(md.month) + 1,
        md.day_index + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    }) catch "timestamp";
}

fn openJournal(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();

    // Create journal directory
    std.fs.cwd().makeDir("journal") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create journal/ directory", true);
            return;
        },
    };

    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "journal/{d:0>4}-{d:0>2}-{d:0>2}.md", .{
        yd.year,
        @intFromEnum(md.month) + 1,
        md.day_index + 1,
    }) catch {
        editor.status.set("Date error", true);
        return;
    };

    editor.openFile(path) catch {
        // Create with template
        var ts_buf: [32]u8 = undefined;
        const ts = getTimestamp(&ts_buf);
        var tpl_buf: [256]u8 = undefined;
        const template = std.fmt.bufPrint(&tpl_buf, "# Journal — {s}\n\n## Entry\n\n\n", .{ts[0..10]}) catch "# Journal\n\n";

        const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
            editor.openFile(path) catch {
                editor.status.set("Failed to create journal", true);
            };
            return;
        };
        file.writeAll(template) catch {};
        file.close();

        editor.openFile(path) catch {
            editor.status.set("Failed to open journal", true);
            return;
        };
    };

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Journal: {s}", .{path}) catch "Journal opened";
    editor.status.set(msg, false);
}

fn newEntry(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var ts_buf: [32]u8 = undefined;
    const ts = getTimestamp(&ts_buf);

    var entry_buf: [128]u8 = undefined;
    const entry = std.fmt.bufPrint(&entry_buf, "\n## {s}\n\n", .{ts}) catch "\n## Entry\n\n";

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, entry) catch {
        editor.status.set("Failed to insert entry", true);
        return;
    };
    editor.status.set("Journal entry added", false);
}

fn insertTimestamp(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var ts_buf: [32]u8 = undefined;
    const ts = getTimestamp(&ts_buf);

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, ts) catch {
        editor.status.set("Failed to insert timestamp", true);
        return;
    };
    editor.cursor_col += ts.len;
    editor.status.set("Timestamp inserted", false);
}

test "journal plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("journal", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
