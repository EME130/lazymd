const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Habit Tracker plugin — track daily habits using checkbox lists.
/// Uses ## Habits section with - [ ] and - [x] items.
/// Commands: :habit, :habit.new, :habit.add
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "habit-tracker", .version = "0.1.0", .author = "lazy-md contributors", .description = "Daily habit tracking" };
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
        .{ .name = "habit", .description = "Show habit stats", .handler = &showHabits },
        .{ .name = "habit.new", .description = "Create habit tracker template", .handler = &newTracker },
        .{ .name = "habit.add", .description = "Add new habit", .handler = &addHabit },
    };
}

fn showHabits(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var total: usize = 0;
    var done: usize = 0;

    // Look for habits section
    var in_habits = false;
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (std.mem.startsWith(u8, line, "## Habits")) {
            in_habits = true;
            continue;
        }
        if (in_habits and line.len > 1 and line[0] == '#') break;

        if (in_habits) {
            if (std.mem.indexOf(u8, line, "- [ ]") != null) total += 1;
            if (std.mem.indexOf(u8, line, "- [x]") != null or std.mem.indexOf(u8, line, "- [X]") != null) {
                total += 1;
                done += 1;
            }
        }
    }

    if (total == 0) {
        editor.status.set("No habits found (use :habit.new to create tracker)", false);
    } else {
        var buf: [64]u8 = undefined;
        const pct = (done * 100) / total;
        const msg = std.fmt.bufPrint(&buf, "Habits: {d}/{d} done ({d}%)", .{ done, total, pct }) catch "Habits";
        editor.status.set(msg, false);
    }
}

fn newTracker(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const template =
        \\## Habits
        \\
        \\- [ ] Exercise
        \\- [ ] Read 30 min
        \\- [ ] Meditate
        \\- [ ] Write
        \\- [ ] No social media
        \\
    ;
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, template) catch {
        editor.status.set("Failed to insert tracker", true);
        return;
    };
    editor.status.set("Habit tracker template inserted", false);
}

fn addHabit(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const name = event.command_args orelse {
        editor.status.set("Usage: :habit.add <habit name>", true);
        return;
    };

    var buf: [128]u8 = undefined;
    const item = std.fmt.bufPrint(&buf, "\n- [ ] {s}", .{name}) catch {
        editor.status.set("Name too long", true);
        return;
    };

    const line_end = editor.buffer.posToOffset(editor.cursor_row, editor.buffer.getLineLen(editor.cursor_row));
    editor.buffer.insertSlice(line_end, item) catch {
        editor.status.set("Failed to add habit", true);
        return;
    };
    editor.cursor_row += 1;
    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Habit added: {s}", .{name}) catch "Added";
    editor.status.set(msg, false);
}

test "habit_tracker plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("habit-tracker", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
