const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Daily Notes plugin — create and navigate daily journal notes.
/// Creates files in daily/ directory with YYYY-MM-DD.md naming.
/// Commands: :daily, :daily.yesterday, :daily.tomorrow
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "daily-notes", .version = "0.1.0", .author = "lazy-md contributors", .description = "Daily journal notes" };
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
        .{ .name = "daily", .description = "Open today's daily note", .handler = &openDaily },
        .{ .name = "daily.yesterday", .description = "Open yesterday's note", .handler = &openYesterday },
        .{ .name = "daily.tomorrow", .description = "Open tomorrow's note", .handler = &openTomorrow },
    };
}

fn openDailyNote(editor: *Editor, day_offset: i32) void {
    const epoch = std.time.timestamp();
    const adjusted = epoch + @as(i64, day_offset) * 86400;
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(adjusted))) };
    const day = es.getDaySeconds();
    _ = day;
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();

    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "daily/{d:0>4}-{d:0>2}-{d:0>2}.md", .{
        yd.year,
        @intFromEnum(md.month) + 1,
        md.day_index + 1,
    }) catch {
        editor.status.set("Date format error", true);
        return;
    };

    // Ensure daily/ directory exists
    std.fs.cwd().makeDir("daily") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create daily/ directory", true);
            return;
        },
    };

    // Try to open, or create with template
    editor.openFile(path) catch {
        // File doesn't exist — create it with template
        const header_template = "# Daily Note\n\n## Tasks\n\n- [ ] \n\n## Notes\n\n\n\n## Journal\n\n\n";
        const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
            // Maybe another error; try opening again
            editor.openFile(path) catch {
                editor.status.set("Failed to create daily note", true);
            };
            return;
        };
        file.writeAll(header_template) catch {};
        file.close();
        editor.openFile(path) catch {
            editor.status.set("Failed to open daily note", true);
            return;
        };
    };

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Daily note: {s}", .{path}) catch "Daily note opened";
    editor.status.set(msg, false);
}

fn openDaily(event: *plugin.PluginEvent) void {
    openDailyNote(event.editor, 0);
}
fn openYesterday(event: *plugin.PluginEvent) void {
    openDailyNote(event.editor, -1);
}
fn openTomorrow(event: *plugin.PluginEvent) void {
    openDailyNote(event.editor, 1);
}

test "daily_notes plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("daily-notes", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
