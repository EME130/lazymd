const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Emoji plugin — insert emoji by shortcode.
/// Common emoji are built-in. Use :emoji <shortcode> to insert.
/// Commands: :emoji, :emoji.search
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "emoji", .version = "0.1.0", .author = "lazy-md contributors", .description = "Emoji shortcode insertion" };
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
        .{ .name = "emoji", .description = "Insert emoji by shortcode", .handler = &insertEmoji },
        .{ .name = "emoji.list", .description = "List available emoji", .handler = &listEmoji },
    };
}

const EmojiEntry = struct { code: []const u8, emoji: []const u8 };

const emoji_table = [_]EmojiEntry{
    .{ .code = "smile", .emoji = "\xF0\x9F\x98\x8A" },
    .{ .code = "heart", .emoji = "\xE2\x9D\xA4" },
    .{ .code = "thumbsup", .emoji = "\xF0\x9F\x91\x8D" },
    .{ .code = "thumbsdown", .emoji = "\xF0\x9F\x91\x8E" },
    .{ .code = "fire", .emoji = "\xF0\x9F\x94\xA5" },
    .{ .code = "star", .emoji = "\xE2\xAD\x90" },
    .{ .code = "check", .emoji = "\xE2\x9C\x85" },
    .{ .code = "x", .emoji = "\xE2\x9D\x8C" },
    .{ .code = "warning", .emoji = "\xE2\x9A\xA0" },
    .{ .code = "info", .emoji = "\xE2\x84\xB9" },
    .{ .code = "rocket", .emoji = "\xF0\x9F\x9A\x80" },
    .{ .code = "bug", .emoji = "\xF0\x9F\x90\x9B" },
    .{ .code = "idea", .emoji = "\xF0\x9F\x92\xA1" },
    .{ .code = "question", .emoji = "\xE2\x9D\x93" },
    .{ .code = "exclamation", .emoji = "\xE2\x9D\x97" },
    .{ .code = "pin", .emoji = "\xF0\x9F\x93\x8C" },
    .{ .code = "link", .emoji = "\xF0\x9F\x94\x97" },
    .{ .code = "book", .emoji = "\xF0\x9F\x93\x96" },
    .{ .code = "memo", .emoji = "\xF0\x9F\x93\x9D" },
    .{ .code = "calendar", .emoji = "\xF0\x9F\x93\x85" },
    .{ .code = "clock", .emoji = "\xF0\x9F\x95\x90" },
    .{ .code = "folder", .emoji = "\xF0\x9F\x93\x81" },
    .{ .code = "tag", .emoji = "\xF0\x9F\x8F\xB7" },
    .{ .code = "tada", .emoji = "\xF0\x9F\x8E\x89" },
    .{ .code = "wave", .emoji = "\xF0\x9F\x91\x8B" },
    .{ .code = "eyes", .emoji = "\xF0\x9F\x91\x80" },
    .{ .code = "think", .emoji = "\xF0\x9F\xA4\x94" },
    .{ .code = "100", .emoji = "\xF0\x9F\x92\xAF" },
    .{ .code = "zap", .emoji = "\xE2\x9A\xA1" },
    .{ .code = "gear", .emoji = "\xE2\x9A\x99" },
};

fn insertEmoji(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const code = event.command_args orelse {
        editor.status.set("Usage: :emoji <shortcode> (e.g. :emoji smile)", true);
        return;
    };

    for (emoji_table) |entry| {
        if (std.mem.eql(u8, entry.code, code)) {
            const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
            editor.buffer.insertSlice(offset, entry.emoji) catch {
                editor.status.set("Failed to insert emoji", true);
                return;
            };
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Inserted :{s}:", .{code}) catch "Inserted";
            editor.status.set(msg, false);
            return;
        }
    }

    // Search for partial matches
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    const prefix = std.fmt.bufPrint(buf[0..], "Unknown :{s}: — did you mean: ", .{code}) catch {
        editor.status.set("Unknown emoji shortcode", true);
        return;
    };
    pos = prefix.len;

    var suggestions: usize = 0;
    for (emoji_table) |entry| {
        if (std.mem.indexOf(u8, entry.code, code) != null) {
            const written = std.fmt.bufPrint(buf[pos..], ":{s}: ", .{entry.code}) catch break;
            pos += written.len;
            suggestions += 1;
            if (suggestions >= 5) break;
        }
    }

    if (suggestions > 0) {
        editor.status.set(buf[0..pos], true);
    } else {
        editor.status.set("Unknown emoji. Use :emoji.list to see all", true);
    }
}

fn listEmoji(event: *plugin.PluginEvent) void {
    var buf: [256]u8 = undefined;
    var pos: usize = 0;
    for (emoji_table) |entry| {
        const written = std.fmt.bufPrint(buf[pos..], ":{s}: ", .{entry.code}) catch break;
        pos += written.len;
    }
    event.editor.status.set(buf[0..pos], false);
}

test "emoji plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("emoji", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
