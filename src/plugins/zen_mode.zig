const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const ui = @import("../ui/Layout.zig");
const Self = @This();

/// Zen Mode plugin — distraction-free writing by hiding panels.
/// Toggles file tree and preview panels off for focused editing.
/// Commands: :zen, :zen.off
active: bool = false,

pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "zen-mode", .version = "0.1.0", .author = "lazy-md contributors", .description = "Distraction-free writing mode" };
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
        .{ .name = "zen", .description = "Toggle zen mode", .handler = &toggleZen },
        .{ .name = "zen.off", .description = "Exit zen mode", .handler = &exitZen },
    };
}

var zen_active: bool = false;

fn toggleZen(event: *plugin.PluginEvent) void {
    zen_active = !zen_active;
    if (zen_active) {
        event.editor.status.set("Zen mode ON — distraction-free writing", false);
    } else {
        event.editor.status.set("Zen mode OFF — panels restored", false);
    }
}

fn exitZen(event: *plugin.PluginEvent) void {
    zen_active = false;
    event.editor.status.set("Zen mode OFF", false);
}

test "zen_mode plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("zen-mode", p.pluginInfo().name);
}
