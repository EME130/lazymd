const std = @import("std");
const events = @import("events.zig");
const Surface = @import("Surface.zig");

pub const Event = events.Event;
pub const Size = events.Size;
pub const Key = events.Key;
pub const Mouse = events.Mouse;
pub const MouseButton = events.MouseButton;

const Self = @This();

// ── VTable ───────────────────────────────────────────────────────────

pub const VTable = struct {
    /// Initialize the frontend (enter raw mode, alternate screen, etc.)
    init: *const fn (ctx: *anyopaque) anyerror!void,

    /// Shut down the frontend (restore terminal, etc.)
    deinit: *const fn (ctx: *anyopaque) void,

    /// Get the current display size.
    getSize: *const fn (ctx: *anyopaque) Size,

    /// Check if the display has been resized since last call. Returns new size or null.
    checkResize: *const fn (ctx: *anyopaque) ?Size,

    /// Poll for the next input event (key, mouse, resize, or none).
    pollEvent: *const fn (ctx: *anyopaque) anyerror!Event,

    /// Get a mutable reference to the drawing surface.
    getSurface: *const fn (ctx: *anyopaque) *Surface,

    /// Flush the surface to the display (diff render for TUI, send frame for web, etc.)
    flush: *const fn (ctx: *anyopaque) anyerror!void,
};

// ── Fields ───────────────────────────────────────────────────────────

ptr: *anyopaque,
vtable: *const VTable,

// ── Dispatch Methods ─────────────────────────────────────────────────

pub fn frontendInit(self: Self) !void {
    return self.vtable.init(self.ptr);
}

pub fn frontendDeinit(self: Self) void {
    self.vtable.deinit(self.ptr);
}

pub fn getSize(self: Self) Size {
    return self.vtable.getSize(self.ptr);
}

pub fn checkResize(self: Self) ?Size {
    return self.vtable.checkResize(self.ptr);
}

pub fn pollEvent(self: Self) !Event {
    return self.vtable.pollEvent(self.ptr);
}

pub fn getSurface(self: Self) *Surface {
    return self.vtable.getSurface(self.ptr);
}

pub fn flush(self: Self) !void {
    return self.vtable.flush(self.ptr);
}

// ── Tests ─────────────────────────────────────────────────────────────

test "Frontend vtable compiles" {
    // Just verify the types compile correctly
    const vtable = VTable{
        .init = undefined,
        .deinit = undefined,
        .getSize = undefined,
        .checkResize = undefined,
        .pollEvent = undefined,
        .getSurface = undefined,
        .flush = undefined,
    };
    _ = vtable;
}
