const std = @import("std");
const Terminal = @import("Terminal.zig");
const Surface = @import("frontend/Surface.zig");
const Cell = Surface.Cell;
const Color = Surface.Color;
const Style = Surface.Style;
const Self = @This();

// ── State ─────────────────────────────────────────────────────────────

term: *Terminal,
surface: Surface,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator, term: *Terminal) !Self {
    return .{
        .term = term,
        .surface = try Surface.init(allocator, term.width, term.height),
    };
}

pub fn deinit(self: *Self) void {
    self.surface.deinit();
}

// ── Resize ────────────────────────────────────────────────────────────

pub fn resize(self: *Self) !void {
    try self.surface.resize(self.term.width, self.term.height);
}

// ── Drawing API (delegates to Surface) ────────────────────────────────

pub fn clear(self: *Self) void {
    self.surface.clear();
}

pub fn setCell(self: *Self, x: u16, y: u16, cell: Cell) void {
    self.surface.setCell(x, y, cell);
}

pub fn putChar(self: *Self, x: u16, y: u16, ch: u21, fg: Color, bg: Color, style: Style) void {
    self.surface.putChar(x, y, ch, fg, bg, style);
}

pub fn putStr(self: *Self, x: u16, y: u16, str: []const u8, fg: Color, bg: Color, style: Style) void {
    self.surface.putStr(x, y, str, fg, bg, style);
}

pub fn putStrTrunc(self: *Self, x: u16, y: u16, str: []const u8, max_w: u16, fg: Color, bg: Color, style: Style) void {
    self.surface.putStrTrunc(x, y, str, max_w, fg, bg, style);
}

pub fn fillRow(self: *Self, y: u16, ch: u21, fg: Color, bg: Color, style: Style) void {
    self.surface.fillRow(y, ch, fg, bg, style);
}

pub fn fillRect(self: *Self, x: u16, y: u16, w: u16, h: u16, ch: u21, fg: Color, bg: Color, style: Style) void {
    self.surface.fillRect(x, y, w, h, ch, fg, bg, style);
}

pub fn drawBox(self: *Self, x: u16, y: u16, w: u16, h: u16, fg: Color, bg: Color) void {
    self.surface.drawBox(x, y, w, h, fg, bg);
}

pub fn drawVLine(self: *Self, x: u16, y: u16, h: u16, fg: Color, bg: Color) void {
    self.surface.drawVLine(x, y, h, fg, bg);
}

pub fn forceRedraw(self: *Self) void {
    self.surface.forceRedraw();
}

// ── Accessors ─────────────────────────────────────────────────────────

pub fn getSurface(self: *Self) *Surface {
    return &self.surface;
}

/// Access width through surface (for backward compatibility, use surface.width)
pub inline fn getWidth(self: *const Self) u16 {
    return self.surface.width;
}

/// Access height through surface (for backward compatibility, use surface.height)
pub inline fn getHeight(self: *const Self) u16 {
    return self.surface.height;
}

// ── Flush (Diff Render) ───────────────────────────────────────────────

pub fn flush(self: *Self) !void {
    try self.term.hideCursor();

    var last_fg: Color = .default;
    var last_bg: Color = .default;
    var last_style: Style = .{};
    var last_row: u16 = 0xFFFF;
    var last_col: u16 = 0xFFFF;

    for (0..self.surface.height) |y| {
        for (0..self.surface.width) |x| {
            const idx = y * @as(usize, self.surface.width) + x;
            const back_cell = self.surface.back[idx];
            const front_cell = self.surface.front[idx];

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
    @memcpy(self.surface.front, self.surface.back);

    try self.term.flush();
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
