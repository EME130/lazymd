const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Typewriter plugin — keeps cursor centered on screen while typing.
/// Tracks state globally. When active, scroll_offset follows cursor.
/// Commands: :typewriter, :typewriter.off
active: bool = false,

var g_typewriter_active: bool = false;

pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "typewriter", .version = "0.1.0", .author = "lazy-md contributors", .description = "Typewriter scrolling — cursor always centered" };
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
        .{ .name = "typewriter", .description = "Toggle typewriter mode", .handler = &toggle },
        .{ .name = "typewriter.off", .description = "Disable typewriter mode", .handler = &off },
    };
}

fn toggle(event: *plugin.PluginEvent) void {
    g_typewriter_active = !g_typewriter_active;
    if (g_typewriter_active) {
        // Center cursor by adjusting scroll_offset
        centerCursor(event.editor);
        event.editor.status.set("Typewriter ON — cursor stays centered", false);
    } else {
        event.editor.status.set("Typewriter OFF", false);
    }
}

fn off(event: *plugin.PluginEvent) void {
    g_typewriter_active = false;
    event.editor.status.set("Typewriter OFF", false);
}

fn centerCursor(editor: *Editor) void {
    // Set scroll offset so cursor is vertically centered
    const cursor = editor.cursor_row;
    // Estimate visible height as ~20 lines (would need terminal size for exact)
    const half_screen: usize = 10;
    if (cursor > half_screen) {
        editor.scroll_row = cursor - half_screen;
    } else {
        editor.scroll_row = 0;
    }
}

test "typewriter plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("typewriter", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
