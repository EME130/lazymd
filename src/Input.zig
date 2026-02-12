const std = @import("std");
const Terminal = @import("Terminal.zig");
const Self = @This();

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

pub const Event = union(enum) {
    key: Key,
    resize: Terminal.Size,
    none,
};

// ── State ─────────────────────────────────────────────────────────────

term: *Terminal,
buf: [32]u8 = undefined,
buf_len: usize = 0,
buf_pos: usize = 0,

// ── Init ──────────────────────────────────────────────────────────────

pub fn init(term: *Terminal) Self {
    return .{ .term = term };
}

// ── Read Events ───────────────────────────────────────────────────────

pub fn poll(self: *Self) !Event {
    // Check for resize
    if (self.term.updateSize()) {
        return .{ .resize = .{ .rows = self.term.height, .cols = self.term.width } };
    }

    const byte = self.nextByte() orelse return .none;

    // Escape sequence
    if (byte == 0x1b) {
        return self.parseEscape();
    }

    // Ctrl+key (0x01-0x1a except special cases)
    if (byte < 0x20) {
        return .{
            .key = switch (byte) {
                0x00 => Key{ .code = .{ .char = ' ' }, .ctrl = true }, // Ctrl+Space
                0x08 => Key{ .code = .backspace },
                0x09 => Key{ .code = .tab },
                0x0a, 0x0d => Key{ .code = .enter },
                0x1b => Key{ .code = .escape },
                0x7f => unreachable,
                else => Key{ .code = .{ .char = @as(u21, byte) + 0x60 }, .ctrl = true },
            },
        };
    }

    // DEL
    if (byte == 0x7f) {
        return .{ .key = .{ .code = .backspace } };
    }

    // UTF-8 multi-byte
    if (byte >= 0x80) {
        return .{ .key = .{ .code = .{ .char = self.decodeUtf8(byte) } } };
    }

    // Normal ASCII
    return .{ .key = Key.char(@as(u21, byte)) };
}

// ── Escape Sequence Parser ────────────────────────────────────────────

fn parseEscape(self: *Self) Event {
    const b1 = self.peekByte() orelse return .{ .key = .{ .code = .escape } };

    if (b1 == '[') {
        _ = self.nextByte(); // consume '['
        return self.parseCsi();
    }

    if (b1 == 'O') {
        _ = self.nextByte(); // consume 'O'
        const b2 = self.nextByte() orelse return .{ .key = .{ .code = .escape } };
        return .{ .key = .{ .code = switch (b2) {
            'P' => .f1,
            'Q' => .f2,
            'R' => .f3,
            'S' => .f4,
            'H' => .home,
            'F' => .end,
            else => .escape,
        } } };
    }

    // Alt+key
    if (b1 >= 0x20 and b1 < 0x7f) {
        _ = self.nextByte();
        return .{ .key = .{ .code = .{ .char = @as(u21, b1) }, .alt = true } };
    }

    return .{ .key = .{ .code = .escape } };
}

fn parseCsi(self: *Self) Event {
    var params: [4]u16 = .{ 0, 0, 0, 0 };
    var param_count: usize = 0;

    // Parse numeric params separated by ';'
    while (true) {
        const b = self.peekByte() orelse break;
        if (b >= '0' and b <= '9') {
            _ = self.nextByte();
            if (param_count < params.len) {
                params[param_count] = params[param_count] * 10 + @as(u16, b - '0');
            }
        } else if (b == ';') {
            _ = self.nextByte();
            param_count += 1;
        } else {
            break;
        }
    }
    param_count += 1;

    // Final byte
    const final = self.nextByte() orelse return .{ .key = .{ .code = .escape } };

    const ctrl = param_count >= 2 and (params[1] == 5 or params[1] == 6);
    const alt = param_count >= 2 and (params[1] == 3 or params[1] == 4);

    return .{ .key = .{
        .ctrl = ctrl,
        .alt = alt,
        .code = switch (final) {
            'A' => .up,
            'B' => .down,
            'C' => .right,
            'D' => .left,
            'H' => .home,
            'F' => .end,
            '~' => switch (params[0]) {
                1 => .home,
                3 => .delete,
                4 => .end,
                5 => .page_up,
                6 => .page_down,
                15 => .f5,
                17 => .f6,
                18 => .f7,
                19 => .f8,
                20 => .f9,
                21 => .f10,
                23 => .f11,
                24 => .f12,
                else => .escape,
            },
            else => .escape,
        },
    } };
}

// ── Byte Helpers ──────────────────────────────────────────────────────

fn nextByte(self: *Self) ?u8 {
    if (self.buf_pos < self.buf_len) {
        const b = self.buf[self.buf_pos];
        self.buf_pos += 1;
        return b;
    }
    // Read more from terminal
    self.buf_len = self.term.readBytes(&self.buf) catch return null;
    self.buf_pos = 0;
    if (self.buf_len == 0) return null;
    self.buf_pos = 1;
    return self.buf[0];
}

fn peekByte(self: *Self) ?u8 {
    if (self.buf_pos < self.buf_len) {
        return self.buf[self.buf_pos];
    }
    self.buf_len = self.term.readBytes(&self.buf) catch return null;
    self.buf_pos = 0;
    if (self.buf_len == 0) return null;
    return self.buf[0];
}

fn decodeUtf8(self: *Self, first: u8) u21 {
    const len: u3 = std.unicode.utf8ByteSequenceLength(first) catch return 0xFFFD;
    var bytes: [4]u8 = undefined;
    bytes[0] = first;
    for (1..len) |i| {
        bytes[i] = self.nextByte() orelse return 0xFFFD;
    }
    return std.unicode.utf8Decode(bytes[0..len]) catch 0xFFFD;
}

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
