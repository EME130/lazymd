const std = @import("std");
const Renderer = @import("../Renderer.zig");
const Terminal = @import("../Terminal.zig");
const Editor = @import("../Editor.zig");
const syntax = @import("../markdown/syntax.zig");
const Layout = @import("Layout.zig");
const Self = @This();

// ── Preview Renderer ──────────────────────────────────────────────────
// Renders markdown content as a styled preview (not raw source).
// Strips syntax markers and applies visual formatting.

allocator: std.mem.Allocator,
line_ctx: syntax.LineContext = .{},
spans: std.ArrayList(syntax.Span) = .{},

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.spans.deinit(self.allocator);
}

pub fn render(self: *Self, renderer: *Renderer, editor: *Editor, rect: Layout.Rect) void {
    const content_x = rect.x + 2;
    const content_w: u16 = if (rect.w > 3) rect.w - 3 else 1;

    self.line_ctx = .{};

    // Pre-scan for code blocks before visible area
    for (0..editor.scroll_row) |row| {
        if (row >= editor.buffer.lineCount()) break;
        const line = editor.buffer.getLine(row);
        if (syntax.isCodeFence(line)) {
            self.line_ctx.in_code_block = !self.line_ctx.in_code_block;
        }
    }

    var screen_row: u16 = 0;
    var buf_row: usize = editor.scroll_row;

    while (screen_row < rect.h -| 1 and buf_row < editor.buffer.lineCount()) {
        const y = rect.y + 1 + screen_row;
        const line = editor.buffer.getLine(buf_row);

        const rows_used = self.renderLine(renderer, line, content_x, y, content_w, rect.h -| 1 -| screen_row);
        screen_row += rows_used;
        buf_row += 1;
    }
}

