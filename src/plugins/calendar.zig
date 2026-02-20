const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Calendar plugin — visual ASCII calendar for navigating daily notes.
/// Shows current month with days, highlights today.
/// Commands: :cal, :cal.today, :cal.goto
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "calendar", .version = "0.1.0", .author = "lazy-md contributors", .description = "Visual calendar navigation" };
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
        .{ .name = "cal", .description = "Insert ASCII calendar for current month", .handler = &showCalendar },
        .{ .name = "cal.today", .description = "Open today's daily note", .handler = &jumpToday },
        .{ .name = "cal.goto", .description = "Open daily note for date", .handler = &gotoDate },
    };
}

fn getDateParts() struct { year: u16, month: u9, day: u9 } {
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    return .{
        .year = yd.year,
        .month = @intFromEnum(md.month) + 1,
        .day = md.day_index + 1,
    };
}

fn daysInMonth(month: u9, year: u16) u9 {
    const days = [_]u9{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    if (month == 2) {
        if (@rem(year, 4) == 0 and (@rem(year, 100) != 0 or @rem(year, 400) == 0)) return 29;
        return 28;
    }
    return days[month - 1];
}

fn monthName(m: u9) []const u8 {
    const names = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
    if (m >= 1 and m <= 12) return names[m - 1];
    return "Unknown";
}

fn showCalendar(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const d = getDateParts();
    const dim = daysInMonth(d.month, d.year);

    var buf: [512]u8 = undefined;
    var pos: usize = 0;

    // Header
    const header = std.fmt.bufPrint(buf[pos..], "## {s} {d}\n\n| Mo | Tu | We | Th | Fr | Sa | Su |\n|----|----|----|----|----|----|----|\n", .{ monthName(d.month), d.year }) catch {
        editor.status.set("Calendar: format error", true);
        return;
    };
    pos += header.len;

    // Simple day-of-week calculation (Zeller-like for first of month)
    // Jan 1 2024 was Monday (0-indexed: Mon=0)
    // Count days from Jan 1 2024 to first of target month
    var day_count: i32 = 0;
    var y: u16 = 2024;
    while (y < d.year) : (y += 1) {
        if (@rem(y, 4) == 0 and (@rem(y, 100) != 0 or @rem(y, 400) == 0)) {
            day_count += 366;
        } else {
            day_count += 365;
        }
    }
    var m: u9 = 1;
    while (m < d.month) : (m += 1) {
        day_count += daysInMonth(m, d.year);
    }
    // Jan 1 2024 is Monday (dow=0 for Mon)
    const first_dow: usize = @intCast(@rem(@as(i32, @intCast(@rem(day_count, 7))), 7));

    // Fill calendar
    buf[pos] = '|';
    pos += 1;
    var col: usize = 0;
    while (col < first_dow) : (col += 1) {
        const cell = std.fmt.bufPrint(buf[pos..], "    |", .{}) catch break;
        pos += cell.len;
    }

    var day: u9 = 1;
    while (day <= dim) : (day += 1) {
        const marker: u8 = if (day == d.day) '*' else ' ';
        const cell = std.fmt.bufPrint(buf[pos..], " {d:>2}{c}|", .{ day, marker }) catch break;
        pos += cell.len;
        col += 1;
        if (col == 7 and day < dim) {
            buf[pos] = '\n';
            pos += 1;
            buf[pos] = '|';
            pos += 1;
            col = 0;
        }
    }
    // Pad remaining cells
    while (col < 7) : (col += 1) {
        const cell = std.fmt.bufPrint(buf[pos..], "    |", .{}) catch break;
        pos += cell.len;
    }
    buf[pos] = '\n';
    pos += 1;

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, buf[0..pos]) catch {
        editor.status.set("Failed to insert calendar", true);
        return;
    };
    editor.status.set("Calendar inserted (* = today)", false);
}

fn jumpToday(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const d = getDateParts();
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "daily/{d:0>4}-{d:0>2}-{d:0>2}.md", .{ d.year, d.month, d.day }) catch {
        editor.status.set("Date format error", true);
        return;
    };

    // Try to open, or create if missing
    std.fs.cwd().makeDir("daily") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {},
    };

    if (std.fs.cwd().access(path, .{})) {
        editor.openFile(path) catch {
            editor.status.set("Failed to open today's note", true);
            return;
        };
    } else |_| {
        const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
            editor.status.set("Failed to create today's note", true);
            return;
        };
        var tpl_buf: [256]u8 = undefined;
        const tpl = std.fmt.bufPrint(&tpl_buf, "# {d:0>4}-{d:0>2}-{d:0>2}\n\n## Tasks\n\n- [ ] \n\n## Notes\n\n", .{ d.year, d.month, d.day }) catch "";
        file.writeAll(tpl) catch {};
        file.close();
        editor.openFile(path) catch {};
    }

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Today: {d:0>4}-{d:0>2}-{d:0>2}", .{ d.year, d.month, d.day }) catch "Today";
    editor.status.set(msg, false);
}

fn gotoDate(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const date = event.command_args orelse {
        editor.status.set("Usage: :cal.goto YYYY-MM-DD", true);
        return;
    };
    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "daily/{s}.md", .{date}) catch {
        editor.status.set("Date too long", true);
        return;
    };
    editor.openFile(path) catch {
        var msg_buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "No note found: {s}", .{date}) catch "Not found";
        editor.status.set(msg, true);
        return;
    };
}

test "calendar plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("calendar", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "daysInMonth" {
    try std.testing.expectEqual(@as(u9, 31), daysInMonth(1, 2024));
    try std.testing.expectEqual(@as(u9, 29), daysInMonth(2, 2024)); // leap year
    try std.testing.expectEqual(@as(u9, 28), daysInMonth(2, 2023));
    try std.testing.expectEqual(@as(u9, 30), daysInMonth(4, 2024));
}
