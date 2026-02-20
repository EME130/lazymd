const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Citations plugin — insert academic-style citations.
/// Uses [@key] format and counts references in document.
/// Commands: :cite, :cite.list, :cite.ref
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "citations", .version = "0.1.0", .author = "lazy-md contributors", .description = "Academic citations and BibTeX" };
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
        .{ .name = "cite", .description = "Insert citation [@key]", .handler = &insertCite },
        .{ .name = "cite.list", .description = "List all citations", .handler = &listCites },
        .{ .name = "cite.ref", .description = "Add reference entry", .handler = &addRef },
    };
}

fn insertCite(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const key = event.command_args orelse {
        editor.status.set("Usage: :cite <key> (e.g. :cite smith2024)", true);
        return;
    };

    var buf: [64]u8 = undefined;
    const cite = std.fmt.bufPrint(&buf, "[@{s}]", .{key}) catch {
        editor.status.set("Key too long", true);
        return;
    };

    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, cite) catch {
        editor.status.set("Failed to insert citation", true);
        return;
    };
    editor.cursor_col += cite.len;
    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Citation [@{s}] inserted", .{key}) catch "Inserted";
    editor.status.set(msg, false);
}

fn listCites(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    var count: usize = 0;

    const prefix = "Citations: ";
    @memcpy(buf[0..prefix.len], prefix);
    pos = prefix.len;

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        var i: usize = 0;
        while (i + 2 < line.len) : (i += 1) {
            if (line[i] == '[' and line[i + 1] == '@') {
                const end = std.mem.indexOfScalar(u8, line[i..], ']') orelse continue;
                const cite = line[i .. i + end + 1];
                count += 1;
                if (pos + cite.len + 1 < buf.len) {
                    @memcpy(buf[pos .. pos + cite.len], cite);
                    pos += cite.len;
                    buf[pos] = ' ';
                    pos += 1;
                }
            }
        }
    }

    if (count == 0) {
        editor.status.set("No citations found (use [@key] format)", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
}

fn addRef(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const key = event.command_args orelse {
        editor.status.set("Usage: :cite.ref <key> <author, title, year>", true);
        return;
    };

    var ref_buf: [256]u8 = undefined;
    const ref = std.fmt.bufPrint(&ref_buf, "\n[@{s}]: {s}\n", .{ key, key }) catch {
        editor.status.set("Reference too long", true);
        return;
    };

    // Add at end of document
    const end = editor.buffer.length();
    editor.buffer.insertSlice(end, ref) catch {
        editor.status.set("Failed to add reference", true);
        return;
    };
    editor.status.set("Reference added at end of document", false);
}

test "citations plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("citations", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