fn renderLine(self: *Self, renderer: *Renderer, line: []const u8, x: u16, y: u16, w: u16, max_rows: u16) u16 {
    if (max_rows == 0) return 0;

    const trimmed = std.mem.trimLeft(u8, line, " \t");

    // Code fence
    if (syntax.isCodeFence(line)) {
        self.line_ctx.in_code_block = !self.line_ctx.in_code_block;
        if (self.line_ctx.in_code_block) {
            // Opening fence: draw top border
            fillHLine(renderer, x, y, w, 0x2500, .bright_black, .{ .fixed = 235 }); // ─
            renderer.putChar(x, y, 0x250C, .bright_black, .{ .fixed = 235 }, .{}); // ┌
            if (x + w > 0) renderer.putChar(x + w -| 1, y, 0x2510, .bright_black, .{ .fixed = 235 }, .{}); // ┐
            return 1;
        } else {
            // Closing fence: draw bottom border
            fillHLine(renderer, x, y, w, 0x2500, .bright_black, .{ .fixed = 235 }); // ─
            renderer.putChar(x, y, 0x2514, .bright_black, .{ .fixed = 235 }, .{}); // └
            if (x + w > 0) renderer.putChar(x + w -| 1, y, 0x2518, .bright_black, .{ .fixed = 235 }, .{}); // ┘
            return 1;
        }
    }

    // Inside code block
    if (self.line_ctx.in_code_block) {
        renderer.putChar(x, y, 0x2502, .bright_black, .{ .fixed = 235 }, .{}); // │
        if (x + w > 0) renderer.putChar(x + w -| 1, y, 0x2502, .bright_black, .{ .fixed = 235 }, .{}); // │
        renderer.fillRect(x + 1, y, w -| 2, 1, ' ', .default, .{ .fixed = 235 }, .{});
        _ = putStrClipped(renderer, x + 1, y, line, w -| 2, .yellow, .{ .fixed = 235 }, .{});
        return 1;
    }

    // Empty line
    if (line.len == 0) return 1;

    // Horizontal rule
    if (syntax.isHorizontalRule(trimmed)) {
        fillHLine(renderer, x, y, w, 0x2500, .bright_black, .default); // ─
        return 1;
    }

    // Header
    if (parseHeader(trimmed)) |result| {
        const header_text = result.text;
        const level = result.level;
        const fg: Terminal.Color = switch (level) {
            1 => .bright_cyan,
            2 => .bright_green,
            3 => .bright_yellow,
            else => .bright_blue,
        };
        const style: Terminal.Style = .{ .bold = true };

        // Render header text with inline formatting
        const written = self.renderInline(renderer, header_text, x, y, w, fg, style);
        _ = written;

        // Underline for h1 and h2
        if (level <= 2 and max_rows > 1) {
            const underline_char: u21 = if (level == 1) 0x2550 else 0x2500; // ═ or ─
            const underline_color: Terminal.Color = if (level == 1) .bright_cyan else .bright_green;
            fillHLine(renderer, x, y + 1, w, underline_char, underline_color, .default);
            return 2;
        }
        return 1;
    }

    // Blockquote
    if (trimmed.len > 0 and trimmed[0] == '>') {
        renderer.putChar(x, y, 0x2502, .bright_cyan, .default, .{ .bold = true }); // │
        const quote_text = if (trimmed.len > 1 and trimmed[1] == ' ') trimmed[2..] else trimmed[1..];
        _ = self.renderInline(renderer, quote_text, x + 2, y, w -| 2, .bright_black, .{ .italic = true });
        return 1;
    }

    // Unordered list (including task checkboxes)
    if (isListItem(trimmed)) {
        const indent = line.len - trimmed.len;
        const bullet_indent: u16 = @intCast(@min(indent, w));
        const item_text = trimmed[2..];

        // Check for task checkbox: - [ ] or - [x]
        if (item_text.len >= 3 and item_text[0] == '[' and item_text[2] == ']') {
            const is_checked = item_text[1] == 'x' or item_text[1] == 'X';
            const checkbox: u21 = if (is_checked) 0x2611 else 0x2610; // ☑ or ☐
            const checkbox_fg: Terminal.Color = if (is_checked) .bright_green else .bright_yellow;
            renderer.putChar(x + bullet_indent, y, checkbox, checkbox_fg, .default, .{ .bold = true });
            const task_text = if (item_text.len > 3) item_text[3..] else "";
            const task_text_trimmed = std.mem.trimLeft(u8, task_text, " ");
            const task_style: Terminal.Style = if (is_checked) .{ .strikethrough = true, .dim = true } else .{};
            const task_fg: Terminal.Color = if (is_checked) .bright_black else .default;
            _ = self.renderInline(renderer, task_text_trimmed, x + bullet_indent + 2, y, w -| bullet_indent -| 2, task_fg, task_style);
        } else {
            renderer.putChar(x + bullet_indent, y, 0x2022, .bright_magenta, .default, .{ .bold = true }); // •
            _ = self.renderInline(renderer, item_text, x + bullet_indent + 2, y, w -| bullet_indent -| 2, .default, .{});
        }
        return 1;
    }

    // Numbered list
    if (isNumberedList(trimmed)) {
        const indent = line.len - trimmed.len;
        const bullet_indent: u16 = @intCast(@min(indent, w));
        const prefix_len = numberedListPrefixLen(trimmed);
        _ = putStrClipped(renderer, x + bullet_indent, y, trimmed[0..prefix_len], w -| bullet_indent, .bright_magenta, .default, .{ .bold = true });
        const item_text = trimmed[prefix_len..];
        _ = self.renderInline(renderer, item_text, x + bullet_indent + @as(u16, @intCast(prefix_len)), y, w -| bullet_indent -| @as(u16, @intCast(prefix_len)), .default, .{});
        return 1;
    }

    // Normal paragraph
    _ = self.renderInline(renderer, line, x, y, w, .default, .{});
    return 1;
}

