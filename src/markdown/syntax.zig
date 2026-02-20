const std = @import("std");
const Terminal = @import("../Terminal.zig");

pub const TokenType = enum {
    normal,
    h1,
    h2,
    h3,
    h4,
    h5,
    h6,
    bold,
    italic,
    bold_italic,
    code_inline,
    code_block_marker,
    code_block,
    link_text,
    link_url,
    image_marker,
    list_bullet,
    list_number,
    blockquote,
    hr,
    strikethrough,
    task_checkbox,
    html_tag,
    wiki_link,
};

pub const Span = struct {
    start: usize,
    end: usize,
    token: TokenType,
};

pub const Theme = struct {
    const themes = @import("../themes.zig");

    pub fn getFg(token: TokenType) Terminal.Color {
        const c = themes.currentColors();
        return switch (token) {
            .h1 => c.h1,
            .h2 => c.h2,
            .h3 => c.h3,
            .h4 => c.h4,
            .h5 => c.h5,
            .h6 => c.h6,
            .bold, .bold_italic => c.bold,
            .italic => c.italic,
            .code_inline, .code_block, .code_block_marker => c.code,
            .link_text => c.link,
            .link_url => c.link_url,
            .image_marker => c.list_marker,
            .list_bullet, .list_number => c.list_marker,
            .blockquote => c.blockquote,
            .hr => c.hr,
            .strikethrough => c.strikethrough,
            .task_checkbox => c.checkbox,
            .html_tag => c.text_muted,
            .wiki_link => c.link,
            .normal => c.text,
        };
    }

    pub fn getStyle(token: TokenType) Terminal.Style {
        return switch (token) {
            .h1 => .{ .bold = true },
            .h2 => .{ .bold = true },
            .h3 => .{ .bold = true },
            .bold => .{ .bold = true },
            .italic => .{ .italic = true },
            .bold_italic => .{ .bold = true, .italic = true },
            .code_inline, .code_block, .code_block_marker => .{},
            .link_text => .{ .underline = true },
            .link_url => .{ .dim = true },
            .wiki_link => .{ .underline = true, .bold = true },
            .strikethrough => .{ .strikethrough = true },
            .blockquote => .{ .italic = true },
            .hr => .{ .dim = true },
            else => .{},
        };
    }

    pub fn getBg(token: TokenType) Terminal.Color {
        const c = themes.currentColors();
        return switch (token) {
            .code_inline => c.code_bg,
            .code_block => c.code_block_bg,
            .code_block_marker => c.code_block_bg,
            else => .default,
        };
    }
};

pub const LineContext = struct {
    in_code_block: bool = false,
};

pub fn isCodeFence(line: []const u8) bool {
    const trimmed = std.mem.trimLeft(u8, line, " ");
    if (trimmed.len < 3) return false;
    if (std.mem.startsWith(u8, trimmed, "```")) return true;
    if (std.mem.startsWith(u8, trimmed, "~~~")) return true;
    return false;
}

pub fn tokenizeLine(allocator: std.mem.Allocator, line: []const u8, ctx: *LineContext, spans: *std.ArrayList(Span)) !void {
    spans.clearRetainingCapacity();

    if (isCodeFence(line)) {
        try spans.append(allocator, .{ .start = 0, .end = line.len, .token = .code_block_marker });
        ctx.in_code_block = !ctx.in_code_block;
        return;
    }

    if (ctx.in_code_block) {
        try spans.append(allocator, .{ .start = 0, .end = line.len, .token = .code_block });
        return;
    }

    if (line.len == 0) return;

    const trimmed = std.mem.trimLeft(u8, line, " \t");

    if (isHorizontalRule(trimmed)) {
        try spans.append(allocator, .{ .start = 0, .end = line.len, .token = .hr });
        return;
    }

    if (parseHeader(trimmed)) |level| {
        const token: TokenType = switch (level) {
            1 => .h1,
            2 => .h2,
            3 => .h3,
            4 => .h4,
            5 => .h5,
            6 => .h6,
            else => .normal,
        };
        try spans.append(allocator, .{ .start = 0, .end = line.len, .token = token });
        return;
    }

    if (trimmed.len > 0 and trimmed[0] == '>') {
        try spans.append(allocator, .{ .start = 0, .end = line.len, .token = .blockquote });
        return;
    }

    if (isListItem(trimmed)) {
        const indent = line.len - trimmed.len;
        const bullet_end = indent + 2;
        try spans.append(allocator, .{ .start = 0, .end = bullet_end, .token = .list_bullet });
        if (bullet_end < line.len) {
            try tokenizeInline(allocator, line, bullet_end, line.len, spans);
        }
        return;
    }

    if (isNumberedList(trimmed)) {
        const indent = line.len - trimmed.len;
        const num_end = indent + numberedListPrefixLen(trimmed);
        try spans.append(allocator, .{ .start = 0, .end = num_end, .token = .list_number });
        if (num_end < line.len) {
            try tokenizeInline(allocator, line, num_end, line.len, spans);
        }
        return;
    }

    try tokenizeInline(allocator, line, 0, line.len, spans);
}

