const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Day Planner plugin — time-blocked daily planning with markdown.
/// Creates planner files and inserts time block templates.
/// Commands: :plan, :plan.today, :plan.template
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "day-planner", .version = "0.1.0", .author = "lazy-md contributors", .description = "Time-blocked daily planning" };
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
        .{ .name = "plan", .description = "Show current time block", .handler = &showPlan },
        .{ .name = "plan.today", .description = "Create today's planner", .handler = &todayPlan },
        .{ .name = "plan.template", .description = "Insert time block template", .handler = &insertTemplate },
    };
}

fn getTime() struct { year: u16, month: u9, day: u9, hour: u8, min: u8 } {
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    return .{
        .year = yd.year,
        .month = @intFromEnum(md.month) + 1,
        .day = md.day_index + 1,
        .hour = ds.getHoursIntoDay(),
        .min = ds.getMinutesIntoHour(),
    };
}

fn showPlan(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const t = getTime();

    // Scan document for time blocks like "- HH:MM" and find current
    var current_block: ?[]const u8 = null;
    var next_block: ?[]const u8 = null;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (parseTimeBlock(line)) |block_hour| {
            if (block_hour <= t.hour and current_block == null) {
                current_block = line;
            } else if (block_hour > t.hour and next_block == null) {
                next_block = line;
            }
            if (block_hour <= t.hour) {
                current_block = line;
            }
        }
    }

    var buf: [128]u8 = undefined;
    if (current_block) |block| {
        const max = @min(block.len, 60);
        const msg = std.fmt.bufPrint(&buf, "Now ({d:0>2}:{d:0>2}): {s}", .{ t.hour, t.min, block[0..max] }) catch "Current block";
        editor.status.set(msg, false);
    } else {
        const msg = std.fmt.bufPrint(&buf, "No time blocks found ({d:0>2}:{d:0>2}). Use :plan.template", .{ t.hour, t.min }) catch "No blocks";
        editor.status.set(msg, false);
    }
}

fn parseTimeBlock(line: []const u8) ?u8 {
    // Look for patterns like "- HH:MM" or "- [ ] HH:MM"
    var i: usize = 0;
    // Skip whitespace and list markers
    while (i < line.len and (line[i] == ' ' or line[i] == '-' or line[i] == '[' or line[i] == ']' or line[i] == 'x' or line[i] == 'X')) : (i += 1) {}
    while (i < line.len and line[i] == ' ') : (i += 1) {}

    // Try to parse HH:MM
    if (i + 4 < line.len and line[i + 2] == ':') {
        const h1 = std.fmt.charToDigit(line[i], 10) catch return null;
        const h2 = std.fmt.charToDigit(line[i + 1], 10) catch return null;
        return h1 * 10 + h2;
    }
    return null;
}

fn todayPlan(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const t = getTime();

    std.fs.cwd().makeDir("planner") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create planner/ directory", true);
            return;
        },
    };

    var path_buf: [64]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "planner/{d:0>4}-{d:0>2}-{d:0>2}.md", .{ t.year, t.month, t.day }) catch {
        editor.status.set("Path error", true);
        return;
    };

    // Check if exists
    if (std.fs.cwd().access(path, .{})) {
        editor.openFile(path) catch {
            editor.status.set("Failed to open planner", true);
        };
        return;
    } else |_| {}

    const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
        editor.status.set("Planner file already exists", true);
        return;
    };
    var tpl_buf: [512]u8 = undefined;
    const tpl = std.fmt.bufPrint(&tpl_buf,
        \\# Day Plan: {d:0>4}-{d:0>2}-{d:0>2}
        \\
        \\## Morning
        \\- 06:00 Wake up / morning routine
        \\- 07:00 Breakfast
        \\- 08:00 Deep work block 1
        \\- 10:00 Break
        \\
        \\## Afternoon
        \\- 10:30 Deep work block 2
        \\- 12:00 Lunch
        \\- 13:00 Meetings / calls
        \\- 15:00 Deep work block 3
        \\
        \\## Evening
        \\- 17:00 Exercise
        \\- 18:00 Dinner
        \\- 19:00 Reading / learning
        \\- 21:00 Wind down
        \\
        \\## Notes
        \\
        \\
    , .{ t.year, t.month, t.day }) catch "";
    file.writeAll(tpl) catch {};
    file.close();
    editor.openFile(path) catch {};
    editor.status.set("Day planner created", false);
}

fn insertTemplate(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const template =
        \\## Time Blocks
        \\
        \\- 08:00 Morning focus
        \\- 09:00
        \\- 10:00
        \\- 11:00
        \\- 12:00 Lunch
        \\- 13:00
        \\- 14:00
        \\- 15:00
        \\- 16:00
        \\- 17:00 Wrap up
        \\
    ;
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, template) catch {
        editor.status.set("Failed to insert template", true);
        return;
    };
    editor.status.set("Time block template inserted", false);
}

test "day_planner plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("day-planner", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "parseTimeBlock" {
    try std.testing.expectEqual(@as(?u8, 8), parseTimeBlock("- 08:00 Morning"));
    try std.testing.expectEqual(@as(?u8, 12), parseTimeBlock("- [ ] 12:00 Lunch"));
    try std.testing.expectEqual(@as(?u8, null), parseTimeBlock("Just some text"));
}
