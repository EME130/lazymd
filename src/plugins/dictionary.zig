const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Dictionary plugin — built-in mini dictionary for common words.
/// Also shows word under cursor info.
/// Commands: :define, :define.insert
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "dictionary", .version = "0.1.0", .author = "lazy-md contributors", .description = "Word definition lookup" };
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
        .{ .name = "define", .description = "Look up word definition", .handler = &define },
        .{ .name = "define.insert", .description = "Insert definition at cursor", .handler = &defineInsert },
    };
}

const DictEntry = struct {
    word: []const u8,
    definition: []const u8,
};

const dictionary = [_]DictEntry{
    .{ .word = "algorithm", .definition = "A step-by-step procedure for solving a problem" },
    .{ .word = "api", .definition = "Application Programming Interface — a set of rules for software communication" },
    .{ .word = "asynchronous", .definition = "Not occurring at the same time; non-blocking operations" },
    .{ .word = "boolean", .definition = "A data type with only two values: true or false" },
    .{ .word = "cache", .definition = "A temporary storage area for frequently accessed data" },
    .{ .word = "callback", .definition = "A function passed as an argument to be executed later" },
    .{ .word = "compile", .definition = "To translate source code into machine-executable form" },
    .{ .word = "database", .definition = "An organized collection of structured data" },
    .{ .word = "debug", .definition = "To identify and remove errors from software" },
    .{ .word = "deprecate", .definition = "To mark as outdated and discourage use" },
    .{ .word = "encrypt", .definition = "To convert data into a coded form for security" },
    .{ .word = "framework", .definition = "A reusable set of libraries and tools for building software" },
    .{ .word = "git", .definition = "A distributed version control system" },
    .{ .word = "hash", .definition = "A fixed-size value derived from input data via a function" },
    .{ .word = "iterate", .definition = "To repeat a process, typically over a collection" },
    .{ .word = "json", .definition = "JavaScript Object Notation — a lightweight data format" },
    .{ .word = "kernel", .definition = "The core component of an operating system" },
    .{ .word = "latency", .definition = "The delay between a request and its response" },
    .{ .word = "markdown", .definition = "A lightweight markup language for formatting text" },
    .{ .word = "mutex", .definition = "A synchronization primitive for exclusive resource access" },
    .{ .word = "null", .definition = "A special value representing the absence of data" },
    .{ .word = "parse", .definition = "To analyze a string and extract structured data" },
    .{ .word = "query", .definition = "A request for data from a database or system" },
    .{ .word = "recursion", .definition = "A function that calls itself to solve a problem" },
    .{ .word = "refactor", .definition = "To restructure code without changing its behavior" },
    .{ .word = "runtime", .definition = "The period during which a program is executing" },
    .{ .word = "schema", .definition = "The structure or blueprint of a database or data format" },
    .{ .word = "syntax", .definition = "The rules governing the structure of code or language" },
    .{ .word = "thread", .definition = "A lightweight unit of execution within a process" },
    .{ .word = "token", .definition = "A unit of meaning in parsing or authentication" },
};

fn define(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const word = event.command_args orelse {
        // Use word under cursor
        const line = editor.buffer.getLine(editor.cursor_row);
        const col = @min(editor.cursor_col, if (line.len > 0) line.len - 1 else 0);
        var start = col;
        while (start > 0 and std.ascii.isAlphabetic(line[start - 1])) : (start -= 1) {}
        var end = col;
        while (end < line.len and std.ascii.isAlphabetic(line[end])) : (end += 1) {}
        if (start == end) {
            editor.status.set("Usage: :define <word>", true);
            return;
        }
        lookupWord(editor, line[start..end]);
        return;
    };
    lookupWord(editor, word);
}

fn lookupWord(editor: *Editor, word: []const u8) void {
    for (&dictionary) |*entry| {
        if (std.ascii.eqlIgnoreCase(entry.word, word)) {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{s}: {s}", .{ entry.word, entry.definition }) catch "Found";
            editor.status.set(msg, false);
            return;
        }
    }
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "'{s}' not in built-in dictionary (30 tech terms available)", .{word}) catch "Not found";
    editor.status.set(msg, false);
}

fn defineInsert(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const word = event.command_args orelse {
        editor.status.set("Usage: :define.insert <word>", true);
        return;
    };

    for (&dictionary) |*entry| {
        if (std.ascii.eqlIgnoreCase(entry.word, word)) {
            var buf: [256]u8 = undefined;
            const text = std.fmt.bufPrint(&buf, "\n**{s}**: {s}\n", .{ entry.word, entry.definition }) catch {
                editor.status.set("Format error", true);
                return;
            };
            const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
            editor.buffer.insertSlice(offset, text) catch {
                editor.status.set("Insert failed", true);
                return;
            };
            editor.status.set("Definition inserted", false);
            return;
        }
    }

    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "'{s}' not found in dictionary", .{word}) catch "Not found";
    editor.status.set(msg, true);
}

test "dictionary plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("dictionary", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