fn tokenizeInline(allocator: std.mem.Allocator, line: []const u8, start: usize, end: usize, spans: *std.ArrayList(Span)) !void {
    var i = start;
    var text_start = start;

    while (i < end) {
        if (line[i] == '`') {
            if (i > text_start) {
                try spans.append(allocator, .{ .start = text_start, .end = i, .token = .normal });
            }
            const code_end = findInlineCode(line, i, end);
            try spans.append(allocator, .{ .start = i, .end = code_end, .token = .code_inline });
            i = code_end;
            text_start = i;
            continue;
        }

        // Bold + italic
        if (i + 2 < end and ((line[i] == '*' and line[i + 1] == '*' and line[i + 2] == '*') or
            (line[i] == '_' and line[i + 1] == '_' and line[i + 2] == '_')))
        {
            const marker = line[i];
            if (findClosing(line, i + 3, end, &[3]u8{ marker, marker, marker })) |close| {
                if (i > text_start) try spans.append(allocator, .{ .start = text_start, .end = i, .token = .normal });
                try spans.append(allocator, .{ .start = i, .end = close + 3, .token = .bold_italic });
                i = close + 3;
                text_start = i;
                continue;
            }
        }

        // Bold
        if (i + 1 < end and ((line[i] == '*' and line[i + 1] == '*') or
            (line[i] == '_' and line[i + 1] == '_')))
        {
            const marker = line[i];
            if (findClosing(line, i + 2, end, &[2]u8{ marker, marker })) |close| {
                if (i > text_start) try spans.append(allocator, .{ .start = text_start, .end = i, .token = .normal });
                try spans.append(allocator, .{ .start = i, .end = close + 2, .token = .bold });
                i = close + 2;
                text_start = i;
                continue;
            }
        }

        // Italic
        if (line[i] == '*' or line[i] == '_') {
            const marker = line[i];
            if (findClosing(line, i + 1, end, &[1]u8{marker})) |close| {
                if (close > i + 1) {
                    if (i > text_start) try spans.append(allocator, .{ .start = text_start, .end = i, .token = .normal });
                    try spans.append(allocator, .{ .start = i, .end = close + 1, .token = .italic });
                    i = close + 1;
                    text_start = i;
                    continue;
                }
            }
        }

        // Strikethrough
        if (i + 1 < end and line[i] == '~' and line[i + 1] == '~') {
            if (findClosing(line, i + 2, end, "~~")) |close| {
                if (i > text_start) try spans.append(allocator, .{ .start = text_start, .end = i, .token = .normal });
                try spans.append(allocator, .{ .start = i, .end = close + 2, .token = .strikethrough });
                i = close + 2;
                text_start = i;
                continue;
            }
        }

        // Wiki-links [[target]] or [[target|display]]
        if (i + 1 < end and line[i] == '[' and line[i + 1] == '[') {
            if (findWikiLinkEnd(line, i + 2, end)) |wl_end| {
                if (i > text_start) try spans.append(allocator, .{ .start = text_start, .end = i, .token = .normal });
                try spans.append(allocator, .{ .start = i, .end = wl_end, .token = .wiki_link });
                i = wl_end;
                text_start = i;
                continue;
            }
        }

        // Links
        if (line[i] == '[') {
            if (parseLink(line, i, end)) |link| {
                if (i > text_start) try spans.append(allocator, .{ .start = text_start, .end = i, .token = .normal });
                try spans.append(allocator, .{ .start = i, .end = link.text_end, .token = .link_text });
                try spans.append(allocator, .{ .start = link.text_end, .end = link.url_end, .token = .link_url });
                i = link.url_end;
                text_start = i;
                continue;
            }
        }

        i += 1;
    }

    if (text_start < end) {
        try spans.append(allocator, .{ .start = text_start, .end = end, .token = .normal });
    }
}

fn parseHeader(line: []const u8) ?u8 {
    var level: u8 = 0;
    for (line) |c| {
        if (c == '#') {
            level += 1;
            if (level > 6) return null;
        } else if (c == ' ') {
            if (level >= 1) return level;
            return null;
        } else {
            return null;
        }
    }
    return null;
}

