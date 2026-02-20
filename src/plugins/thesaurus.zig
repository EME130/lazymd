const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Thesaurus plugin — find synonyms for common words.
/// Built-in synonym database for writing improvement.
/// Commands: :synonyms, :synonyms.replace
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "thesaurus", .version = "0.1.0", .author = "lazy-md contributors", .description = "Synonym and antonym lookup" };
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
        .{ .name = "synonyms", .description = "Find synonyms for word", .handler = &findSynonyms },
        .{ .name = "synonyms.replace", .description = "Replace word with synonym", .handler = &replaceSynonym },
    };
}

const SynEntry = struct {
    word: []const u8,
    synonyms: []const u8,
};

const thesaurus_data = [_]SynEntry{
    .{ .word = "good", .synonyms = "excellent, great, fine, superb, outstanding, wonderful" },
    .{ .word = "bad", .synonyms = "poor, terrible, awful, dreadful, inferior, subpar" },
    .{ .word = "big", .synonyms = "large, huge, enormous, vast, immense, substantial" },
    .{ .word = "small", .synonyms = "tiny, little, miniature, compact, minute, petite" },
    .{ .word = "fast", .synonyms = "quick, rapid, swift, speedy, hasty, brisk" },
    .{ .word = "slow", .synonyms = "sluggish, gradual, leisurely, unhurried, plodding" },
    .{ .word = "happy", .synonyms = "joyful, cheerful, delighted, pleased, content, elated" },
    .{ .word = "sad", .synonyms = "unhappy, sorrowful, melancholy, gloomy, dejected" },
    .{ .word = "important", .synonyms = "significant, crucial, vital, essential, critical, key" },
    .{ .word = "easy", .synonyms = "simple, straightforward, effortless, uncomplicated" },
    .{ .word = "hard", .synonyms = "difficult, challenging, tough, demanding, arduous" },
    .{ .word = "new", .synonyms = "novel, fresh, modern, recent, innovative, original" },
    .{ .word = "old", .synonyms = "ancient, aged, vintage, antique, mature, elderly" },
    .{ .word = "nice", .synonyms = "pleasant, agreeable, lovely, delightful, charming" },
    .{ .word = "interesting", .synonyms = "fascinating, engaging, compelling, intriguing, captivating" },
    .{ .word = "beautiful", .synonyms = "gorgeous, stunning, elegant, attractive, lovely" },
    .{ .word = "smart", .synonyms = "intelligent, clever, brilliant, sharp, astute, wise" },
    .{ .word = "strong", .synonyms = "powerful, robust, sturdy, formidable, resilient" },
    .{ .word = "make", .synonyms = "create, build, construct, produce, generate, craft" },
    .{ .word = "get", .synonyms = "obtain, acquire, receive, gain, fetch, retrieve" },
    .{ .word = "use", .synonyms = "utilize, employ, apply, leverage, operate, wield" },
    .{ .word = "show", .synonyms = "display, demonstrate, reveal, exhibit, present, illustrate" },
    .{ .word = "help", .synonyms = "assist, aid, support, facilitate, enable, guide" },
    .{ .word = "change", .synonyms = "modify, alter, adjust, transform, revise, update" },
    .{ .word = "think", .synonyms = "consider, ponder, reflect, contemplate, deliberate" },
    .{ .word = "very", .synonyms = "extremely, highly, incredibly, remarkably, exceptionally" },
    .{ .word = "also", .synonyms = "additionally, furthermore, moreover, likewise, too" },
    .{ .word = "however", .synonyms = "nevertheless, nonetheless, yet, still, though" },
    .{ .word = "because", .synonyms = "since, as, due to, owing to, given that" },
    .{ .word = "but", .synonyms = "however, yet, although, nevertheless, though" },
};

fn findSynonyms(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const word = event.command_args orelse {
        // Get word under cursor
        const line = editor.buffer.getLine(editor.cursor_row);
        const col = @min(editor.cursor_col, if (line.len > 0) line.len - 1 else 0);
        var start = col;
        while (start > 0 and std.ascii.isAlphabetic(line[start - 1])) : (start -= 1) {}
        var end = col;
        while (end < line.len and std.ascii.isAlphabetic(line[end])) : (end += 1) {}
        if (start == end) {
            editor.status.set("Usage: :synonyms <word>", true);
            return;
        }
        lookupSynonyms(editor, line[start..end]);
        return;
    };
    lookupSynonyms(editor, word);
}

fn lookupSynonyms(editor: *Editor, word: []const u8) void {
    for (&thesaurus_data) |*entry| {
        if (std.ascii.eqlIgnoreCase(entry.word, word)) {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{s} -> {s}", .{ entry.word, entry.synonyms }) catch "Found";
            editor.status.set(msg, false);
            return;
        }
    }
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "No synonyms for '{s}' (30 common words available)", .{word}) catch "Not found";
    editor.status.set(msg, false);
}

fn replaceSynonym(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const replacement = event.command_args orelse {
        editor.status.set("Usage: :synonyms.replace <new-word>", true);
        return;
    };

    // Replace word under cursor with the given synonym
    const line = editor.buffer.getLine(editor.cursor_row);
    const col = @min(editor.cursor_col, if (line.len > 0) line.len - 1 else 0);
    var start = col;
    while (start > 0 and std.ascii.isAlphabetic(line[start - 1])) : (start -= 1) {}
    var end = col;
    while (end < line.len and std.ascii.isAlphabetic(line[end])) : (end += 1) {}

    if (start == end) {
        editor.status.set("No word under cursor", true);
        return;
    }

    const offset_start = editor.buffer.posToOffset(editor.cursor_row, start);
    const offset_end = editor.buffer.posToOffset(editor.cursor_row, end);
    editor.buffer.deleteRange(offset_start, offset_end) catch {
        editor.status.set("Replace failed", true);
        return;
    };
    editor.buffer.insertSlice(offset_start, replacement) catch {
        editor.status.set("Insert failed", true);
        return;
    };

    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Replaced with: {s}", .{replacement}) catch "Replaced";
    editor.status.set(msg, false);
}

test "thesaurus plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("thesaurus", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
