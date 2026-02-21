const std = @import("std");
const Allocator = std.mem.Allocator;
const languages = @import("languages.zig");
const LangDef = languages.LangDef;
const Highlighter = @import("Highlighter.zig");

const Self = @This();

// ── Init ─────────────────────────────────────────────────────────────

pub fn init() Self {
    return .{};
}

pub fn highlighter(self: *Self) Highlighter {
    return .{
        .ptr = @ptrCast(self),
        .vtable = &vtable,
    };
}

const vtable = Highlighter.VTable{
    .highlightLine = highlightLineImpl,
    .supportsLanguage = supportsLanguageImpl,
};

// ── VTable Implementations ───────────────────────────────────────────

fn highlightLineImpl(ctx: *anyopaque, allocator: Allocator, line: []const u8, lang_name: []const u8, state: *Highlighter.State, spans: *std.ArrayList(Highlighter.Span)) anyerror!void {
    _ = ctx;
    const lang = languages.findLang(lang_name) orelse return;
    try highlightLine(line, lang, state, spans, allocator);
}

fn supportsLanguageImpl(ctx: *anyopaque, lang_name: []const u8) bool {
    _ = ctx;
    return languages.findLang(lang_name) != null;
}

// ── Core Highlighter ─────────────────────────────────────────────────