pub fn isHorizontalRule(line: []const u8) bool {
    if (line.len < 3) return false;
    var count: usize = 0;
    const ch = line[0];
    if (ch != '-' and ch != '*' and ch != '_') return false;
    for (line) |c| {
        if (c == ch) count += 1 else if (c != ' ') return false;
    }
    return count >= 3;
}

fn isListItem(line: []const u8) bool {
    if (line.len < 2) return false;
    return (line[0] == '-' or line[0] == '*' or line[0] == '+') and line[1] == ' ';
}

fn isNumberedList(line: []const u8) bool {
    var i: usize = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {}
    if (i == 0 or i >= line.len) return false;
    return line[i] == '.' and i + 1 < line.len and line[i + 1] == ' ';
}

fn numberedListPrefixLen(line: []const u8) usize {
    var i: usize = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {}
    return i + 2;
}

fn findInlineCode(line: []const u8, start: usize, end: usize) usize {
    var i = start + 1;
    while (i < end) : (i += 1) {
        if (line[i] == '`') return i + 1;
    }
    return end;
}

fn findClosing(line: []const u8, start: usize, end: usize, marker: []const u8) ?usize {
    if (start + marker.len > end) return null;
    var i = start;
    while (i + marker.len <= end) : (i += 1) {
        if (std.mem.eql(u8, line[i .. i + marker.len], marker)) return i;
    }
    return null;
}

const LinkResult = struct { text_end: usize, url_end: usize };

fn findWikiLinkEnd(line: []const u8, start: usize, end: usize) ?usize {
    var i = start;
    while (i + 1 < end) : (i += 1) {
        if (line[i] == ']' and line[i + 1] == ']') return i + 2;
        if (line[i] == '\n') return null;
    }
    return null;
}

fn parseLink(line: []const u8, start: usize, end: usize) ?LinkResult {
    var i = start + 1;
    while (i < end) : (i += 1) {
        if (line[i] == ']') break;
    } else return null;
    if (i >= end) return null;
    const bracket_close = i;
    if (bracket_close + 1 >= end or line[bracket_close + 1] != '(') return null;
    i = bracket_close + 2;
    while (i < end) : (i += 1) {
        if (line[i] == ')') {
            return .{ .text_end = bracket_close + 1, .url_end = i + 1 };
        }
    }
    return null;
}

// ── Tests ─────────────────────────────────────────────────────────────

test "header detection" {
    try std.testing.expectEqual(@as(?u8, 1), parseHeader("# Hello"));
    try std.testing.expectEqual(@as(?u8, 3), parseHeader("### Test"));
    try std.testing.expectEqual(@as(?u8, null), parseHeader("####### Too many"));
    try std.testing.expectEqual(@as(?u8, null), parseHeader("Not a header"));
}

test "horizontal rule" {
    try std.testing.expect(isHorizontalRule("---"));
    try std.testing.expect(isHorizontalRule("***"));
    try std.testing.expect(isHorizontalRule("___"));
    try std.testing.expect(isHorizontalRule("- - -"));
    try std.testing.expect(!isHorizontalRule("--"));
    try std.testing.expect(!isHorizontalRule("abc"));
}

test "code fence" {
    try std.testing.expect(isCodeFence("```"));
    try std.testing.expect(isCodeFence("```zig"));
    try std.testing.expect(isCodeFence("~~~"));
    try std.testing.expect(!isCodeFence("``"));
}

test "tokenize header line" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Span) = .{};
    defer spans.deinit(allocator);
    var ctx = LineContext{};

    try tokenizeLine(allocator, "## Hello world", &ctx, &spans);
    try std.testing.expectEqual(@as(usize, 1), spans.items.len);
    try std.testing.expectEqual(TokenType.h2, spans.items[0].token);
}

test "tokenize code block" {
    const allocator = std.testing.allocator;
    var spans: std.ArrayList(Span) = .{};
    defer spans.deinit(allocator);
    var ctx = LineContext{};

    try tokenizeLine(allocator, "```zig", &ctx, &spans);
    try std.testing.expect(ctx.in_code_block);
    try std.testing.expectEqual(TokenType.code_block_marker, spans.items[0].token);

    spans.clearRetainingCapacity();
    try tokenizeLine(allocator, "const x = 5;", &ctx, &spans);
    try std.testing.expectEqual(TokenType.code_block, spans.items[0].token);

    spans.clearRetainingCapacity();
    try tokenizeLine(allocator, "```", &ctx, &spans);
    try std.testing.expect(!ctx.in_code_block);
}
