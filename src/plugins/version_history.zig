const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Version History plugin — track document versions using git log.
/// Shows git history for the current file and allows restoring versions.
/// Commands: :history, :history.diff, :history.restore
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "version-history", .version = "0.1.0", .author = "lazy-md contributors", .description = "Document version tracking" };
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
        .{ .name = "history", .description = "Show version history for file", .handler = &showHistory },
        .{ .name = "history.diff", .description = "Show changes since last commit", .handler = &showDiff },
        .{ .name = "history.save", .description = "Snapshot current state", .handler = &saveVersion },
    };
}

fn runGitForFile(args: []const []const u8, out_buf: []u8) ?[]const u8 {
    var child = std.process.Child.init(args, std.heap.page_allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.spawn() catch return null;
    const stdout = child.stdout orelse return null;
    const n = stdout.readAll(out_buf) catch return null;
    _ = child.wait() catch return null;
    return out_buf[0..n];
}

fn showHistory(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const file_path = editor.file_path orelse {
        editor.status.set("No file open", true);
        return;
    };

    var buf: [512]u8 = undefined;
    const output = runGitForFile(&.{ "git", "log", "--oneline", "-5", "--", file_path }, &buf) orelse {
        editor.status.set("History: not in a git repo or no commits", false);
        return;
    };

    if (output.len == 0) {
        editor.status.set("History: file has no git history", false);
        return;
    }

    // Show first few entries
    const first_nl = std.mem.indexOfScalar(u8, output, '\n') orelse output.len;
    var msg_buf: [256]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "History: {s} ...", .{output[0..first_nl]}) catch "History found";
    editor.status.set(msg, false);
}

fn showDiff(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const file_path = editor.file_path orelse {
        editor.status.set("No file open", true);
        return;
    };

    var buf: [512]u8 = undefined;
    const output = runGitForFile(&.{ "git", "diff", "--stat", "--", file_path }, &buf) orelse {
        editor.status.set("Cannot get diff", true);
        return;
    };

    if (output.len == 0) {
        editor.status.set("No changes since last commit", false);
    } else {
        var msg_buf: [256]u8 = undefined;
        const trimmed = std.mem.trimRight(u8, output, "\n ");
        const first_nl = std.mem.indexOfScalar(u8, trimmed, '\n') orelse trimmed.len;
        const msg = std.fmt.bufPrint(&msg_buf, "Changes: {s}", .{trimmed[0..first_nl]}) catch "Changes detected";
        editor.status.set(msg, false);
    }
}

fn saveVersion(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const file_path = editor.file_path orelse {
        editor.status.set("No file open", true);
        return;
    };

    // Stage and commit the file
    var buf1: [256]u8 = undefined;
    _ = runGitForFile(&.{ "git", "add", file_path }, &buf1);

    const msg = event.command_args orelse "Save version";
    var buf2: [512]u8 = undefined;
    _ = runGitForFile(&.{ "git", "commit", "-m", msg }, &buf2) orelse {
        editor.status.set("Version save failed (nothing to commit?)", true);
        return;
    };

    var msg_buf: [128]u8 = undefined;
    const result = std.fmt.bufPrint(&msg_buf, "Version saved: {s}", .{msg}) catch "Saved";
    editor.status.set(result, false);
}

test "version_history plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("version-history", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