pub fn highlightLine(
    line: []const u8,
    lang: *const LangDef,
    state: *Highlighter.State,
    spans: *std.ArrayList(Highlighter.Span),
    allocator: Allocator,
) !void {
    spans.clearRetainingCapacity();
    if (line.len == 0) return;

    var i: usize = 0;

    // 1. Continue block comment from previous line
    if (state.in_block_comment) {
        if (lang.block_comment_end) |end_marker| {
            if (findSubstring(line, 0, end_marker)) |end_pos| {
                try spans.append(allocator, .{ .start = 0, .end = end_pos + end_marker.len, .kind = .comment });
                state.in_block_comment = false;
                i = end_pos + end_marker.len;
            } else {
                try spans.append(allocator, .{ .start = 0, .end = line.len, .kind = .comment });
                return;
            }
        } else {
            try spans.append(allocator, .{ .start = 0, .end = line.len, .kind = .comment });
            return;
        }
    }

    // 2. Continue multiline string from previous line (Python triple-quote)
    if (state.in_multiline_string) {
        if (findTripleQuoteEnd(line, 0)) |end_pos| {
            try spans.append(allocator, .{ .start = 0, .end = end_pos, .kind = .string });
            state.in_multiline_string = false;
            i = end_pos;
        } else {
            try spans.append(allocator, .{ .start = 0, .end = line.len, .kind = .string });
            return;
        }
    }

    while (i < line.len) {
        // Skip whitespace — emit as normal
        if (line[i] == ' ' or line[i] == '\t') {
            const ws_start = i;
            while (i < line.len and (line[i] == ' ' or line[i] == '\t')) : (i += 1) {}
            try spans.append(allocator, .{ .start = ws_start, .end = i, .kind = .normal });
            continue;
        }

        // Line comment
        if (lang.line_comment) |lc| {
            if (i + lc.len <= line.len and std.mem.eql(u8, line[i .. i + lc.len], lc)) {
                try spans.append(allocator, .{ .start = i, .end = line.len, .kind = .comment });
                return;
            }
        }

        // Block comment start
        if (lang.block_comment_start) |bcs| {
            if (i + bcs.len <= line.len and std.mem.eql(u8, line[i .. i + bcs.len], bcs)) {
                if (lang.block_comment_end) |bce| {
                    if (findSubstring(line, i + bcs.len, bce)) |end_pos| {
                        try spans.append(allocator, .{ .start = i, .end = end_pos + bce.len, .kind = .comment });
                        i = end_pos + bce.len;
                        continue;
                    }
                }
                // No end found on this line
                try spans.append(allocator, .{ .start = i, .end = line.len, .kind = .comment });
                state.in_block_comment = true;
                return;
            }
        }

        // Triple-quote strings (Python)
        if (lang.supports_triple_quote) {
            if (i + 3 <= line.len and ((std.mem.eql(u8, line[i .. i + 3], "\"\"\"")) or
                (std.mem.eql(u8, line[i .. i + 3], "'''"))))
            {
                if (findTripleQuoteEnd(line, i + 3)) |end_pos| {
                    try spans.append(allocator, .{ .start = i, .end = end_pos, .kind = .string });
                    i = end_pos;
                    continue;
                } else {
                    try spans.append(allocator, .{ .start = i, .end = line.len, .kind = .string });
                    state.in_multiline_string = true;
                    return;
                }
            }
        }

        // String delimiters
        if (isStringDelimiter(lang, line[i])) {
            const str_end = scanString(line, i);
            try spans.append(allocator, .{ .start = i, .end = str_end, .kind = .string });
            i = str_end;
            continue;
        }

        // Numbers
        if (isDigit(line[i]) or (line[i] == '.' and i + 1 < line.len and isDigit(line[i + 1]))) {
            const num_end = scanNumber(line, i);
            try spans.append(allocator, .{ .start = i, .end = num_end, .kind = .number });
            i = num_end;
            continue;
        }

        // Annotation prefix (@identifier for Zig/Java/Python, #[ for Rust)
        if (lang.annotation_prefix) |prefix| {
            if (line[i] == prefix) {
                if (prefix == '#' and i + 1 < line.len and line[i + 1] == '[') {
                    // Rust-style #[attr]
                    const attr_end = scanUntilChar(line, i, ']');
                    try spans.append(allocator, .{ .start = i, .end = attr_end, .kind = .annotation });
                    i = attr_end;
                    continue;
                } else if (prefix == '@') {
                    // Check if this is a Zig builtin (@import, etc.)
                    const ident_end = scanIdentifier(line, i + 1);
                    if (ident_end > i + 1) {
                        const word = line[i..ident_end];
                        if (matchWord(lang.builtins, word)) {
                            try spans.append(allocator, .{ .start = i, .end = ident_end, .kind = .builtin });
                        } else {
                            try spans.append(allocator, .{ .start = i, .end = ident_end, .kind = .annotation });
                        }
                        i = ident_end;
                        continue;
                    }
                }
            }
        }

        // Identifiers → keyword/type/builtin lookup
        if (isIdentStart(line[i])) {
            const ident_end = scanIdentifier(line, i);
            const word = line[i..ident_end];

            // For Rust macros, include the trailing '!'
            var effective_end = ident_end;
            if (effective_end < line.len and line[effective_end] == '!' and matchWord(lang.builtins, line[i .. effective_end + 1])) {
                effective_end += 1;
                try spans.append(allocator, .{ .start = i, .end = effective_end, .kind = .builtin });
                i = effective_end;
                continue;
            }

            if (matchWord(lang.keywords, word)) {
                try spans.append(allocator, .{ .start = i, .end = ident_end, .kind = .keyword });
            } else if (matchWord(lang.types, word)) {
                try spans.append(allocator, .{ .start = i, .end = ident_end, .kind = .type_name });
            } else if (matchWord(lang.builtins, word)) {
                try spans.append(allocator, .{ .start = i, .end = ident_end, .kind = .builtin });
            } else {
                try spans.append(allocator, .{ .start = i, .end = ident_end, .kind = .normal });
            }
            i = ident_end;
            continue;
        }

        // Operators
        if (isOperator(line[i])) {
            try spans.append(allocator, .{ .start = i, .end = i + 1, .kind = .operator });
            i += 1;
            continue;
        }

        // Punctuation
        if (isPunctuation(line[i])) {
            try spans.append(allocator, .{ .start = i, .end = i + 1, .kind = .punctuation });
            i += 1;
            continue;
        }

        // Everything else → normal
        try spans.append(allocator, .{ .start = i, .end = i + 1, .kind = .normal });
        i += 1;
    }
}

