const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Quick Switcher plugin — open files by partial name match.
/// Scans directory for .md/.rndm files matching the query.
/// Commands: :open, :switcher
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "quick-switcher", .version = "0.1.0", .author = "lazy-md contributors", .description = "Fuzzy file switcher" };
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
        .{ .name = "open", .description = "Open file by name (fuzzy match)", .handler = &openFile },
        .{ .name = "switcher", .description = "List matching files", .handler = &openFile },
    };
}

fn openFile(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const query = event.command_args orelse {
        // List all markdown files
        listFiles(editor);
        return;
    };

    // First try exact match
    editor.openFile(query) catch {
        // Try with .md extension
        var path_buf: [128]u8 = undefined;
        const with_md = std.fmt.bufPrint(&path_buf, "{s}.md", .{query}) catch {
            editor.status.set("Filename too long", true);
            return;
        };

        editor.openFile(with_md) catch {
            // Fuzzy match: scan directory
            var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
                editor.status.set("Cannot scan directory", true);
                return;
            };
            defer dir.close();

            var best_match: [256]u8 = undefined;
            var best_len: usize = 0;
            var match_count: usize = 0;

            var iter = dir.iterate();
            while (iter.next() catch null) |entry| {
                if (entry.kind != .file) continue;
                if (!std.mem.endsWith(u8, entry.name, ".md") and
                    !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

                // Case-insensitive substring match
                if (containsIgnoreCase(entry.name, query)) {
                    match_count += 1;
                    if (match_count == 1 and entry.name.len <= best_match.len) {
                        @memcpy(best_match[0..entry.name.len], entry.name);
                        best_len = entry.name.len;
                    }
                }
            }

            if (match_count == 1 and best_len > 0) {
                editor.openFile(best_match[0..best_len]) catch {
                    editor.status.set("Failed to open file", true);
                    return;
                };
            } else if (match_count > 1) {
                var buf: [128]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "{d} matches for '{s}' — be more specific", .{ match_count, query }) catch "Multiple matches";
                editor.status.set(msg, false);
            } else {
                var buf: [128]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "No files matching '{s}'", .{query}) catch "Not found";
                editor.status.set(msg, true);
            }
        };
    };
}

fn listFiles(editor: *Editor) void {
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan directory", true);
        return;
    };
    defer dir.close();

    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    var count: usize = 0;

    const prefix = "Files: ";
    @memcpy(buf[0..prefix.len], prefix);
    pos = prefix.len;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and
            !std.mem.endsWith(u8, entry.name, ".rndm")) continue;
        count += 1;
        if (pos + entry.name.len + 1 < buf.len) {
            @memcpy(buf[pos .. pos + entry.name.len], entry.name);
            pos += entry.name.len;
            buf[pos] = ' ';
            pos += 1;
        }
    }

    if (count == 0) {
        editor.status.set("No markdown files found", false);
    } else {
        editor.status.set(buf[0..pos], false);
    }
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

test "quick_switcher plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("quick-switcher", p.pluginInfo().name);
}

test "containsIgnoreCase" {
    try std.testing.expect(containsIgnoreCase("README.md", "readme"));
    try std.testing.expect(containsIgnoreCase("MyNotes.md", "note"));
    try std.testing.expect(!containsIgnoreCase("hello.md", "xyz"));
}
