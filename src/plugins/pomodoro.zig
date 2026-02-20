const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Pomodoro plugin — built-in pomodoro timer for focused writing.
/// Tracks start time and shows remaining time on status check.
/// Commands: :pomo.start, :pomo.stop, :pomo.status
start_time: i64 = 0,
duration_min: u32 = 25,
sessions: u32 = 0,

pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "pomodoro", .version = "0.1.0", .author = "lazy-md contributors", .description = "Pomodoro focus timer" };
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
        .{ .name = "pomo.start", .description = "Start 25-min pomodoro", .handler = &start },
        .{ .name = "pomo.stop", .description = "Stop pomodoro timer", .handler = &stop },
        .{ .name = "pomo.status", .description = "Show timer status", .handler = &showStatus },
    };
}

// Use a global to track state since handler functions are static
var g_start_time: i64 = 0;
var g_sessions: u32 = 0;

fn start(event: *plugin.PluginEvent) void {
    g_start_time = std.time.timestamp();
    g_sessions += 1;
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Pomodoro #{d} started (25:00) — focus time!", .{g_sessions}) catch "Pomodoro started";
    event.editor.status.set(msg, false);
}

fn stop(event: *plugin.PluginEvent) void {
    if (g_start_time == 0) {
        event.editor.status.set("No active pomodoro", false);
        return;
    }
    const elapsed = std.time.timestamp() - g_start_time;
    g_start_time = 0;
    const mins: u64 = @intCast(@divTrunc(elapsed, 60));
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Pomodoro stopped after {d} min — {d} sessions today", .{ mins, g_sessions }) catch "Stopped";
    event.editor.status.set(msg, false);
}

fn showStatus(event: *plugin.PluginEvent) void {
    if (g_start_time == 0) {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "No active pomodoro — {d} sessions completed", .{g_sessions}) catch "No timer";
        event.editor.status.set(msg, false);
        return;
    }

    const elapsed = std.time.timestamp() - g_start_time;
    const total_secs: i64 = 25 * 60;
    const remaining = @max(total_secs - elapsed, 0);
    const mins: u64 = @intCast(@divTrunc(remaining, 60));
    const secs: u64 = @intCast(@mod(remaining, 60));

    var buf: [64]u8 = undefined;
    if (remaining <= 0) {
        const msg = std.fmt.bufPrint(&buf, "Pomodoro #{d} complete! Take a break.", .{g_sessions}) catch "Done!";
        event.editor.status.set(msg, false);
    } else {
        const msg = std.fmt.bufPrint(&buf, "Pomodoro #{d}: {d:0>2}:{d:0>2} remaining", .{ g_sessions, mins, secs }) catch "Running...";
        event.editor.status.set(msg, false);
    }
}

test "pomodoro plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("pomodoro", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
