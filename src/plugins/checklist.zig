const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Checklist plugin — manage markdown checklists with progress tracking.
/// Toggle checkboxes on current line, show progress stats.
/// Commands: :check, :check.toggle, :check.progress
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "checklist", .version = "0.1.0", .author = "lazy-md contributors", .description = "Checklist management and progress" };
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
        .{ .name = "check", .description = "Toggle checkbox at cursor", .handler = &toggleCheck },
        .{ .name = "check.toggle", .description = "Toggle checkbox at cursor", .handler = &toggleCheck },
        .{ .name = "check.progress", .description = "Show checklist progress", .handler = &showProgress },
    };
}

fn toggleCheck(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const line = editor.buffer.getLine(editor.cursor_row);

    // Find "- [ ]" or "- [x]" / "- [X]" in the current line
    if (findCheckbox(line)) |check_offset| {
        const buf_offset = editor.buffer.posToOffset(editor.cursor_row, check_offset);
        const ch = editor.buffer.byteAt(buf_offset);
        if (ch == ' ') {
            // Check it: replace space with x
            editor.buffer.deleteRange(buf_offset, 1) catch return;
            editor.buffer.insertSlice(buf_offset, "x") catch return;
            editor.status.set("Checked", false);
        } else {
            // Uncheck it: replace x/X with space
            editor.buffer.deleteRange(buf_offset, 1) catch return;
            editor.buffer.insertSlice(buf_offset, " ") catch return;
            editor.status.set("Unchecked", false);
        }
    } else {
        // No checkbox found — insert one at the beginning of the line
        const line_start = editor.buffer.posToOffset(editor.cursor_row, 0);
        editor.buffer.insertSlice(line_start, "- [ ] ") catch {
            editor.status.set("Failed to insert checkbox", true);
            return;
        };
        editor.cursor_col += 6;
        editor.status.set("Checkbox added", false);
    }
}

fn showProgress(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var total: usize = 0;
    var done: usize = 0;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (isUnchecked(line)) {
            total += 1;
        } else if (isChecked(line)) {
            total += 1;
            done += 1;
        }
    }

    var buf: [128]u8 = undefined;
    if (total == 0) {
        event.editor.status.set("No checkboxes found", false);
    } else {
        const pct = (done * 100) / total;
        const msg = std.fmt.bufPrint(&buf, "Progress: {d}/{d} ({d}%)", .{ done, total, pct }) catch "Error";
        event.editor.status.set(msg, false);
    }
}

/// Returns the offset of the character inside [ ] if a checkbox is found
fn findCheckbox(line: []const u8) ?usize {
    // Look for "- [ ]" or "- [x]" or "- [X]"
    for (0..line.len) |i| {
        if (i + 4 < line.len and
            line[i] == '-' and line[i + 1] == ' ' and line[i + 2] == '[' and
            (line[i + 3] == ' ' or line[i + 3] == 'x' or line[i + 3] == 'X') and
            line[i + 4] == ']')
        {
            return i + 3; // offset of the char inside brackets
        }
    }
    return null;
}

fn isUnchecked(line: []const u8) bool {
    for (0..line.len) |i| {
        if (i + 4 < line.len and
            line[i] == '-' and line[i + 1] == ' ' and line[i + 2] == '[' and
            line[i + 3] == ' ' and line[i + 4] == ']') return true;
    }
    return false;
}

fn isChecked(line: []const u8) bool {
    for (0..line.len) |i| {
        if (i + 4 < line.len and
            line[i] == '-' and line[i + 1] == ' ' and line[i + 2] == '[' and
            (line[i + 3] == 'x' or line[i + 3] == 'X') and
            line[i + 4] == ']') return true;
    }
    return false;
}

test "checklist plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("checklist", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "findCheckbox" {
    try std.testing.expectEqual(@as(?usize, 3), findCheckbox("- [ ] task"));
    try std.testing.expectEqual(@as(?usize, 3), findCheckbox("- [x] done"));
    try std.testing.expectEqual(@as(?usize, null), findCheckbox("no checkbox"));
    try std.testing.expectEqual(@as(?usize, 5), findCheckbox("  - [ ] indented"));
}