fn renderInline(self: *Self, renderer: *Renderer, text: []const u8, x: u16, y: u16, w: u16, base_fg: Terminal.Color, base_style: Terminal.Style) u16 {
    var col: u16 = 0;
    var i: usize = 0;

    while (i < text.len and col < w) {
        // Bold+Italic (***text*** or ___text___)
        if (i + 2 < text.len and ((text[i] == '*' and text[i + 1] == '*' and text[i + 2] == '*') or
            (text[i] == '_' and text[i + 1] == '_' and text[i + 2] == '_')))
        {
            const marker = text[i];
            if (findClosing3(text, i + 3, marker)) |end| {
                const inner = text[i + 3 .. end];
                col += putStrClipped(renderer, x + col, y, inner, w -| col, if (base_fg == .default) .bright_white else base_fg, .default, mergeStyle(base_style, .{ .bold = true, .italic = true }));
                i = end + 3;
                continue;
            }
        }

        // Bold (**text** or __text__)
        if (i + 1 < text.len and ((text[i] == '*' and text[i + 1] == '*') or
            (text[i] == '_' and text[i + 1] == '_')))
        {
            const marker = text[i];
            if (findClosing2(text, i + 2, marker)) |end| {
                const inner = text[i + 2 .. end];
                col += putStrClipped(renderer, x + col, y, inner, w -| col, if (base_fg == .default) .bright_white else base_fg, .default, mergeStyle(base_style, .{ .bold = true }));
                i = end + 2;
                continue;
            }
        }

        // Italic (*text* or _text_)
        if (text[i] == '*' or text[i] == '_') {
            const marker = text[i];
            if (findClosing1(text, i + 1, marker)) |end| {
                if (end > i + 1) {
                    const inner = text[i + 1 .. end];
                    col += putStrClipped(renderer, x + col, y, inner, w -| col, if (base_fg == .default) .white else base_fg, .default, mergeStyle(base_style, .{ .italic = true }));
                    i = end + 1;
                    continue;
                }
            }
        }

        // Strikethrough (~~text~~)
        if (i + 1 < text.len and text[i] == '~' and text[i + 1] == '~') {
            if (findClosingStr(text, i + 2, "~~")) |end| {
                const inner = text[i + 2 .. end];
                col += putStrClipped(renderer, x + col, y, inner, w -| col, .bright_black, .default, mergeStyle(base_style, .{ .strikethrough = true }));
                i = end + 2;
                continue;
            }
        }

        // Inline code (`code`)
        if (text[i] == '`') {
            if (findClosing1(text, i + 1, '`')) |end| {
                const inner = text[i + 1 .. end];
                col += putStrClipped(renderer, x + col, y, inner, w -| col, .yellow, .{ .fixed = 236 }, base_style);
                i = end + 1;
                continue;
            }
        }

        // Image ![alt](url) — show as [IMAGE: alt]
        if (text[i] == '!' and i + 1 < text.len and text[i + 1] == '[') {
            if (parseLink(text, i + 1)) |link| {
                const alt_text = text[i + 2 .. link.text_end];
                col += putStrClipped(renderer, x + col, y, "[", w -| col, .bright_magenta, .default, .{ .dim = true });
                col += putStrClipped(renderer, x + col, y, alt_text, w -| col, .bright_magenta, .default, base_style);
                col += putStrClipped(renderer, x + col, y, "]", w -| col, .bright_magenta, .default, .{ .dim = true });
                i = link.url_end + 1; // +1 for the leading '!'
                continue;
            }
        }

        // Link [text](url)
        if (text[i] == '[') {
            if (parseLink(text, i)) |link| {
                const link_text = text[i + 1 .. link.text_end];
                col += putStrClipped(renderer, x + col, y, link_text, w -| col, .bright_blue, .default, mergeStyle(base_style, .{ .underline = true }));
                i = link.url_end;
                continue;
            }
        }

        // Normal character
        if (col < w) {
            const byte_len = std.unicode.utf8ByteSequenceLength(text[i]) catch {
                i += 1;
                continue;
            };
            if (i + byte_len > text.len) break;
            const codepoint = std.unicode.utf8Decode(text[i .. i + byte_len]) catch {
                i += byte_len;
                continue;
            };
            const fg = if (base_fg == .default) .default else base_fg;
            renderer.putChar(x + col, y, codepoint, fg, .default, base_style);
            col += 1;
            i += byte_len;
        }
    }

    _ = self;
    return col;
}

// ── Helpers ───────────────────────────────────────────────────────────

const HeaderResult = struct {
    level: u8,
    text: []const u8,
};

