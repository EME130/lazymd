const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Frontmatter plugin — YAML frontmatter parsing and display.
/// Parses --- delimited frontmatter and shows key-value pairs.
/// Commands: :fm, :fm.add, :fm.edit
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "frontmatter", .version = "0.1.0", .author = "lazy-md contributors", .description = "YAML frontmatter management" };
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
        .{ .name = "fm", .description = "Show frontmatter", .handler = &showFm },
        .{ .name = "fm.add", .description = "Add frontmatter field", .handler = &addField },
        .{ .name = "fm.edit", .description = "Edit frontmatter", .handler = &editFm },
    };
}

fn showFm(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    // Check if first line is "---"
    if (editor.buffer.lineCount() == 0) {
        editor.status.set("No frontmatter found", false);
        return;
    }
    const first = editor.buffer.getLine(0);
    if (!std.mem.eql(u8, std.mem.trimRight(u8, first, " \t\r"), "---")) {
        editor.status.set("No frontmatter (file doesn't start with ---)", false);
        return;
    }

    // Find closing ---
    var end_row: ?usize = null;
    var field_count: usize = 0;
    for (1..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        const trimmed = std.mem.trimRight(u8, line, " \t\r");
        if (std.mem.eql(u8, trimmed, "---")) {
            end_row = row;
            break;
        }
        if (line.len > 0 and line[0] != '#') field_count += 1;
    }

    var buf: [256]u8 = undefined;
    if (end_row) |er| {
        // Show summary of frontmatter fields
        var pos: usize = 0;
        const prefix = std.fmt.bufPrint(buf[pos..], "Frontmatter ({d} fields, lines 1-{d}): ", .{ field_count, er + 1 }) catch {
            editor.status.set("Frontmatter found", false);
            return;
        };
        pos += prefix.len;

        // Show first few key names
        for (1..er) |row| {
            const line = editor.buffer.getLine(row);
            if (std.mem.indexOfScalar(u8, line, ':')) |colon| {
                const key = std.mem.trimRight(u8, line[0..colon], " ");
                if (pos + key.len + 2 < buf.len) {
                    @memcpy(buf[pos .. pos + key.len], key);
                    pos += key.len;
                    buf[pos] = ' ';
                    pos += 1;
                }
            }
        }
        editor.status.set(buf[0..pos], false);
    } else {
        editor.status.set("Frontmatter: unclosed (missing closing ---)", true);
    }
}

fn addField(event: *plugin.PluginEvent) void {
    const args = event.command_args orelse {
        event.editor.status.set("Usage: :fm.add <key> <value>", true);
        return;
    };
    const editor = event.editor;

    // Parse key value
    const space_idx = std.mem.indexOfScalar(u8, args, ' ') orelse {
        event.editor.status.set("Usage: :fm.add <key> <value>", true);
        return;
    };
    const key = args[0..space_idx];
    const value = args[space_idx + 1 ..];

    // Check if frontmatter exists
    if (editor.buffer.lineCount() == 0 or
        !std.mem.eql(u8, std.mem.trimRight(u8, editor.buffer.getLine(0), " \t\r"), "---"))
    {
        // Create frontmatter block
        var line_buf: [256]u8 = undefined;
        const new_line = std.fmt.bufPrint(&line_buf, "---\n{s}: {s}\n---\n", .{ key, value }) catch {
            editor.status.set("Field too long", true);
            return;
        };
        editor.buffer.insertSlice(0, new_line) catch {
            editor.status.set("Failed to add frontmatter", true);
            return;
        };
        editor.status.set("Frontmatter created", false);
        return;
    }

    // Find closing --- and insert before it
    for (1..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (std.mem.eql(u8, std.mem.trimRight(u8, line, " \t\r"), "---")) {
            var line_buf: [256]u8 = undefined;
            const new_field = std.fmt.bufPrint(&line_buf, "{s}: {s}\n", .{ key, value }) catch {
                editor.status.set("Field too long", true);
                return;
            };
            const offset = editor.buffer.posToOffset(row, 0);
            editor.buffer.insertSlice(offset, new_field) catch {
                editor.status.set("Failed to add field", true);
                return;
            };
            var msg_buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&msg_buf, "Added: {s}: {s}", .{ key, value }) catch "Field added";
            editor.status.set(msg, false);
            return;
        }
    }
    editor.status.set("Unclosed frontmatter", true);
}

fn editFm(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    // Jump cursor to frontmatter area (line 1)
    if (editor.buffer.lineCount() > 0 and
        std.mem.eql(u8, std.mem.trimRight(u8, editor.buffer.getLine(0), " \t\r"), "---"))
    {
        editor.cursor_row = 1;
        editor.cursor_col = 0;
        editor.status.set("Editing frontmatter — navigate with j/k, edit with i", false);
    } else {
        editor.status.set("No frontmatter to edit", true);
    }
}

test "frontmatter plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("frontmatter", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
