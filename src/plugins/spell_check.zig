const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Spell Check plugin — basic built-in spell checking.
/// Uses a list of common misspellings to flag issues.
/// Commands: :spell, :spell.add, :spell.check
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "spell-check", .version = "0.1.0", .author = "lazy-md contributors", .description = "Spell checking for documents" };
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
        .{ .name = "spell", .description = "Check current line for misspellings", .handler = &spellCheck },
        .{ .name = "spell.all", .description = "Check entire document", .handler = &spellAll },
        .{ .name = "spell.fix", .description = "Fix common misspellings on line", .handler = &spellFix },
    };
}

const Misspelling = struct {
    wrong: []const u8,
    right: []const u8,
};

const common_misspellings = [_]Misspelling{
    .{ .wrong = "teh", .right = "the" },
    .{ .wrong = "recieve", .right = "receive" },
    .{ .wrong = "occured", .right = "occurred" },
    .{ .wrong = "seperate", .right = "separate" },
    .{ .wrong = "definately", .right = "definitely" },
    .{ .wrong = "occurance", .right = "occurrence" },
    .{ .wrong = "neccessary", .right = "necessary" },
    .{ .wrong = "accomodate", .right = "accommodate" },
    .{ .wrong = "apparantly", .right = "apparently" },
    .{ .wrong = "calender", .right = "calendar" },
    .{ .wrong = "collegue", .right = "colleague" },
    .{ .wrong = "commitee", .right = "committee" },
    .{ .wrong = "concensus", .right = "consensus" },
    .{ .wrong = "defintion", .right = "definition" },
    .{ .wrong = "enviroment", .right = "environment" },
    .{ .wrong = "existance", .right = "existence" },
    .{ .wrong = "foriegn", .right = "foreign" },
    .{ .wrong = "goverment", .right = "government" },
    .{ .wrong = "harrass", .right = "harass" },
    .{ .wrong = "immediatly", .right = "immediately" },
    .{ .wrong = "independant", .right = "independent" },
    .{ .wrong = "knowlege", .right = "knowledge" },
    .{ .wrong = "millenium", .right = "millennium" },
    .{ .wrong = "noticable", .right = "noticeable" },
    .{ .wrong = "occurence", .right = "occurrence" },
    .{ .wrong = "persistant", .right = "persistent" },
    .{ .wrong = "privelege", .right = "privilege" },
    .{ .wrong = "recomend", .right = "recommend" },
    .{ .wrong = "refrence", .right = "reference" },
    .{ .wrong = "untill", .right = "until" },
    .{ .wrong = "wierd", .right = "weird" },
    .{ .wrong = "wich", .right = "which" },
    .{ .wrong = "alot", .right = "a lot" },
    .{ .wrong = "arguement", .right = "argument" },
    .{ .wrong = "begining", .right = "beginning" },
};

fn checkLine(line: []const u8) ?*const Misspelling {
    for (&common_misspellings) |*ms| {
        if (containsWord(line, ms.wrong)) return ms;
    }
    return null;
}

fn containsWord(text: []const u8, word: []const u8) bool {
    var i: usize = 0;
    while (i + word.len <= text.len) {
        if (std.ascii.eqlIgnoreCase(text[i .. i + word.len], word)) {
            // Check word boundaries
            const before_ok = (i == 0) or !std.ascii.isAlphabetic(text[i - 1]);
            const after_ok = (i + word.len >= text.len) or !std.ascii.isAlphabetic(text[i + word.len]);
            if (before_ok and after_ok) return true;
        }
        i += 1;
    }
    return false;
}

fn spellCheck(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const line = editor.buffer.getLine(editor.cursor_row);

    if (checkLine(line)) |ms| {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Spelling: '{s}' -> '{s}' (use :spell.fix)", .{ ms.wrong, ms.right }) catch "Found issue";
        editor.status.set(msg, true);
    } else {
        editor.status.set("No misspellings found on this line", false);
    }
}

fn spellAll(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var issues: usize = 0;
    var first_row: usize = 0;
    var first_word: []const u8 = "";

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        if (checkLine(line)) |ms| {
            if (issues == 0) {
                first_row = row;
                first_word = ms.wrong;
            }
            issues += 1;
        }
    }

    if (issues == 0) {
        editor.status.set("Document clean — no common misspellings found", false);
    } else {
        // Jump to first issue
        editor.cursor_row = first_row;
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Found {d} misspelling(s). First: '{s}' on line {d}", .{ issues, first_word, first_row + 1 }) catch "Issues found";
        editor.status.set(msg, true);
    }
}

fn spellFix(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const line = editor.buffer.getLine(editor.cursor_row);
    var fixed: usize = 0;

    for (&common_misspellings) |*ms| {
        var i: usize = 0;
        while (i + ms.wrong.len <= line.len) {
            if (std.ascii.eqlIgnoreCase(line[i .. i + ms.wrong.len], ms.wrong)) {
                const before_ok = (i == 0) or !std.ascii.isAlphabetic(line[i - 1]);
                const after_ok = (i + ms.wrong.len >= line.len) or !std.ascii.isAlphabetic(line[i + ms.wrong.len]);
                if (before_ok and after_ok) {
                    const offset = editor.buffer.posToOffset(editor.cursor_row, i);
                    editor.buffer.deleteRange(offset, offset + ms.wrong.len) catch break;
                    editor.buffer.insertSlice(offset, ms.right) catch break;
                    fixed += 1;
                    break; // One fix per misspelling per invocation
                }
            }
            i += 1;
        }
    }

    if (fixed == 0) {
        editor.status.set("No fixable misspellings on this line", false);
    } else {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Fixed {d} misspelling(s)", .{fixed}) catch "Fixed";
        editor.status.set(msg, false);
    }
}

test "spell_check plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("spell-check", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}

test "containsWord" {
    try std.testing.expect(containsWord("I recieve mail", "recieve"));
    try std.testing.expect(!containsWord("receiver", "recieve"));
    try std.testing.expect(containsWord("teh quick fox", "teh"));
}
