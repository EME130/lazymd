const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Admonitions plugin — insert Obsidian-style callout blocks.
/// Uses > [!type] format for callouts.
/// Commands: :callout, :callout.tip, :callout.warn, :callout.note, :callout.danger
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "admonitions", .version = "0.1.0", .author = "lazy-md contributors", .description = "Callout blocks (tip, warning, note)" };
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
        .{ .name = "callout", .description = "Insert callout by type", .handler = &insertCallout },
        .{ .name = "callout.tip", .description = "Insert tip callout", .handler = &insertTip },
        .{ .name = "callout.warn", .description = "Insert warning callout", .handler = &insertWarn },
        .{ .name = "callout.note", .description = "Insert note callout", .handler = &insertNote },
    };
}

fn insertCalloutBlock(editor: *Editor, callout_type: []const u8) void {
    var buf: [128]u8 = undefined;
    const block = std.fmt.bufPrint(&buf, "\n> [!{s}]\n> \n", .{callout_type}) catch {
        editor.status.set("Callout error", true);
        return;
    };
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, block) catch {
        editor.status.set("Failed to insert callout", true);
        return;
    };
    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "[!{s}] callout inserted", .{callout_type}) catch "Inserted";
    editor.status.set(msg, false);
}

fn insertCallout(event: *plugin.PluginEvent) void {
    const callout_type = event.command_args orelse {
        event.editor.status.set("Usage: :callout <tip|warn|note|danger|info|example>", true);
        return;
    };
    insertCalloutBlock(event.editor, callout_type);
}
fn insertTip(event: *plugin.PluginEvent) void {
    insertCalloutBlock(event.editor, "tip");
}
fn insertWarn(event: *plugin.PluginEvent) void {
    insertCalloutBlock(event.editor, "warning");
}
fn insertNote(event: *plugin.PluginEvent) void {
    insertCalloutBlock(event.editor, "note");
}

test "admonitions plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("admonitions", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 4), cmds.len);
}