// ── Helpers ───────────────────────────────────────────────────────────

fn findSubstring(line: []const u8, start: usize, needle: []const u8) ?usize {
    if (needle.len == 0) return null;
    var i = start;
    while (i + needle.len <= line.len) : (i += 1) {
        if (std.mem.eql(u8, line[i .. i + needle.len], needle)) return i;
    }
    return null;
}

fn findTripleQuoteEnd(line: []const u8, start: usize) ?usize {
    var i = start;
    while (i + 3 <= line.len) : (i += 1) {
        if ((std.mem.eql(u8, line[i .. i + 3], "\"\"\"")) or
            (std.mem.eql(u8, line[i .. i + 3], "'''")))
        {
            return i + 3;
        }
    }
    return null;
}

fn isStringDelimiter(lang: *const LangDef, ch: u8) bool {
    for (lang.string_delimiters) |d| {
        if (ch == d) return true;
    }
    return false;
}

fn scanString(line: []const u8, start: usize) usize {
    const quote = line[start];
    var i = start + 1;
    while (i < line.len) : (i += 1) {
        if (line[i] == '\\') {
            i += 1; // skip escaped char
            continue;
        }
        if (line[i] == quote) return i + 1;
    }
    return line.len; // unterminated string
}

fn isDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}

fn scanNumber(line: []const u8, start: usize) usize {
    var i = start;
    // 0x, 0b, 0o prefixes
    if (i + 1 < line.len and line[i] == '0') {
        if (line[i + 1] == 'x' or line[i + 1] == 'X' or
            line[i + 1] == 'b' or line[i + 1] == 'B' or
            line[i + 1] == 'o' or line[i + 1] == 'O')
        {
            i += 2;
            while (i < line.len and (isHexDigit(line[i]) or line[i] == '_')) : (i += 1) {}
            return i;
        }
    }
    while (i < line.len and (isDigit(line[i]) or line[i] == '_')) : (i += 1) {}
    if (i < line.len and line[i] == '.') {
        i += 1;
        while (i < line.len and (isDigit(line[i]) or line[i] == '_')) : (i += 1) {}
    }
    // Exponent
    if (i < line.len and (line[i] == 'e' or line[i] == 'E')) {
        i += 1;
        if (i < line.len and (line[i] == '+' or line[i] == '-')) i += 1;
        while (i < line.len and isDigit(line[i])) : (i += 1) {}
    }
    return i;
}

fn isHexDigit(ch: u8) bool {
    return isDigit(ch) or (ch >= 'a' and ch <= 'f') or (ch >= 'A' and ch <= 'F');
}

fn isIdentStart(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z') or ch == '_';
}

fn scanIdentifier(line: []const u8, start: usize) usize {
    var i = start;
    while (i < line.len and (isIdentStart(line[i]) or isDigit(line[i]) or line[i] == '?')) : (i += 1) {}
    return i;
}

fn scanUntilChar(line: []const u8, start: usize, ch: u8) usize {
    var i = start;
    while (i < line.len) : (i += 1) {
        if (line[i] == ch) return i + 1;
    }
    return line.len;
}

fn matchWord(list: []const []const u8, word: []const u8) bool {
    for (list) |entry| {
        if (std.mem.eql(u8, entry, word)) return true;
    }
    return false;
}

fn isOperator(ch: u8) bool {
    return switch (ch) {
        '=', '+', '-', '*', '/', '%', '!', '<', '>', '&', '|', '^', '~' => true,
        else => false,
    };
}

fn isPunctuation(ch: u8) bool {
    return switch (ch) {
        '(', ')', '{', '}', '[', ']', ';', ',', '.', ':', '?' => true,
        else => false,
    };
}

// ── Tests ─────────────────────────────────────────────────────────────

