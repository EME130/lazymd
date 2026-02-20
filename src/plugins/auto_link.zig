const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Auto Link plugin — detect and convert bare URLs on current line to markdown links.
/// Finds https://... URLs and wraps them in [url](url) format.
/// Commands: :autolink, :autolink.line
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "auto-link", .version = "0.1.0", .author = "lazy-md contributors", .description = "Auto-convert URLs to links" };
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
        .{ .name = "autolink", .description = "Convert URLs on current line to links", .handler = &linkCurrentLine },
    };
}

fn linkCurrentLine(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const line = editor.buffer.getLine(editor.cursor_row);

    // Find "http://" or "https://" not already inside []() or <>
    const prefixes = [_][]const u8{ "https://", "http://" };
    for (prefixes) |prefix| {
        if (std.mem.indexOf(u8, line, prefix)) |url_start| {
            // Check if already a markdown link (preceded by '(' or '<')
            if (url_start > 0 and (line[url_start - 1] == '(' or line[url_start - 1] == '<')) continue;

            // Find end of URL (space, ), ], or end of line)
            var url_end = url_start + prefix.len;
            while (url_end < line.len) : (url_end += 1) {
                const c = line[url_end];
                if (c == ' ' or c == ')' or c == ']' or c == '>' or c == '\t') break;
            }

            const url = line[url_start..url_end];
            // Build markdown link: [url](url)
            var buf: [512]u8 = undefined;
            const link = std.fmt.bufPrint(&buf, "[{s}]({s})", .{ url, url }) catch {
                editor.status.set("URL too long", true);
                return;
            };

            // Replace in buffer
            const offset = editor.buffer.posToOffset(editor.cursor_row, url_start);
            editor.buffer.deleteRange(offset, url.len) catch return;
            editor.buffer.insertSlice(offset, link) catch return;

            var msg_buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&msg_buf, "Linked: {s}", .{url[0..@min(url.len, 50)]}) catch "URL linked";
            editor.status.set(msg, false);
            return;
        }
    }

    editor.status.set("No bare URLs found on current line", false);
}

test "auto_link plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("auto-link", p.pluginInfo().name);
}
