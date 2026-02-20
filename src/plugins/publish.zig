const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Publish plugin — publish notes as a static website.
/// Generates HTML files from vault's markdown notes.
/// Commands: :publish, :publish.build, :publish.preview
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "publish", .version = "0.1.0", .author = "lazy-md contributors", .description = "Publish notes as static site" };
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
        .{ .name = "publish", .description = "Publish current note to HTML", .handler = &publishNote },
        .{ .name = "publish.build", .description = "Build entire vault as static site", .handler = &buildSite },
        .{ .name = "publish.preview", .description = "Generate preview HTML", .handler = &preview },
    };
}

fn writeHtmlHeader(file: std.fs.File, title: []const u8) void {
    var buf: [512]u8 = undefined;
    const header = std.fmt.bufPrint(&buf,
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\<meta charset="UTF-8">
        \\<meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\<title>{s}</title>
        \\<style>
        \\body {{ font-family: -apple-system, sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; color: #333; }}
        \\h1,h2,h3 {{ color: #1a1a1a; }}
        \\code {{ background: #f4f4f4; padding: 0.2em 0.4em; border-radius: 3px; }}
        \\pre {{ background: #f4f4f4; padding: 1em; overflow-x: auto; border-radius: 6px; }}
        \\blockquote {{ border-left: 4px solid #ddd; margin: 0; padding-left: 1em; color: #666; }}
        \\a {{ color: #0066cc; }}
        \\</style>
        \\</head>
        \\<body>
        \\
    , .{title}) catch return;
    file.writeAll(header) catch {};
}

fn writeHtmlFooter(file: std.fs.File) void {
    file.writeAll("\n</body>\n</html>\n") catch {};
}

fn convertLine(file: std.fs.File, line: []const u8) void {
    // Trim trailing whitespace
    var end = line.len;
    while (end > 0 and (line[end - 1] == '\n' or line[end - 1] == '\r' or line[end - 1] == ' ')) : (end -= 1) {}
    const trimmed = line[0..end];

    if (trimmed.len == 0) {
        file.writeAll("<br>\n") catch {};
        return;
    }

    // Headings
    if (std.mem.startsWith(u8, trimmed, "### ")) {
        file.writeAll("<h3>") catch {};
        writeEscaped(file, trimmed[4..]);
        file.writeAll("</h3>\n") catch {};
    } else if (std.mem.startsWith(u8, trimmed, "## ")) {
        file.writeAll("<h2>") catch {};
        writeEscaped(file, trimmed[3..]);
        file.writeAll("</h2>\n") catch {};
    } else if (std.mem.startsWith(u8, trimmed, "# ")) {
        file.writeAll("<h1>") catch {};
        writeEscaped(file, trimmed[2..]);
        file.writeAll("</h1>\n") catch {};
    } else if (std.mem.startsWith(u8, trimmed, "> ")) {
        file.writeAll("<blockquote>") catch {};
        writeEscaped(file, trimmed[2..]);
        file.writeAll("</blockquote>\n") catch {};
    } else if (std.mem.startsWith(u8, trimmed, "- ")) {
        file.writeAll("<li>") catch {};
        writeEscaped(file, trimmed[2..]);
        file.writeAll("</li>\n") catch {};
    } else if (std.mem.startsWith(u8, trimmed, "---")) {
        file.writeAll("<hr>\n") catch {};
    } else {
        file.writeAll("<p>") catch {};
        writeEscaped(file, trimmed);
        file.writeAll("</p>\n") catch {};
    }
}

fn writeEscaped(file: std.fs.File, text: []const u8) void {
    for (text) |ch| {
        switch (ch) {
            '<' => file.writeAll("&lt;") catch {},
            '>' => file.writeAll("&gt;") catch {},
            '&' => file.writeAll("&amp;") catch {},
            '"' => file.writeAll("&quot;") catch {},
            else => file.writeAll(&[_]u8{ch}) catch {},
        }
    }
}

fn publishNote(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    std.fs.cwd().makeDir("_site") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create _site/ directory", true);
            return;
        },
    };

    const stem = blk: {
        if (editor.file_path) |fp| {
            const name = if (std.mem.lastIndexOfScalar(u8, fp, '/')) |s| fp[s + 1 ..] else fp;
            if (std.mem.lastIndexOfScalar(u8, name, '.')) |dot| break :blk name[0..dot];
            break :blk name;
        }
        break :blk "untitled";
    };

    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "_site/{s}.html", .{stem}) catch {
        editor.status.set("Path error", true);
        return;
    };

    const file = std.fs.cwd().createFile(path, .{}) catch {
        editor.status.set("Failed to create HTML file", true);
        return;
    };
    defer file.close();

    writeHtmlHeader(file, stem);

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        convertLine(file, line);
    }

    writeHtmlFooter(file);

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Published: {s}", .{path}) catch "Published";
    editor.status.set(msg, false);
}

fn buildSite(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    std.fs.cwd().makeDir("_site") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create _site/ directory", true);
            return;
        },
    };

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var published: usize = 0;
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

        const stem = blk: {
            if (std.mem.lastIndexOfScalar(u8, entry.name, '.')) |dot| break :blk entry.name[0..dot];
            break :blk entry.name;
        };

        var path_buf: [128]u8 = undefined;
        const html_path = std.fmt.bufPrint(&path_buf, "_site/{s}.html", .{stem}) catch continue;

        const source = dir.openFile(entry.name, .{}) catch continue;
        defer source.close();

        const out = std.fs.cwd().createFile(html_path, .{}) catch continue;
        defer out.close();

        writeHtmlHeader(out, stem);

        var read_buf: [4096]u8 = undefined;
        const n = source.readAll(&read_buf) catch continue;
        var lines = std.mem.splitScalar(u8, read_buf[0..n], '\n');
        while (lines.next()) |line| {
            convertLine(out, line);
        }

        writeHtmlFooter(out);
        published += 1;
    }

    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Built {d} pages in _site/", .{published}) catch "Built";
    editor.status.set(msg, false);
}

fn preview(event: *plugin.PluginEvent) void {
    // Just publish current note as preview
    publishNote(event);
}

test "publish plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("publish", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
