const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Todoist plugin — extract and manage tasks from markdown.
/// Scans document for `- [ ]` items and manages them locally.
/// Future: sync with Todoist API when configured.
/// Commands: :todoist, :todoist.add, :todoist.done, :todoist.inbox
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "todoist", .version = "0.1.0", .author = "lazy-md contributors", .description = "Todoist task integration" };
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
        .{ .name = "todoist", .description = "Show task summary", .handler = &showTasks },
        .{ .name = "todoist.add", .description = "Add task at cursor", .handler = &addTask },
        .{ .name = "todoist.done", .description = "Mark tasks done on line", .handler = &markDone },
        .{ .name = "todoist.inbox", .description = "Show all open tasks", .handler = &showInbox },
    };
}

fn showTasks(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var open: usize = 0;
    var done: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (std.mem.indexOf(u8, line, "- [ ]") != null) open += 1;
        if (std.mem.indexOf(u8, line, "- [x]") != null or std.mem.indexOf(u8, line, "- [X]") != null) done += 1;
    }

    const total = open + done;
    if (total == 0) {
        editor.status.set("No tasks found. Use :todoist.add to create one", false);
        return;
    }
    var buf: [128]u8 = undefined;
    const pct = if (total > 0) (done * 100) / total else 0;
    const msg = std.fmt.bufPrint(&buf, "Tasks: {d} open, {d} done ({d}% complete)", .{ open, done, pct }) catch "Tasks";
    editor.status.set(msg, false);
}

fn addTask(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const task = event.command_args orelse {
        editor.status.set("Usage: :todoist.add <task description>", true);
        return;
    };

    var buf: [256]u8 = undefined;
    const item = std.fmt.bufPrint(&buf, "\n- [ ] {s}", .{task}) catch {
        editor.status.set("Task too long", true);
        return;
    };

    const line_end = editor.buffer.posToOffset(editor.cursor_row, editor.buffer.getLineLen(editor.cursor_row));
    editor.buffer.insertSlice(line_end, item) catch {
        editor.status.set("Failed to add task", true);
        return;
    };
    editor.cursor_row += 1;

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Task added: {s}", .{task}) catch "Added";
    editor.status.set(msg, false);
}

fn markDone(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const line = editor.buffer.getLine(editor.cursor_row);

    if (std.mem.indexOf(u8, line, "- [ ]")) |idx| {
        // Replace [ ] with [x]
        const offset = editor.buffer.posToOffset(editor.cursor_row, idx + 3);
        editor.buffer.deleteRange(offset, offset + 1) catch return;
        editor.buffer.insertSlice(offset, "x") catch return;
        editor.status.set("Task completed!", false);
    } else if (std.mem.indexOf(u8, line, "- [x]") != null or std.mem.indexOf(u8, line, "- [X]") != null) {
        editor.status.set("Task already done", false);
    } else {
        editor.status.set("No task on this line", false);
    }
}

fn showInbox(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [256]u8 = undefined;
    const hdr = "Open: ";
    @memcpy(buf[0..hdr.len], hdr);
    var pos: usize = hdr.len;
    var count: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (std.mem.indexOf(u8, line, "- [ ]")) |idx| {
            count += 1;
            // Get task text after "- [ ] "
            const text_start = idx + 6;
            if (text_start < line.len) {
                var text_end = line.len;
                while (text_end > text_start and (line[text_end - 1] == '\n' or line[text_end - 1] == '\r')) : (text_end -= 1) {}
                const text = line[text_start..text_end];
                const max = @min(text.len, buf.len - pos - 10);
                if (max > 0) {
                    @memcpy(buf[pos .. pos + max], text[0..max]);
                    pos += max;
                    buf[pos] = ';';
                    pos += 1;
                    buf[pos] = ' ';
                    pos += 1;
                }
            }
            if (count >= 5) break;
        }
    }

    if (count == 0) {
        editor.status.set("Inbox empty — all tasks done!", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

test "todoist plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("todoist", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 4), cmds.len);
}
