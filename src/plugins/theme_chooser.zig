const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const themes = @import("../themes.zig");
const Self = @This();

/// Theme Chooser plugin — browse and switch color themes interactively.
/// Commands: :theme.chooser, :theme.preview, :theme.info
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "theme-chooser", .version = "0.1.0", .author = "lazy-md contributors", .description = "Interactive theme browser and chooser" };
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
        .{ .name = "theme.chooser", .description = "Browse themes interactively", .handler = &browseThemes },
        .{ .name = "theme.preview", .description = "Preview next theme", .handler = &previewNext },
        .{ .name = "theme.info", .description = "Show current theme details", .handler = &showInfo },
    };
}

fn browseThemes(event: *plugin.PluginEvent) void {
    // List all themes with current marker
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    for (themes.builtin_themes, 0..) |t, i| {
        const marker: []const u8 = if (i == themes.current_theme_index) "*" else " ";
        const written = std.fmt.bufPrint(buf[pos..], "{s}{s} ", .{ marker, t.name }) catch break;
        pos += written.len;
    }
    event.editor.status.set(buf[0..pos], false);
}

fn previewNext(event: *plugin.PluginEvent) void {
    themes.cycleTheme();
    const t = themes.currentTheme();
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Preview: {s} — {s}", .{ t.name, t.description }) catch "Preview changed";
    event.editor.status.set(msg, false);
}

fn showInfo(event: *plugin.PluginEvent) void {
    const t = themes.currentTheme();
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Theme {d}/{d}: {s} — {s}", .{ themes.current_theme_index + 1, themes.theme_count, t.name, t.description }) catch "Info error";
    event.editor.status.set(msg, false);
}

test "theme_chooser plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("theme-chooser", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
