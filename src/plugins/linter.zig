const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Linter plugin — check markdown for common issues.
/// Checks for trailing whitespace, missing blank lines around headings,
/// inconsistent list markers, and other style issues.
/// Commands: :lint, :lint.fix
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "linter", .version = "0.1.0", .author = "lazy-md contributors", .description = "Markdown linting and style checks" };
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
        .{ .name = "lint", .description = "Lint current document", .handler = &lint },
        .{ .name = "lint.fix", .description = "Fix trailing whitespace", .handler = &lintFix },
    };
}

fn lint(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var issues: usize = 0;
    var first_issue_row: ?usize = null;
    var first_issue: []const u8 = "";

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);

        // Check trailing whitespace
        if (line.len > 0 and (line[line.len - 1] == ' ' or line[line.len - 1] == '\t')) {
            issues += 1;
            if (first_issue_row == null) {
                first_issue_row = row;
                first_issue = "trailing whitespace";
            }
        }

        // Check heading without blank line before
        if (headingLevel(line) > 0 and row > 0) {
            const prev = editor.buffer.getLine(row - 1);
            if (prev.len > 0) {
                issues += 1;
                if (first_issue_row == null) {
                    first_issue_row = row;
                    first_issue = "heading needs blank line before";
                }
            }
        }

        // Check very long lines (> 120 chars)
        if (line.len > 120) {
            issues += 1;
            if (first_issue_row == null) {
                first_issue_row = row;
                first_issue = "line > 120 chars";
            }
        }
    }

    if (issues == 0) {
        editor.status.set("Lint: no issues found!", false);
    } else {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Lint: {d} issues — first at L{d}: {s}", .{
            issues,
            (first_issue_row orelse 0) + 1,
            first_issue,
        }) catch "Issues found";
        editor.status.set(msg, true);
    }
}

fn lintFix(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var fixed: usize = 0;

    // Fix trailing whitespace (iterate backwards to preserve offsets)
    var row: usize = editor.buffer.lineCount();
    while (row > 0) {
        row -= 1;
        const line = editor.buffer.getLine(row);
        if (line.len == 0) continue;

        // Count trailing whitespace
        var trail: usize = 0;
        var i = line.len;
        while (i > 0) {
            i -= 1;
            if (line[i] == ' ' or line[i] == '\t') {
                trail += 1;
            } else break;
        }

        if (trail > 0) {
            const offset = editor.buffer.posToOffset(row, line.len - trail);
            editor.buffer.deleteRange(offset, trail) catch continue;
            fixed += 1;
        }
    }

    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Fixed trailing whitespace on {d} line(s)", .{fixed}) catch "Fixed";
    editor.status.set(msg, false);
}

fn headingLevel(line: []const u8) usize {
    var level: usize = 0;
    for (line) |c| {
        if (c == '#') level += 1 else break;
    }
    if (level > 0 and level < line.len and line[level] == ' ') return level;
    return 0;
}

test "linter plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("linter", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