test "highlight zig keywords" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("zig").?;
    try highlightLine("const x = 5;", lang, &state, &spans, allocator);

    // Should have: keyword("const"), normal(" "), normal("x"), normal(" "), operator("="), normal(" "), number("5"), punctuation(";")
    try std.testing.expect(spans.items.len > 0);
    try std.testing.expectEqual(Highlighter.TokenKind.keyword, spans.items[0].kind);
    try std.testing.expectEqualStrings("const", "const x = 5;"[spans.items[0].start..spans.items[0].end]);
}

test "highlight zig string" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("zig").?;
    try highlightLine("const s = \"hello\";", lang, &state, &spans, allocator);

    var found_string = false;
    for (spans.items) |span| {
        if (span.kind == .string) {
            try std.testing.expectEqualStrings("\"hello\"", "const s = \"hello\";"[span.start..span.end]);
            found_string = true;
        }
    }
    try std.testing.expect(found_string);
}

test "highlight line comment" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("zig").?;
    try highlightLine("// this is a comment", lang, &state, &spans, allocator);

    try std.testing.expectEqual(@as(usize, 1), spans.items.len);
    try std.testing.expectEqual(Highlighter.TokenKind.comment, spans.items[0].kind);
}

test "highlight block comment" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("javascript").?;
    try highlightLine("/* comment */ code", lang, &state, &spans, allocator);

    try std.testing.expect(spans.items.len >= 2);
    try std.testing.expectEqual(Highlighter.TokenKind.comment, spans.items[0].kind);
    try std.testing.expect(!state.in_block_comment);
}

test "highlight multiline block comment" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("javascript").?;

    // Line 1: start of block comment
    try highlightLine("/* start", lang, &state, &spans, allocator);
    try std.testing.expect(state.in_block_comment);

    // Line 2: end of block comment
    try highlightLine("end */ const x = 1;", lang, &state, &spans, allocator);
    try std.testing.expect(!state.in_block_comment);
    try std.testing.expect(spans.items.len >= 2);
    try std.testing.expectEqual(Highlighter.TokenKind.comment, spans.items[0].kind);
}

test "highlight zig builtin" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("zig").?;
    try highlightLine("@import(\"std\")", lang, &state, &spans, allocator);

    try std.testing.expect(spans.items.len > 0);
    try std.testing.expectEqual(Highlighter.TokenKind.builtin, spans.items[0].kind);
}

test "highlight numbers" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("zig").?;
    try highlightLine("0xff 42 3.14", lang, &state, &spans, allocator);

    var num_count: usize = 0;
    for (spans.items) |span| {
        if (span.kind == .number) num_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), num_count);
}

test "highlight python" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("python").?;
    try highlightLine("def hello(name: str):", lang, &state, &spans, allocator);

    try std.testing.expect(spans.items.len > 0);
    try std.testing.expectEqual(Highlighter.TokenKind.keyword, spans.items[0].kind);
    try std.testing.expectEqualStrings("def", "def hello(name: str):"[spans.items[0].start..spans.items[0].end]);
}

test "highlight empty line" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    const lang = languages.findLang("zig").?;
    try highlightLine("", lang, &state, &spans, allocator);
    try std.testing.expectEqual(@as(usize, 0), spans.items.len);
}

test "vtable highlightLine" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Highlighter.Span) = .{};
    defer spans.deinit(allocator);
    var state = Highlighter.State{};

    var builtin = init();
    var hl = builtin.highlighter();
    try hl.highlightLine(allocator, "const x = 5;", "zig", &state, &spans);

    try std.testing.expect(spans.items.len > 0);
    try std.testing.expectEqual(Highlighter.TokenKind.keyword, spans.items[0].kind);
}

test "vtable supportsLanguage" {
    var builtin = init();
    var hl = builtin.highlighter();
    try std.testing.expect(hl.supportsLanguage("zig"));
    try std.testing.expect(hl.supportsLanguage("python"));
    try std.testing.expect(!hl.supportsLanguage("brainfuck"));
}
