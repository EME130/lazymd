const std = @import("std");
const Terminal = @import("Terminal.zig");
const Cell = Terminal.Cell;
const Color = Terminal.Color;
const Style = Terminal.Style;
const Self = @This();

// ── State ─────────────────────────────────────────────────────────────

term: *Terminal,
allocator: std.mem.Allocator,
front: []Cell, // currently displayed
back: []Cell, // being drawn to
width: u16,
height: u16,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator, term: *Terminal) !Self {
    const size = @as(usize, term.width) * @as(usize, term.height);
    const front = try allocator.alloc(Cell, size);
    const back = try allocator.alloc(Cell, size);

    @memset(front, Cell{});
    @memset(back, Cell{});

    return .{
        .term = term,
        .allocator = allocator,
        .front = front,
        .back = back,
        .width = term.width,
        .height = term.height,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.front);
    self.allocator.free(self.back);
}

// ── Resize ────────────────────────────────────────────────────────────

pub fn resize(self: *Self) !void {
    const w = self.term.width;
    const h = self.term.height;
    if (w == self.width and h == self.height) return;

    const size = @as(usize, w) * @as(usize, h);
    self.allocator.free(self.front);
    self.allocator.free(self.back);
    self.front = try self.allocator.alloc(Cell, size);
    self.back = try self.allocator.alloc(Cell, size);
    @memset(self.front, Cell{});
    @memset(self.back, Cell{});
    self.width = w;
    self.height = h;
}

// ── Drawing API ───────────────────────────────────────────────────────

pub fn clear(self: *Self) void {
    @memset(self.back, Cell{});
}

pub fn setCell(self: *Self, x: u16, y: u16, cell: Cell) void {
    if (x >= self.width or y >= self.height) return;
    self.back[@as(usize, y) * @as(usize, self.width) + @as(usize, x)] = cell;
}

pub fn putChar(self: *Self, x: u16, y: u16, ch: u21, fg: Color, bg: Color, style: Style) void {
    self.setCell(x, y, .{ .char = ch, .fg = fg, .bg = bg, .style = style });
}

pub fn putStr(self: *Self, x: u16, y: u16, str: []const u8, fg: Color, bg: Color, style: Style) void {
    var col = x;
    var i: usize = 0;
    while (i < str.len) {
        if (col >= self.width) break;
        const byte_len = std.unicode.utf8ByteSequenceLength(str[i]) catch {
            i += 1;
            continue;
        };
        if (i + byte_len > str.len) break;
        const codepoint = std.unicode.utf8Decode(str[i .. i + byte_len]) catch {
            i += byte_len;
            continue;
        };
        self.putChar(col, y, codepoint, fg, bg, style);
        col += 1;
        i += byte_len;
    }
}

pub fn putStrTrunc(self: *Self, x: u16, y: u16, str: []const u8, max_w: u16, fg: Color, bg: Color, style: Style) void {
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
        self.putChar(x + col, y, codepoint, fg, bg, style);
        col += 1;
        i += byte_len;
    }
}

pub fn fillRow(self: *Self, y: u16, ch: u21, fg: Color, bg: Color, style: Style) void {
    for (0..self.width) |x| {
        self.putChar(@intCast(x), y, ch, fg, bg, style);
    }
}

pub fn fillRect(self: *Self, x: u16, y: u16, w: u16, h: u16, ch: u21, fg: Color, bg: Color, style: Style) void {
    for (0..h) |dy| {
        for (0..w) |dx| {
            self.putChar(x +| @as(u16, @intCast(dx)), y +| @as(u16, @intCast(dy)), ch, fg, bg, style);
        }
    }
}

// Box drawing
pub fn drawBox(self: *Self, x: u16, y: u16, w: u16, h: u16, fg: Color, bg: Color) void {
    if (w < 2 or h < 2) return;
    // Corners
    self.putChar(x, y, 0x250C, fg, bg, .{}); // ┌
    self.putChar(x + w - 1, y, 0x2510, fg, bg, .{}); // ┐
    self.putChar(x, y + h - 1, 0x2514, fg, bg, .{}); // └
    self.putChar(x + w - 1, y + h - 1, 0x2518, fg, bg, .{}); // ┘
    // Horizontal
    for (1..@as(usize, w) - 1) |dx| {
        self.putChar(x + @as(u16, @intCast(dx)), y, 0x2500, fg, bg, .{}); // ─
        self.putChar(x + @as(u16, @intCast(dx)), y + h - 1, 0x2500, fg, bg, .{}); // ─
    }
    // Vertical
    for (1..@as(usize, h) - 1) |dy| {
        self.putChar(x, y + @as(u16, @intCast(dy)), 0x2502, fg, bg, .{}); // │
        self.putChar(x + w - 1, y + @as(u16, @intCast(dy)), 0x2502, fg, bg, .{}); // │
    }
}

pub fn drawVLine(self: *Self, x: u16, y: u16, h: u16, fg: Color, bg: Color) void {
    for (0..h) |dy| {
        self.putChar(x, y +| @as(u16, @intCast(dy)), 0x2502, fg, bg, .{});
    }
}

// ── Flush (Diff Render) ───────────────────────────────────────────────

pub fn flush(self: *Self) !void {
    try self.term.hideCursor();

    var last_fg: Color = .default;
    var last_bg: Color = .default;
    var last_style: Style = .{};
    var last_row: u16 = 0xFFFF;
    var last_col: u16 = 0xFFFF;

    for (0..self.height) |y| {
        for (0..self.width) |x| {
            const idx = y * @as(usize, self.width) + x;
            const back_cell = self.back[idx];
            const front_cell = self.front[idx];

            if (back_cell.eql(front_cell)) continue;

            const row: u16 = @intCast(y);
            const col: u16 = @intCast(x);

            // Move cursor if not sequential
            if (row != last_row or col != last_col) {
                try self.term.moveCursor(row, col);
            }

            // Update style if changed
            if (!std.meta.eql(back_cell.fg, last_fg) or
                !std.meta.eql(back_cell.bg, last_bg) or
                @as(u6, @bitCast(back_cell.style)) != @as(u6, @bitCast(last_style)))
            {
                try self.term.resetStyle();
                try self.term.setStyle(back_cell.style);
                try self.term.setFg(back_cell.fg);
                try self.term.setBg(back_cell.bg);
                last_fg = back_cell.fg;
                last_bg = back_cell.bg;
                last_style = back_cell.style;
            }

            try self.term.writeUtf8(back_cell.char);

            last_row = row;
            last_col = col + 1;
        }
    }

    try self.term.resetStyle();

    // Swap buffers
    @memcpy(self.front, self.back);

    try self.term.flush();
}

pub fn forceRedraw(self: *Self) void {
    // Invalidate front buffer to force full redraw on next flush
    @memset(self.front, Cell{ .char = 0xFFFD });
}

// ── Tests ─────────────────────────────────────────────────────────────

test "cell operations" {
    // Can't test flush without real terminal, but test cell logic
    const a = Cell{ .char = 'A', .fg = .red, .bg = .default, .style = .{ .bold = true } };
    const b = Cell{ .char = 'A', .fg = .red, .bg = .default, .style = .{ .bold = true } };
    try std.testing.expect(a.eql(b));

    const c = Cell{ .char = 'B', .fg = .red, .bg = .default, .style = .{ .bold = true } };
    try std.testing.expect(!a.eql(c));
}
