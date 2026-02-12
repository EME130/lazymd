const std = @import("std");
const posix = std.posix;
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

pub const Size = struct {
    rows: u16,
    cols: u16,
};

// ── State ──────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
orig_termios: posix.termios,
tty: posix.fd_t,
width: u16,
height: u16,
buf: std.ArrayList(u8),

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator) !Self {
    const tty = try posix.open("/dev/tty", .{ .ACCMODE = .RDWR }, 0);
    const orig = try posix.tcgetattr(tty);

    var raw = orig;
    // Input flags
    raw.iflag.BRKINT = false;
    raw.iflag.ICRNL = false;
    raw.iflag.INPCK = false;
    raw.iflag.ISTRIP = false;
    raw.iflag.IXON = false;
    // Output flags
    raw.oflag.OPOST = false;
    // Control flags
    raw.cflag.CSIZE = .CS8;
    // Local flags
    raw.lflag.ECHO = false;
    raw.lflag.ICANON = false;
    raw.lflag.IEXTEN = false;
    raw.lflag.ISIG = false;
    // Read timeout: return after 100ms with no input
    raw.cc[@intFromEnum(posix.V.MIN)] = 0;
    raw.cc[@intFromEnum(posix.V.TIME)] = 1;

    try posix.tcsetattr(tty, .FLUSH, raw);

    const size = getWindowSize(tty);

    var self = Self{
        .allocator = allocator,
        .orig_termios = orig,
        .tty = tty,
        .width = size.cols,
        .height = size.rows,
        .buf = .{},
    };

    try self.buf.ensureTotalCapacity(allocator, 4096);

    // Enter alternate screen, hide cursor
    try self.writeStr("\x1b[?1049h");
    try self.writeStr("\x1b[?25l");
    try self.flush();

    return self;
}

pub fn deinit(self: *Self) void {
    // Show cursor, leave alternate screen
    self.writeStr("\x1b[?25h") catch {};
    self.writeStr("\x1b[?1049l") catch {};
    self.flush() catch {};

    // Restore terminal
    posix.tcsetattr(self.tty, .FLUSH, self.orig_termios) catch {};
    posix.close(self.tty);
    self.buf.deinit(self.allocator);
}

// ── Window Size ───────────────────────────────────────────────────────

fn getWindowSize(fd: posix.fd_t) Size {
    var wsz: posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
    const err = posix.system.ioctl(fd, posix.T.IOCGWINSZ, @intFromPtr(&wsz));
    if (posix.errno(err) == .SUCCESS and wsz.col > 0 and wsz.row > 0) {
        return .{ .rows = wsz.row, .cols = wsz.col };
    }
    return .{ .rows = 24, .cols = 80 };
}

pub fn updateSize(self: *Self) bool {
    const size = getWindowSize(self.tty);
    if (size.cols != self.width or size.rows != self.height) {
        self.width = size.cols;
        self.height = size.rows;
        return true;
    }
    return false;
}

// ── Raw Output ────────────────────────────────────────────────────────

pub fn writeStr(self: *Self, s: []const u8) !void {
    try self.buf.appendSlice(self.allocator, s);
}

pub fn writeByte(self: *Self, b: u8) !void {
    try self.buf.append(self.allocator, b);
}

pub fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    try self.buf.writer(self.allocator).print(fmt, args);
}

pub fn flush(self: *Self) !void {
    if (self.buf.items.len == 0) return;
    _ = try posix.write(self.tty, self.buf.items);
    self.buf.clearRetainingCapacity();
}

// ── Cursor Control ────────────────────────────────────────────────────

pub fn moveCursor(self: *Self, row: u16, col: u16) !void {
    try self.writeFmt("\x1b[{};{}H", .{ row + 1, col + 1 });
}

pub fn showCursor(self: *Self) !void {
    try self.writeStr("\x1b[?25h");
}

pub fn hideCursor(self: *Self) !void {
    try self.writeStr("\x1b[?25l");
}

// ── Screen Control ────────────────────────────────────────────────────

pub fn clearScreen(self: *Self) !void {
    try self.writeStr("\x1b[2J");
    try self.writeStr("\x1b[H");
}

pub fn clearLine(self: *Self) !void {
    try self.writeStr("\x1b[2K");
}

pub fn clearToEol(self: *Self) !void {
    try self.writeStr("\x1b[K");
}

