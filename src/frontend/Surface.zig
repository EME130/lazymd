const std = @import("std");
const Self = @This();

// ── Types ──────────────────────────────────────────────────────────────

pub const Color = union(enum) {
    default,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
    rgb: struct { r: u8, g: u8, b: u8 },
    fixed: u8,
};

pub const Style = packed struct {
    bold: bool = false,
    dim: bool = false,
    italic: bool = false,
    underline: bool = false,
    reverse: bool = false,
    strikethrough: bool = false,
};

pub const Cell = struct {
    char: u21 = ' ',
    fg: Color = .default,
    bg: Color = .default,
    style: Style = .{},

    pub fn eql(a: Cell, b: Cell) bool {
        return a.char == b.char and
            std.meta.eql(a.fg, b.fg) and
            std.meta.eql(a.bg, b.bg) and
            @as(u6, @bitCast(a.style)) == @as(u6, @bitCast(b.style));
    }
};

// ── State ─────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
front: []Cell, // currently displayed
back: []Cell, // being drawn to
width: u16,
height: u16,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !Self {
    const size = @as(usize, width) * @as(usize, height);
    const front = try allocator.alloc(Cell, size);
    const back = try allocator.alloc(Cell, size);

    @memset(front, Cell{});
    @memset(back, Cell{});

    return .{
        .allocator = allocator,
        .front = front,
        .back = back,
        .width = width,
        .height = height,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.front);
    self.allocator.free(self.back);
}

// ── Resize ────────────────────────────────────────────────────────────

pub fn resize(self: *Self, width: u16, height: u16) !void {
    if (width == self.width and height == self.height) return;

    const size = @as(usize, width) * @as(usize, height);
    self.allocator.free(self.front);
    self.allocator.free(self.back);
    self.front = try self.allocator.alloc(Cell, size);
    self.back = try self.allocator.alloc(Cell, size);
    @memset(self.front, Cell{});
    @memset(self.back, Cell{});
    self.width = width;
    self.height = height;
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

pub fn forceRedraw(self: *Self) void {
    // Invalidate front buffer to force full redraw on next flush
    @memset(self.front, Cell{ .char = 0xFFFD });
}

// ── Tests ─────────────────────────────────────────────────────────────

test "Cell equality" {
    const a = Cell{};
    const b = Cell{};
    try std.testing.expect(a.eql(b));

    const c = Cell{ .char = 'X', .fg = .red };
    try std.testing.expect(!a.eql(c));
}

test "Style bitcast" {
    const s = Style{ .bold = true, .italic = true };
    const bits: u6 = @bitCast(s);
    try std.testing.expect(bits != 0);
}

test "Surface init/deinit" {
    var surface = try Self.init(std.testing.allocator, 80, 24);
    defer surface.deinit();

    try std.testing.expectEqual(@as(u16, 80), surface.width);
    try std.testing.expectEqual(@as(u16, 24), surface.height);
}

test "Surface drawing" {
    var surface = try Self.init(std.testing.allocator, 10, 5);
    defer surface.deinit();

    surface.clear();
    surface.putChar(0, 0, 'A', .red, .default, .{});
    const cell = surface.back[0];
    try std.testing.expectEqual(@as(u21, 'A'), cell.char);
}
