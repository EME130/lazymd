const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Command Palette plugin — list all available commands.
/// Shows all registered plugin commands and built-in commands.
/// Commands: :palette, :commands, :help
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "command-palette", .version = "0.1.0", .author = "lazy-md contributors", .description = "Fuzzy command palette" };
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
        .{ .name = "palette", .description = "List available commands", .handler = &openPalette },
        .{ .name = "commands", .description = "List all commands", .handler = &openPalette },
        .{ .name = "help", .description = "Show help", .handler = &showHelp },
    };
}

fn openPalette(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const query = event.command_args;

    if (editor.plugin_mgr) |pm| {
        var buf: [256]u8 = undefined;
        var pos: usize = 0;
        const prefix = "Commands: ";
        @memcpy(buf[0..prefix.len], prefix);
        pos = prefix.len;

        var iter = pm.command_map.iterator();
        while (iter.next()) |entry| {
            const name = entry.key_ptr.*;
            // Filter by query if provided
            if (query) |q| {
                if (!containsIgnoreCase(name, q)) continue;
            }
            if (pos + name.len + 2 < buf.len) {
                buf[pos] = ':';
                pos += 1;
                @memcpy(buf[pos .. pos + name.len], name);
                pos += name.len;
                buf[pos] = ' ';
                pos += 1;
            }
        }
        editor.status.set(buf[0..pos], false);
    } else {
        editor.status.set("Built-in: :q :w :wq :e :theme :theme.cycle :theme.list", false);
    }
}

fn showHelp(event: *plugin.PluginEvent) void {
    event.editor.status.set("lazy-md: :w save | :q quit | :wq save+quit | :e open | :palette commands | :theme themes", false);
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    for (0..haystack.len - needle.len + 1) |i| {
        var match = true;
        for (0..needle.len) |j| {
            const h = if (haystack[i + j] >= 'A' and haystack[i + j] <= 'Z') haystack[i + j] + 32 else haystack[i + j];
            const n = if (needle[j] >= 'A' and needle[j] <= 'Z') needle[j] + 32 else needle[j];
            if (h != n) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

test "command_palette plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("command-palette", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
