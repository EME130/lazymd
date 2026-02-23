const std = @import("std");

// ── Key Types ─────────────────────────────────────────────────────────

pub const Key = struct {
    code: Code,
    ctrl: bool = false,
    alt: bool = false,

    pub const Code = union(enum) {
        char: u21,
        // Navigation
        up,
        down,
        left,
        right,
        home,
        end,
        page_up,
        page_down,
        // Editing
        backspace,
        delete,
        tab,
        enter,
        escape,
        // Function keys
        f1,
        f2,
        f3,
        f4,
        f5,
        f6,
        f7,
        f8,
        f9,
        f10,
        f11,
        f12,
    };

    pub fn char(c: u21) Key {
        return .{ .code = .{ .char = c } };
    }

    pub fn ctrl_key(c: u21) Key {
        return .{ .code = .{ .char = c }, .ctrl = true };
    }

    pub fn eql(a: Key, b: Key) bool {
        return std.meta.eql(a.code, b.code) and a.ctrl == b.ctrl and a.alt == b.alt;
    }
};

pub const MouseButton = enum {
    left,
    middle,
    right,
    scroll_up,
    scroll_down,
    release,
};

pub const Mouse = struct {
    button: MouseButton,
    x: u16, // 0-indexed column
    y: u16, // 0-indexed row
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,
};

// ── Size ──────────────────────────────────────────────────────────────

pub const Size = struct {
    width: u16,
    height: u16,
};

// ── Event ─────────────────────────────────────────────────────────────

pub const Event = union(enum) {
    key: Key,
    mouse: Mouse,
    resize: Size,
    none,
};

// ── Tests ─────────────────────────────────────────────────────────────

test "Key equality" {
    const a = Key.char('a');
    const b = Key.char('a');
    try std.testing.expect(a.eql(b));

    const c = Key.ctrl_key('c');
    try std.testing.expect(!a.eql(c));
}

test "Key construction" {
    const k = Key.char('x');
    try std.testing.expect(k.code == .char);
    try std.testing.expect(k.code.char == 'x');
    try std.testing.expect(!k.ctrl);
    try std.testing.expect(!k.alt);
}

test "Size struct" {
    const s = Size{ .width = 80, .height = 24 };
    try std.testing.expectEqual(@as(u16, 80), s.width);
    try std.testing.expectEqual(@as(u16, 24), s.height);
}