fn parseHeader(line: []const u8) ?HeaderResult {
    var level: u8 = 0;
    var i: usize = 0;
    while (i < line.len and line[i] == '#') : (i += 1) {
        level += 1;
        if (level > 6) return null;
    }
    if (level == 0 or i >= line.len or line[i] != ' ') return null;
    return .{ .level = level, .text = line[i + 1 ..] };
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

fn findClosing1(text: []const u8, start: usize, marker: u8) ?usize {
    var i = start;
    while (i < text.len) : (i += 1) {
        if (text[i] == marker) return i;
    }
    return null;
}

fn findClosing2(text: []const u8, start: usize, marker: u8) ?usize {
    var i = start;
    while (i + 1 < text.len) : (i += 1) {
        if (text[i] == marker and text[i + 1] == marker) return i;
    }
    return null;
}

fn findClosing3(text: []const u8, start: usize, marker: u8) ?usize {
    var i = start;
    while (i + 2 < text.len) : (i += 1) {
        if (text[i] == marker and text[i + 1] == marker and text[i + 2] == marker) return i;
    }
    return null;
}

fn findClosingStr(text: []const u8, start: usize, needle: []const u8) ?usize {
    var i = start;
    while (i + needle.len <= text.len) : (i += 1) {
        if (std.mem.eql(u8, text[i .. i + needle.len], needle)) return i;
    }
    return null;
}

const LinkInfo = struct {
    text_end: usize,
    url_end: usize,
};

fn parseLink(text: []const u8, start: usize) ?LinkInfo {
    var i = start + 1;
    while (i < text.len) : (i += 1) {
        if (text[i] == ']') break;
    } else return null;
    if (i >= text.len) return null;
    const bracket_close = i;
    if (bracket_close + 1 >= text.len or text[bracket_close + 1] != '(') return null;
    i = bracket_close + 2;
    while (i < text.len) : (i += 1) {
        if (text[i] == ')') {
            return .{ .text_end = bracket_close, .url_end = i + 1 };
        }
    }
    return null;
}

fn mergeStyle(a: Terminal.Style, b: Terminal.Style) Terminal.Style {
    return .{
        .bold = a.bold or b.bold,
        .dim = a.dim or b.dim,
        .italic = a.italic or b.italic,
        .underline = a.underline or b.underline,
        .reverse = a.reverse or b.reverse,
        .strikethrough = a.strikethrough or b.strikethrough,
    };
}

fn fillHLine(renderer: *Renderer, x: u16, y: u16, w: u16, char: u21, fg: Terminal.Color, bg: Terminal.Color) void {
    for (0..w) |dx| {
        renderer.putChar(x +| @as(u16, @intCast(dx)), y, char, fg, bg, .{});
    }
}

fn putStrClipped(renderer: *Renderer, x: u16, y: u16, str: []const u8, max_w: u16, fg: Terminal.Color, bg: Terminal.Color, style: Terminal.Style) u16 {
    var col: u16 = 0;
    var i: usize = 0;
    while (i < str.len and col < max_w) {
        const byte_len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            i += 1;
            continue;
        };
        if (i + byte_len > str.len) break;
        const codepoint = std.unicode.utf8Decode(str[i .. i + byte_len]) catch {
            i += byte_len;
            continue;
        };
        renderer.putChar(x + col, y, codepoint, fg, bg, style);
        col += 1;
        i += byte_len;
    }
    return col;
}

// ── Tests ─────────────────────────────────────────────────────────────

test "parseHeader" {
    const h1 = parseHeader("# Hello");
    try std.testing.expect(h1 != null);
    try std.testing.expectEqual(@as(u8, 1), h1.?.level);
    try std.testing.expectEqualStrings("Hello", h1.?.text);

    const h3 = parseHeader("### Test");
    try std.testing.expect(h3 != null);
    try std.testing.expectEqual(@as(u8, 3), h3.?.level);

    try std.testing.expect(parseHeader("Not a header") == null);
    try std.testing.expect(parseHeader("####### Too many") == null);
}

test "isListItem" {
    try std.testing.expect(isListItem("- item"));
    try std.testing.expect(isListItem("* item"));
    try std.testing.expect(isListItem("+ item"));
    try std.testing.expect(!isListItem("no"));
}

test "findClosing" {
    try std.testing.expectEqual(@as(?usize, 5), findClosing1("hello*world", 0, '*'));
    try std.testing.expectEqual(@as(?usize, null), findClosing1("hello", 0, '*'));
}

test "parseLink" {
    const link = parseLink("[text](https://example.com)", 0);
    try std.testing.expect(link != null);
    try std.testing.expectEqual(@as(usize, 5), link.?.text_end);
    try std.testing.expectEqual(@as(usize, 27), link.?.url_end);

    try std.testing.expect(parseLink("no link here", 0) == null);
}

test "numberedList" {
    try std.testing.expect(isNumberedList("1. item"));
    try std.testing.expect(isNumberedList("42. item"));
    try std.testing.expect(!isNumberedList("no"));
    try std.testing.expect(!isNumberedList("1.no space"));
}
