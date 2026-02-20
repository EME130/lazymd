const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

// ── TaskWarrior TUI Plugin ────────────────────────────────────────────
// Integrates with taskwarrior (https://taskwarrior.org) to display
// and manage tasks within the lazy-md editor.
//
// Commands:
//   :tw.list    - List pending tasks
//   :tw.add     - Add a new task
//   :tw.done    - Mark a task as done
//
// Requires taskwarrior (`task`) to be installed and in PATH.

task_output: [2048]u8 = undefined,
task_output_len: usize = 0,

pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{
        .name = "taskwarrior",
        .version = "0.1.0",
        .author = "lazy-md contributors",
        .description = "TaskWarrior TUI integration — view and manage tasks",
    };
}

pub fn pluginInit(self: *Self, editor: *Editor) void {
    _ = self;
    editor.status.set("TaskWarrior plugin loaded", false);
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
        .{
            .name = "tw.list",
            .description = "List pending tasks from TaskWarrior",
            .handler = &listTasks,
        },
        .{
            .name = "tw.add",
            .description = "Add a task (usage: :tw.add <description>)",
            .handler = &addTask,
        },
        .{
            .name = "tw.done",
            .description = "Mark a task as done (usage: :tw.done <id>)",
            .handler = &doneTask,
        },
    };
}

fn listTasks(event: *plugin.PluginEvent) void {
    const result = runTaskCommand(&.{ "task", "list", "rc.verbose=nothing" });
    if (result) |output| {
        // Show first line of output in status bar
        const first_line_end = std.mem.indexOfScalar(u8, output, '\n') orelse output.len;
        if (first_line_end > 0) {
            event.editor.status.set(output[0..first_line_end], false);
        } else {
            event.editor.status.set("No pending tasks", false);
        }
    } else {
        event.editor.status.set("TaskWarrior not found. Install: https://taskwarrior.org", true);
    }
}

fn addTask(event: *plugin.PluginEvent) void {
    if (event.command_args) |args| {
        if (args.len > 0) {
            const result = runTaskCommand(&.{ "task", "add", args });
            if (result != null) {
                event.editor.status.set("Task added", false);
            } else {
                event.editor.status.set("Failed to add task", true);
            }
            return;
        }
    }
    event.editor.status.set("Usage: :tw.add <task description>", true);
}

fn doneTask(event: *plugin.PluginEvent) void {
    if (event.command_args) |args| {
        if (args.len > 0) {
            const result = runTaskCommand(&.{ "task", args, "done" });
            if (result != null) {
                event.editor.status.set("Task marked done", false);
            } else {
                event.editor.status.set("Failed to complete task", true);
            }
            return;
        }
    }
    event.editor.status.set("Usage: :tw.done <task_id>", true);
}

fn runTaskCommand(argv: []const []const u8) ?[]const u8 {
    _ = argv;
    // Placeholder: In a real implementation, this would use
    // std.process.Child to execute the taskwarrior CLI.
    // For now, return null to indicate "not available".
    return null;
}

// ── Tests ─────────────────────────────────────────────────────────────

test "taskwarrior plugin info" {
    var tw = Self{};
    const info = tw.pluginInfo();
    try std.testing.expectEqualStrings("taskwarrior", info.name);
}

test "taskwarrior commands" {
    var tw = Self{};
    const cmds = tw.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
    try std.testing.expectEqualStrings("tw.list", cmds[0].name);
}
