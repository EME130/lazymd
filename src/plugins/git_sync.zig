const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Git Sync plugin — auto-commit and sync notes with git.
/// Runs actual git commands via child processes.
/// Commands: :git, :git.commit, :git.push, :git.pull, :git.status, :git.log
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "git-sync", .version = "0.1.0", .author = "lazy-md contributors", .description = "Git-based note synchronization" };
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
        .{ .name = "git", .description = "Show git status", .handler = &gitStatus },
        .{ .name = "git.commit", .description = "Commit all changes", .handler = &gitCommit },
        .{ .name = "git.push", .description = "Push to remote", .handler = &gitPush },
        .{ .name = "git.pull", .description = "Pull from remote", .handler = &gitPull },
        .{ .name = "git.status", .description = "Show git status", .handler = &gitStatus },
        .{ .name = "git.log", .description = "Show recent commits", .handler = &gitLog },
    };
}

fn runGit(args: []const []const u8, out_buf: []u8) ?[]const u8 {
    var child = std.process.Child.init(args, std.heap.page_allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.spawn() catch return null;

    // Read stdout
    const stdout = child.stdout orelse return null;
    const n = stdout.readAll(out_buf) catch return null;

    _ = child.wait() catch return null;
    return out_buf[0..n];
}

fn gitStatus(event: *plugin.PluginEvent) void {
    var buf: [512]u8 = undefined;
    const output = runGit(&.{ "git", "status", "--short" }, &buf) orelse {
        event.editor.status.set("Git: not a git repository or git not found", true);
        return;
    };

    if (output.len == 0) {
        event.editor.status.set("Git: working tree clean", false);
    } else {
        // Count changes
        var changes: usize = 0;
        for (output) |c| {
            if (c == '\n') changes += 1;
        }
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "Git: {d} changed file(s)", .{changes}) catch "Git: changes detected";
        event.editor.status.set(msg, false);
    }
}

fn gitCommit(event: *plugin.PluginEvent) void {
    // Stage all changes
    var stage_buf: [256]u8 = undefined;
    _ = runGit(&.{ "git", "add", "-A" }, &stage_buf) orelse {
        event.editor.status.set("Git: failed to stage files", true);
        return;
    };

    // Commit with message
    const msg = if (event.command_args) |args| args else "Update notes";
    var commit_buf: [512]u8 = undefined;
    _ = runGit(&.{ "git", "commit", "-m", msg }, &commit_buf) orelse {
        event.editor.status.set("Git: commit failed (nothing to commit?)", true);
        return;
    };

    var result_buf: [128]u8 = undefined;
    const result = std.fmt.bufPrint(&result_buf, "Git: committed — {s}", .{msg}) catch "Git: committed";
    event.editor.status.set(result, false);
}

fn gitPush(event: *plugin.PluginEvent) void {
    var buf: [512]u8 = undefined;
    _ = runGit(&.{ "git", "push" }, &buf) orelse {
        event.editor.status.set("Git: push failed", true);
        return;
    };
    event.editor.status.set("Git: pushed to remote", false);
}

fn gitPull(event: *plugin.PluginEvent) void {
    var buf: [512]u8 = undefined;
    _ = runGit(&.{ "git", "pull" }, &buf) orelse {
        event.editor.status.set("Git: pull failed", true);
        return;
    };
    event.editor.status.set("Git: pulled from remote", false);
}

fn gitLog(event: *plugin.PluginEvent) void {
    var buf: [512]u8 = undefined;
    const output = runGit(&.{ "git", "log", "--oneline", "-5" }, &buf) orelse {
        event.editor.status.set("Git: cannot read log", true);
        return;
    };

    // Show first line of log
    const first_nl = std.mem.indexOfScalar(u8, output, '\n') orelse output.len;
    var msg_buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Git log: {s}", .{output[0..first_nl]}) catch "Git: log";
    event.editor.status.set(msg, false);
}

test "git_sync plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("git-sync", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 6), cmds.len);
}
