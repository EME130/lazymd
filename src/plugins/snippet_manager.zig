const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Snippet Manager plugin — built-in text snippets with shortcodes.
/// Insert common markdown patterns quickly.
/// Commands: :snip, :snip.list
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "snippet-manager", .version = "0.1.0", .author = "lazy-md contributors", .description = "Reusable text snippets" };
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
        .{ .name = "snip", .description = "Insert snippet by name", .handler = &insertSnippet },
        .{ .name = "snip.list", .description = "List all snippets", .handler = &listSnippets },
    };
}

const SnippetEntry = struct { name: []const u8, content: []const u8 };

const snippets = [_]SnippetEntry{
    .{ .name = "code", .content = "```\n\n```\n" },
    .{ .name = "codezig", .content = "```zig\n\n```\n" },
    .{ .name = "codepy", .content = "```python\n\n```\n" },
    .{ .name = "codejs", .content = "```javascript\n\n```\n" },
    .{ .name = "link", .content = "[text](url)" },
    .{ .name = "img", .content = "![alt](url)" },
    .{ .name = "task", .content = "- [ ] " },
    .{ .name = "table2", .content = "| Col 1 | Col 2 |\n| --- | --- |\n|  |  |\n" },
    .{ .name = "table3", .content = "| Col 1 | Col 2 | Col 3 |\n| --- | --- | --- |\n|  |  |  |\n" },
    .{ .name = "details", .content = "<details>\n<summary>Click to expand</summary>\n\n</details>\n" },
    .{ .name = "note", .content = "> **Note**\n> \n" },
    .{ .name = "warn", .content = "> **Warning**\n> \n" },
    .{ .name = "tip", .content = "> **Tip**\n> \n" },
    .{ .name = "hr", .content = "\n---\n\n" },
    .{ .name = "toc", .content = "## Table of Contents\n\n" },
    .{ .name = "fm", .content = "---\ntitle: \"\"\ndate: \ntags: []\n---\n\n" },
};

fn insertSnippet(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const name = event.command_args orelse {
        editor.status.set("Usage: :snip <name> (use :snip.list to see all)", true);
        return;
    };

    for (snippets) |s| {
        if (std.mem.eql(u8, s.name, name)) {
            const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
            editor.buffer.insertSlice(offset, s.content) catch {
                editor.status.set("Failed to insert snippet", true);
                return;
            };
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Snippet '{s}' inserted", .{name}) catch "Inserted";
            editor.status.set(msg, false);
            return;
        }
    }

    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    const prefix = std.fmt.bufPrint(buf[0..], "Unknown snippet '{s}'. Available: ", .{name}) catch "Unknown";
    pos = prefix.len;
    for (snippets) |s| {
        if (pos + s.name.len + 1 < buf.len) {
            @memcpy(buf[pos .. pos + s.name.len], s.name);
            pos += s.name.len;
            buf[pos] = ' ';
            pos += 1;
        }
    }
    editor.status.set(buf[0..pos], true);
}

fn listSnippets(event: *plugin.PluginEvent) void {
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    const prefix = "Snippets: ";
    @memcpy(buf[0..prefix.len], prefix);
    pos = prefix.len;

    for (snippets) |s| {
        if (pos + s.name.len + 1 < buf.len) {
            @memcpy(buf[pos .. pos + s.name.len], s.name);
            pos += s.name.len;
            buf[pos] = ' ';
            pos += 1;
        }
    }
    event.editor.status.set(buf[0..pos], false);
}

test "snippet_manager plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("snippet-manager", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
