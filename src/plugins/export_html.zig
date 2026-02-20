const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Export HTML plugin — export current markdown to standalone HTML.
/// Generates a self-contained HTML file with basic styling.
/// Commands: :export.html
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "export-html", .version = "0.1.0", .author = "lazy-md contributors", .description = "Export to HTML" };
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
        .{ .name = "export.html", .description = "Export to HTML file", .handler = &exportHtml },
    };
}

fn exportHtml(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Determine output filename
    var out_path_buf: [128]u8 = undefined;
    const out_path = blk: {
        if (editor.file_path) |fp| {
            if (std.mem.lastIndexOfScalar(u8, fp, '.')) |dot| {
                break :blk std.fmt.bufPrint(&out_path_buf, "{s}.html", .{fp[0..dot]}) catch "export.html";
            }
        }
        break :blk @as([]const u8, "export.html");
    };

    const file = std.fs.cwd().createFile(out_path, .{}) catch {
        editor.status.set("Failed to create HTML file", true);
        return;
    };
    defer file.close();

    // Write HTML header
    const header =
        \\<!DOCTYPE html>
        \\<html><head><meta charset="utf-8">
        \\<title>Export</title>
        \\<style>
        \\body{font-family:system-ui,sans-serif;max-width:800px;margin:40px auto;padding:0 20px;line-height:1.6;color:#333}
        \\h1{border-bottom:2px solid #333}h2{border-bottom:1px solid #999}
        \\code{background:#f4f4f4;padding:2px 6px;border-radius:3px}
        \\pre{background:#f4f4f4;padding:16px;border-radius:6px;overflow-x:auto}
        \\blockquote{border-left:4px solid #ddd;margin:0;padding:0 16px;color:#666}
        \\table{border-collapse:collapse}td,th{border:1px solid #ddd;padding:8px}
        \\</style></head><body>
        \\
    ;
    file.writeAll(header) catch {
        editor.status.set("Write error", true);
        return;
    };

    // Convert markdown lines to basic HTML
    var in_code_block = false;
    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);

        if (line.len >= 3 and std.mem.startsWith(u8, std.mem.trimLeft(u8, line, " "), "```")) {
            if (in_code_block) {
                file.writeAll("</code></pre>\n") catch return;
                in_code_block = false;
            } else {
                file.writeAll("<pre><code>") catch return;
                in_code_block = true;
            }
            continue;
        }

        if (in_code_block) {
            writeEscaped(file, line);
            file.writeAll("\n") catch return;
            continue;
        }

        // Headings
        const heading = headingLevel(line);
        if (heading > 0 and heading < line.len) {
            var h_buf: [8]u8 = undefined;
            const open = std.fmt.bufPrint(&h_buf, "<h{d}>", .{heading}) catch continue;
            file.writeAll(open) catch return;
            file.writeAll(std.mem.trimLeft(u8, line[heading..], " ")) catch return;
            var close_buf: [8]u8 = undefined;
            const close = std.fmt.bufPrint(&close_buf, "</h{d}>\n", .{heading}) catch continue;
            file.writeAll(close) catch return;
            continue;
        }

        // Blockquote
        if (line.len > 0 and line[0] == '>') {
            file.writeAll("<blockquote>") catch return;
            file.writeAll(if (line.len > 2) line[2..] else "") catch return;
            file.writeAll("</blockquote>\n") catch return;
            continue;
        }

        // Empty line = paragraph break
        if (line.len == 0) {
            file.writeAll("<br>\n") catch return;
            continue;
        }

        // Regular paragraph
        file.writeAll("<p>") catch return;
        file.writeAll(line) catch return;
        file.writeAll("</p>\n") catch return;
    }

    if (in_code_block) {
        file.writeAll("</code></pre>\n") catch {};
    }

    file.writeAll("</body></html>\n") catch {};

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Exported to {s}", .{out_path}) catch "Exported";
    editor.status.set(msg, false);
}

fn writeEscaped(file: std.fs.File, text: []const u8) void {
    for (text) |c| {
        switch (c) {
            '<' => file.writeAll("&lt;") catch return,
            '>' => file.writeAll("&gt;") catch return,
            '&' => file.writeAll("&amp;") catch return,
            else => file.writeAll(&[1]u8{c}) catch return,
        }
    }
}

fn headingLevel(line: []const u8) usize {
    var level: usize = 0;
    for (line) |c| {
        if (c == '#') level += 1 else break;
    }
    if (level > 0 and level < line.len and line[level] == ' ') return level;
    return 0;
}

test "export_html plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("export-html", p.pluginInfo().name);
}
