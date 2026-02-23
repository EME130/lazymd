const std = @import("std");
const Terminal = @import("../Terminal.zig");
const Input = @import("../Input.zig");
const Surface = @import("Surface.zig");
const Frontend = @import("Frontend.zig");
const events = @import("events.zig");
const Cell = Surface.Cell;
const Color = Surface.Color;
const Style = Surface.Style;
const Self = @This();

// ── State ─────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
term: Terminal,
input: Input,
surface: Surface,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator) !Self {
    const term = try Terminal.init(allocator);
    return .{
        .allocator = allocator,
        .term = term,
        .input = .{ .term = undefined },
        .surface = try Surface.init(allocator, term.width, term.height),
    };
}

/// Must be called after init to wire up the Input's terminal pointer.
/// This is needed because Input stores a pointer to Terminal, which
/// can't reference our own field during struct construction.
pub fn wireInput(self: *Self) void {
    self.input.term = &self.term;
}

pub fn deinit(self: *Self) void {
    self.surface.deinit();
    self.term.deinit();
}

// ── Frontend Interface ────────────────────────────────────────────────

pub fn frontend(self: *Self) Frontend {
    return .{ .ptr = @ptrCast(self), .vtable = &vtable };
}

const vtable = Frontend.VTable{
    .init = initImpl,
    .deinit = deinitImpl,
    .getSize = getSizeImpl,
    .checkResize = checkResizeImpl,
    .pollEvent = pollEventImpl,
    .getSurface = getSurfaceImpl,
    .flush = flushImpl,
};

fn initImpl(_: *anyopaque) anyerror!void {
    // Terminal already initialized in TuiFrontend.init()
}

fn deinitImpl(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.deinit();
}

fn getSizeImpl(ctx: *anyopaque) events.Size {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return .{ .width = self.term.width, .height = self.term.height };
}

fn checkResizeImpl(ctx: *anyopaque) ?events.Size {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (self.term.updateSize()) {
        self.surface.resize(self.term.width, self.term.height) catch {};
        return .{ .width = self.term.width, .height = self.term.height };
    }
    return null;
}

fn pollEventImpl(ctx: *anyopaque) anyerror!events.Event {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.input.poll();
}

fn getSurfaceImpl(ctx: *anyopaque) *Surface {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return &self.surface;
}

fn flushImpl(ctx: *anyopaque) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
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

            if (row != last_row or col != last_col) {
                try self.term.moveCursor(row, col);
            }

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
    @memcpy(self.surface.front, self.surface.back);
    try self.term.flush();
}

// ── Tests ─────────────────────────────────────────────────────────────

test "TuiFrontend vtable wiring" {
    // Verify the vtable struct is properly defined and all methods are set
    const vt = vtable;
    try std.testing.expect(@intFromPtr(vt.init) != 0);
    try std.testing.expect(@intFromPtr(vt.flush) != 0);
    try std.testing.expect(@intFromPtr(vt.getSurface) != 0);
    try std.testing.expect(@intFromPtr(vt.pollEvent) != 0);
}