// ── Style / Color ─────────────────────────────────────────────────────

pub fn resetStyle(self: *Self) !void {
    try self.writeStr("\x1b[0m");
}

pub fn setStyle(self: *Self, style: Style) !void {
    if (style.bold) try self.writeStr("\x1b[1m");
    if (style.dim) try self.writeStr("\x1b[2m");
    if (style.italic) try self.writeStr("\x1b[3m");
    if (style.underline) try self.writeStr("\x1b[4m");
    if (style.reverse) try self.writeStr("\x1b[7m");
    if (style.strikethrough) try self.writeStr("\x1b[9m");
}

pub fn setFg(self: *Self, color: Color) !void {
    switch (color) {
        .default => try self.writeStr("\x1b[39m"),
        .black => try self.writeStr("\x1b[30m"),
        .red => try self.writeStr("\x1b[31m"),
        .green => try self.writeStr("\x1b[32m"),
        .yellow => try self.writeStr("\x1b[33m"),
        .blue => try self.writeStr("\x1b[34m"),
        .magenta => try self.writeStr("\x1b[35m"),
        .cyan => try self.writeStr("\x1b[36m"),
        .white => try self.writeStr("\x1b[37m"),
        .bright_black => try self.writeStr("\x1b[90m"),
        .bright_red => try self.writeStr("\x1b[91m"),
        .bright_green => try self.writeStr("\x1b[92m"),
        .bright_yellow => try self.writeStr("\x1b[93m"),
        .bright_blue => try self.writeStr("\x1b[94m"),
        .bright_magenta => try self.writeStr("\x1b[95m"),
        .bright_cyan => try self.writeStr("\x1b[96m"),
        .bright_white => try self.writeStr("\x1b[97m"),
        .rgb => |c| try self.writeFmt("\x1b[38;2;{};{};{}m", .{ c.r, c.g, c.b }),
        .fixed => |n| try self.writeFmt("\x1b[38;5;{}m", .{n}),
    }
}

pub fn setBg(self: *Self, color: Color) !void {
    switch (color) {
        .default => try self.writeStr("\x1b[49m"),
        .black => try self.writeStr("\x1b[40m"),
        .red => try self.writeStr("\x1b[41m"),
        .green => try self.writeStr("\x1b[42m"),
        .yellow => try self.writeStr("\x1b[43m"),
        .blue => try self.writeStr("\x1b[44m"),
        .magenta => try self.writeStr("\x1b[45m"),
        .cyan => try self.writeStr("\x1b[46m"),
        .white => try self.writeStr("\x1b[47m"),
        .bright_black => try self.writeStr("\x1b[100m"),
        .bright_red => try self.writeStr("\x1b[101m"),
        .bright_green => try self.writeStr("\x1b[102m"),
        .bright_yellow => try self.writeStr("\x1b[103m"),
        .bright_blue => try self.writeStr("\x1b[104m"),
        .bright_magenta => try self.writeStr("\x1b[105m"),
        .bright_cyan => try self.writeStr("\x1b[106m"),
        .bright_white => try self.writeStr("\x1b[107m"),
        .rgb => |c| try self.writeFmt("\x1b[48;2;{};{};{}m", .{ c.r, c.g, c.b }),
        .fixed => |n| try self.writeFmt("\x1b[48;5;{}m", .{n}),
    }
}

pub fn setCell(self: *Self, style: Style, fg: Color, bg: Color) !void {
    try self.resetStyle();
    try self.setStyle(style);
    try self.setFg(fg);
    try self.setBg(bg);
}

// ── Read Input ────────────────────────────────────────────────────────

pub fn readByte(self: *Self) !?u8 {
    var buf_local: [1]u8 = undefined;
    const n = posix.read(self.tty, &buf_local) catch |err| switch (err) {
        error.WouldBlock => return null,
        else => return err,
    };
    if (n == 0) return null;
    return buf_local[0];
}

pub fn readBytes(self: *Self, out: []u8) !usize {
    return posix.read(self.tty, out) catch |err| switch (err) {
        error.WouldBlock => return 0,
        else => return err,
    };
}

// ── Helpers ───────────────────────────────────────────────────────────

pub fn writeUtf8(self: *Self, codepoint: u21) !void {
    var buf_local: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(codepoint, &buf_local) catch return;
    try self.writeStr(buf_local[0..len]);
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
