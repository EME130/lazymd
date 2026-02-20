const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Periodic Notes plugin — weekly and monthly note templates.
/// Creates periodic/ directory with structured review templates.
/// Commands: :weekly, :monthly, :quarterly
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "periodic-notes", .version = "0.1.0", .author = "lazy-md contributors", .description = "Weekly and monthly journal notes" };
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
        .{ .name = "weekly", .description = "Open/create this week's note", .handler = &openWeekly },
        .{ .name = "monthly", .description = "Open/create this month's note", .handler = &openMonthly },
        .{ .name = "quarterly", .description = "Open/create quarterly review", .handler = &openQuarterly },
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

fn monthName(m: u9) []const u8 {
    const names = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
    if (m >= 1 and m <= 12) return names[m - 1];
    return "Unknown";
}

fn openWeekly(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const d = getDateParts();

    std.fs.cwd().makeDir("periodic") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create periodic/ directory", true);
            return;
        },
    };

    // Week number approximation: day of year / 7
    const day_of_year = dayOfYear(d.month, d.day);
    const week_num = (day_of_year / 7) + 1;

    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "periodic/{d}-W{d:0>2}.md", .{ d.year, week_num }) catch {
        editor.status.set("Path error", true);
        return;
    };

    if (std.fs.cwd().access(path, .{})) {
        editor.openFile(path) catch {
            editor.status.set("Failed to open weekly note", true);
        };
        return;
    } else |_| {}

    const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
        editor.status.set("Weekly note already exists", true);
        return;
    };
    var tpl_buf: [512]u8 = undefined;
    const tpl = std.fmt.bufPrint(&tpl_buf,
        \\# Week {d}, {d}
        \\
        \\## Goals
        \\
        \\- [ ]
        \\
        \\## Monday
        \\
        \\## Tuesday
        \\
        \\## Wednesday
        \\
        \\## Thursday
        \\
        \\## Friday
        \\
        \\## Weekend
        \\
        \\## Review
        \\
        \\### What went well?
        \\
        \\### What could improve?
        \\
        \\### Next week's focus
        \\
        \\
    , .{ week_num, d.year }) catch "";
    file.writeAll(tpl) catch {};
    file.close();
    editor.openFile(path) catch {};

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Weekly note: W{d:0>2} {d}", .{ week_num, d.year }) catch "Created";
    editor.status.set(msg, false);
}

fn openMonthly(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const d = getDateParts();

    std.fs.cwd().makeDir("periodic") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create periodic/ directory", true);
            return;
        },
    };

    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "periodic/{d}-{d:0>2}.md", .{ d.year, d.month }) catch {
        editor.status.set("Path error", true);
        return;
    };

    if (std.fs.cwd().access(path, .{})) {
        editor.openFile(path) catch {
            editor.status.set("Failed to open monthly note", true);
        };
        return;
    } else |_| {}

    const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
        editor.status.set("Monthly note already exists", true);
        return;
    };
    var tpl_buf: [512]u8 = undefined;
    const tpl = std.fmt.bufPrint(&tpl_buf,
        \\# {s} {d}
        \\
        \\## Goals
        \\
        \\- [ ]
        \\
        \\## Projects
        \\
        \\## Highlights
        \\
        \\## Challenges
        \\
        \\## Monthly Review
        \\
        \\### Accomplishments
        \\
        \\### Lessons Learned
        \\
        \\### Next Month Focus
        \\
        \\
    , .{ monthName(d.month), d.year }) catch "";
    file.writeAll(tpl) catch {};
    file.close();
    editor.openFile(path) catch {};

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Monthly note: {s} {d}", .{ monthName(d.month), d.year }) catch "Created";
    editor.status.set(msg, false);
}

fn openQuarterly(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const d = getDateParts();
    const quarter = ((d.month - 1) / 3) + 1;

    std.fs.cwd().makeDir("periodic") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {},
    };

    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "periodic/{d}-Q{d}.md", .{ d.year, quarter }) catch {
        editor.status.set("Path error", true);
        return;
    };

    if (std.fs.cwd().access(path, .{})) {
        editor.openFile(path) catch {};
        return;
    } else |_| {}

    const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
        editor.status.set("Quarterly note exists", true);
        return;
    };
    var tpl_buf: [256]u8 = undefined;
    const tpl = std.fmt.bufPrint(&tpl_buf,
        \\# Q{d} {d} Review
        \\
        \\## OKRs
        \\
        \\## Key Results
        \\
        \\## Retrospective
        \\
        \\## Next Quarter Planning
        \\
        \\
    , .{ quarter, d.year }) catch "";
    file.writeAll(tpl) catch {};
    file.close();
    editor.openFile(path) catch {};
    editor.status.set("Quarterly note created", false);
}

fn dayOfYear(month: u9, day: u9) u16 {
    const cum = [_]u16{ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
    if (month >= 1 and month <= 12) return cum[month - 1] + day;
    return day;
}

test "periodic_notes plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("periodic-notes", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "dayOfYear" {
    try std.testing.expectEqual(@as(u16, 1), dayOfYear(1, 1));
    try std.testing.expectEqual(@as(u16, 32), dayOfYear(2, 1));
    try std.testing.expectEqual(@as(u16, 365), dayOfYear(12, 31));
}
