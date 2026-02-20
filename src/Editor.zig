const std = @import("std");
const Buffer = @import("Buffer.zig");
const Input = @import("Input.zig");
const Key = Input.Key;
const Renderer = @import("Renderer.zig");
const Terminal = @import("Terminal.zig");
const syntax = @import("markdown/syntax.zig");
const Self = @This();

// ── Types ─────────────────────────────────────────────────────────────

pub const Mode = enum {
    normal,
    insert,
    command,
};

pub const StatusMsg = struct {
    text: [256]u8 = undefined,
    len: usize = 0,
    is_error: bool = false,

    pub fn set(self: *StatusMsg, msg: []const u8, err: bool) void {
        const copy_len = @min(msg.len, self.text.len);
        @memcpy(self.text[0..copy_len], msg[0..copy_len]);
        self.len = copy_len;
        self.is_error = err;
    }

    pub fn slice(self: *const StatusMsg) []const u8 {
        return self.text[0..self.len];
    }
};

// ── State ─────────────────────────────────────────────────────────────

buffer: Buffer,
allocator: std.mem.Allocator,
// Cursor (0-indexed)
cursor_row: usize = 0,
cursor_col: usize = 0,
// Desired column for vertical movement
desired_col: usize = 0,
// Scroll offset
scroll_row: usize = 0,
scroll_col: usize = 0,
// Editor viewport (set by layout)
view_x: u16 = 0,
view_y: u16 = 0,
view_width: u16 = 80,
view_height: u16 = 24,
// Mode
mode: Mode = .normal,
// Command line
cmd_buf: [256]u8 = undefined,
cmd_len: usize = 0,
// File path
file_path: ?[]const u8 = null,
file_path_owned: ?[]u8 = null,
// Status message
status: StatusMsg = .{},
// Quit flag
should_quit: bool = false,
// Syntax state
line_ctx: syntax.LineContext = .{},
spans: std.ArrayList(syntax.Span) = .{},
// Count prefix for vim commands
count: usize = 0,
// Pending operator (d, c, y)
pending_op: ?u21 = null,
// Plugin manager pointer (set by main.zig)
plugin_mgr: ?*@import("plugin.zig").PluginManager = null,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .buffer = try Buffer.init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.spans.deinit(self.allocator);
    self.buffer.deinit();
    if (self.file_path_owned) |p| self.allocator.free(p);
}

pub fn openFile(self: *Self, path: []const u8) !void {
    try self.buffer.loadFile(path);
    const owned = try self.allocator.dupe(u8, path);
    if (self.file_path_owned) |old| self.allocator.free(old);
    self.file_path_owned = owned;
    self.file_path = owned;
    self.cursor_row = 0;
    self.cursor_col = 0;
    self.scroll_row = 0;
    self.status.set("File opened", false);
    if (self.plugin_mgr) |pm| {
        var event = @import("plugin.zig").PluginEvent{ .type = .file_open, .editor = self };
        pm.broadcast(&event);
    }
}

// ── Input Dispatch ────────────────────────────────────────────────────

pub fn handleEvent(self: *Self, event: Input.Event) !void {
    switch (event) {
        .key => |key| switch (self.mode) {
            .normal => try self.handleNormal(key),
            .insert => try self.handleInsert(key),
            .command => try self.handleCommand(key),
        },
        .mouse => {},
        .resize => {},
        .none => {},
    }
}

// ── Normal Mode ───────────────────────────────────────────────────────

fn handleNormal(self: *Self, key: Key) !void {
    // Ctrl shortcuts
    if (key.ctrl) {
        switch (key.code) {
            .char => |c| switch (c) {
                's' => try self.save(),
                'u' => {
                    const n = if (self.count > 0) self.count else @as(usize, self.view_height / 2);
                    self.count = 0;
                    for (0..n) |_| self.moveCursorUp();
                },
                'd' => {
                    const n = if (self.count > 0) self.count else @as(usize, self.view_height / 2);
                    self.count = 0;
                    for (0..n) |_| self.moveCursorDown();
                },
                'r' => try self.buffer.redo(),
                else => {},
            },
            else => {},
        }
        return;
    }

    switch (key.code) {
        .char => |c| {
            // Count prefix
            if (c >= '1' and c <= '9' and self.count == 0 and self.pending_op == null) {
                self.count = c - '0';
                return;
            }
            if (c >= '0' and c <= '9' and self.count > 0) {
                self.count = self.count * 10 + (c - '0');
                return;
            }

            const n = if (self.count > 0) self.count else 1;
            self.count = 0;

            // Handle pending operator
            if (self.pending_op) |op| {
                self.pending_op = null;
                switch (op) {
                    'd' => {
                        if (c == 'd') {
                            for (0..n) |_| try self.deleteLine();
                        }
                    },
                    else => {},
                }
                return;
            }

            switch (c) {
                // Movement
                'h' => for (0..n) |_| self.moveCursorLeft(),
                'j' => for (0..n) |_| self.moveCursorDown(),
                'k' => for (0..n) |_| self.moveCursorUp(),
                'l' => for (0..n) |_| self.moveCursorRight(),
                'w' => for (0..n) |_| self.wordForward(),
                'b' => for (0..n) |_| self.wordBackward(),
                'e' => for (0..n) |_| self.wordEnd(),
                '0' => self.cursor_col = 0,
                '$' => self.cursorToLineEnd(),
                '^' => self.cursorToFirstNonBlank(),

                // Entering insert mode
                'i' => self.mode = .insert,
                'I' => {
                    self.cursorToFirstNonBlank();
                    self.mode = .insert;
                },
                'a' => {
                    self.moveCursorRight();
                    self.mode = .insert;
                },
                'A' => {
                    self.cursorToLineEnd();
                    self.moveCursorRight();
                    self.mode = .insert;
                },
                'o' => {
                    self.cursorToLineEnd();
                    const offset = self.buffer.posToOffset(self.cursor_row, self.cursor_col);
                    try self.buffer.insertChar(offset, '\n');
                    self.cursor_row += 1;
                    self.cursor_col = 0;
                    self.mode = .insert;
                },
                'O' => {
                    const line_start = self.buffer.posToOffset(self.cursor_row, 0);
                    try self.buffer.insertChar(line_start, '\n');
                    self.cursor_col = 0;
                    self.mode = .insert;
                },

                // Editing
                'x' => {
                    for (0..n) |_| {
                        const offset = self.buffer.posToOffset(self.cursor_row, self.cursor_col);
                        if (offset < self.buffer.length()) {
                            try self.buffer.deleteChar(offset);
                        }
                    }
                    self.clampCursor();
                },
                'd' => self.pending_op = 'd',
                'u' => try self.buffer.undo(),
                'p' => {}, // paste (TODO: clipboard)

                // Jumps
                'g' => self.cursor_row = 0,
                'G' => {
                    self.cursor_row = if (self.buffer.lineCount() > 0) self.buffer.lineCount() - 1 else 0;
                },

                // Command mode
                ':' => {
                    self.mode = .command;
                    self.cmd_len = 0;
                },

                else => {},
            }
        },
        .up => self.moveCursorUp(),
        .down => self.moveCursorDown(),
        .left => self.moveCursorLeft(),
        .right => self.moveCursorRight(),
        .home => self.cursor_col = 0,
        .end => self.cursorToLineEnd(),
        .page_up => {
            for (0..self.view_height) |_| self.moveCursorUp();
        },
        .page_down => {
            for (0..self.view_height) |_| self.moveCursorDown();
        },
        else => {},
    }
}

// ── Insert Mode ───────────────────────────────────────────────────────

fn handleInsert(self: *Self, key: Key) !void {
    if (key.code == .escape) {
        self.mode = .normal;
        if (self.cursor_col > 0) self.cursor_col -= 1;
        return;
    }

    if (key.ctrl) {
        switch (key.code) {
            .char => |c| switch (c) {
                's' => try self.save(),
                else => {},
            },
            else => {},
        }
        return;
    }

    switch (key.code) {
        .char => |c| {
            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(c, &buf) catch return;
            const offset = self.buffer.posToOffset(self.cursor_row, self.cursor_col);
            try self.buffer.insertSlice(offset, buf[0..len]);
            self.cursor_col += 1;
        },
        .enter => {
            const offset = self.buffer.posToOffset(self.cursor_row, self.cursor_col);
            try self.buffer.insertChar(offset, '\n');
            self.cursor_row += 1;
            self.cursor_col = 0;
        },
        .backspace => {
            const offset = self.buffer.posToOffset(self.cursor_row, self.cursor_col);
            if (offset > 0) {
                const prev_byte = self.buffer.byteAt(offset - 1);
                try self.buffer.deleteChar(offset - 1);
                if (prev_byte == '\n') {
                    if (self.cursor_row > 0) {
                        self.cursor_row -= 1;
                        self.cursor_col = self.buffer.getLineLen(self.cursor_row);
                    }
                } else {
                    if (self.cursor_col > 0) self.cursor_col -= 1;
                }
            }
        },
        .delete => {
            const offset = self.buffer.posToOffset(self.cursor_row, self.cursor_col);
            if (offset < self.buffer.length()) {
                try self.buffer.deleteChar(offset);
            }
        },
        .tab => {
            const offset = self.buffer.posToOffset(self.cursor_row, self.cursor_col);
            try self.buffer.insertSlice(offset, "    ");
            self.cursor_col += 4;
        },
        .up => self.moveCursorUp(),
        .down => self.moveCursorDown(),
        .left => self.moveCursorLeft(),
        .right => self.moveCursorRight(),
        .home => self.cursor_col = 0,
        .end => self.cursorToLineEnd(),
        else => {},
    }
}

// ── Command Mode ──────────────────────────────────────────────────────

fn handleCommand(self: *Self, key: Key) !void {
    switch (key.code) {
        .escape => {
            self.mode = .normal;
            self.cmd_len = 0;
        },
        .enter => {
            try self.executeCommand();
            self.mode = .normal;
        },
        .backspace => {
            if (self.cmd_len > 0) {
                self.cmd_len -= 1;
            } else {
                self.mode = .normal;
            }
        },
        .char => |c| {
            if (c < 128 and self.cmd_len < self.cmd_buf.len) {
                self.cmd_buf[self.cmd_len] = @intCast(c);
                self.cmd_len += 1;
            }
        },
        else => {},
    }
}

fn executeCommand(self: *Self) !void {
    const cmd = self.cmd_buf[0..self.cmd_len];

    if (std.mem.eql(u8, cmd, "q") or std.mem.eql(u8, cmd, "quit")) {
        if (self.buffer.dirty) {
            self.status.set("Unsaved changes! Use :q! to force quit or :wq to save and quit", true);
            return;
        }
        self.should_quit = true;
    } else if (std.mem.eql(u8, cmd, "q!")) {
        self.should_quit = true;
    } else if (std.mem.eql(u8, cmd, "w") or std.mem.eql(u8, cmd, "write")) {
        try self.save();
    } else if (std.mem.eql(u8, cmd, "wq") or std.mem.eql(u8, cmd, "x")) {
        try self.save();
        self.should_quit = true;
    } else if (std.mem.startsWith(u8, cmd, "w ")) {
        const path = std.mem.trimLeft(u8, cmd[2..], " ");
        if (path.len > 0) {
            try self.saveAs(path);
        }
    } else if (std.mem.startsWith(u8, cmd, "e ")) {
        const path = std.mem.trimLeft(u8, cmd[2..], " ");
        if (path.len > 0) {
            self.openFile(path) catch {
                self.status.set("Failed to open file", true);
            };
        }
    } else if (std.mem.eql(u8, cmd, "theme")) {
        const themes = @import("themes.zig");
        const t = themes.currentTheme();
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "Theme: {s} ({d}/{d})", .{ t.name, themes.current_theme_index + 1, themes.theme_count }) catch "Theme info unavailable";
        self.status.set(msg, false);
    } else if (std.mem.eql(u8, cmd, "theme.cycle") or std.mem.eql(u8, cmd, "theme.next")) {
        const themes = @import("themes.zig");
        themes.cycleTheme();
        const t = themes.currentTheme();
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "Theme: {s}", .{t.name}) catch "Theme changed";
        self.status.set(msg, false);
    } else if (std.mem.startsWith(u8, cmd, "theme ")) {
        const themes = @import("themes.zig");
        const name = std.mem.trimLeft(u8, cmd[6..], " ");
        if (themes.findThemeByName(name)) |idx| {
            themes.setTheme(idx);
            var msg_buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&msg_buf, "Theme: {s}", .{name}) catch "Theme set";
            self.status.set(msg, false);
        } else {
            self.status.set("Unknown theme. Use :theme.cycle to browse", true);
        }
    } else if (std.mem.eql(u8, cmd, "theme.list")) {
        self.status.set("Themes: default dracula gruvbox nord solarized monokai catppuccin tokyo-night one-dark rose-pine kanagawa everforest", false);
    } else {
        // Try plugin commands
        if (self.plugin_mgr) |pm| {
            const space_idx = std.mem.indexOfScalar(u8, cmd, ' ');
            const cmd_name = if (space_idx) |idx| cmd[0..idx] else cmd;
            const cmd_args = if (space_idx) |idx| cmd[idx + 1 ..] else "";
            var pe = @import("plugin.zig").PluginEvent{
                .type = .command,
                .editor = self,
                .command_name = cmd_name,
                .command_args = if (cmd_args.len > 0) cmd_args else null,
            };
            if (pm.executeCommand(cmd_name, &pe)) return;
        }
        self.status.set("Unknown command", true);
    }
}

// ── Cursor Movement ───────────────────────────────────────────────────

fn moveCursorUp(self: *Self) void {
    if (self.cursor_row > 0) {
        self.cursor_row -= 1;
        self.cursor_col = @min(self.desired_col, self.buffer.getLineLen(self.cursor_row));
    }
}

fn moveCursorDown(self: *Self) void {
    if (self.cursor_row + 1 < self.buffer.lineCount()) {
        self.cursor_row += 1;
        self.cursor_col = @min(self.desired_col, self.buffer.getLineLen(self.cursor_row));
    }
}

fn moveCursorLeft(self: *Self) void {
    if (self.cursor_col > 0) {
        self.cursor_col -= 1;
        self.desired_col = self.cursor_col;
    }
}

fn moveCursorRight(self: *Self) void {
    const line_len = self.buffer.getLineLen(self.cursor_row);
    const max_col = if (self.mode == .insert) line_len else if (line_len > 0) line_len - 1 else 0;
    if (self.cursor_col < max_col) {
        self.cursor_col += 1;
        self.desired_col = self.cursor_col;
    }
}

fn cursorToLineEnd(self: *Self) void {
    const len = self.buffer.getLineLen(self.cursor_row);
    self.cursor_col = if (len > 0 and self.mode == .normal) len - 1 else len;
    self.desired_col = std.math.maxInt(usize);
}

fn cursorToFirstNonBlank(self: *Self) void {
    const line = self.buffer.getLine(self.cursor_row);
    var col: usize = 0;
    while (col < line.len and (line[col] == ' ' or line[col] == '\t')) : (col += 1) {}
    self.cursor_col = col;
    self.desired_col = col;
}

fn wordForward(self: *Self) void {
    const line = self.buffer.getLine(self.cursor_row);
    var col = self.cursor_col;
    // Skip current word
    while (col < line.len and !isWordSep(line[col])) : (col += 1) {}
    // Skip spaces
    while (col < line.len and isWordSep(line[col])) : (col += 1) {}
    if (col >= line.len and self.cursor_row + 1 < self.buffer.lineCount()) {
        self.cursor_row += 1;
        self.cursor_col = 0;
        self.cursorToFirstNonBlank();
    } else {
        self.cursor_col = col;
    }
    self.desired_col = self.cursor_col;
}

fn wordBackward(self: *Self) void {
    const line = self.buffer.getLine(self.cursor_row);
    var col = self.cursor_col;
    if (col == 0) {
        if (self.cursor_row > 0) {
            self.cursor_row -= 1;
            self.cursorToLineEnd();
        }
        return;
    }
    col -= 1;
    // Skip spaces
    while (col > 0 and isWordSep(line[col])) : (col -= 1) {}
    // Skip word
    while (col > 0 and !isWordSep(line[col - 1])) : (col -= 1) {}
    self.cursor_col = col;
    self.desired_col = col;
}

fn wordEnd(self: *Self) void {
    const line = self.buffer.getLine(self.cursor_row);
    var col = self.cursor_col + 1;
    // Skip spaces
    while (col < line.len and isWordSep(line[col])) : (col += 1) {}
    // Skip word
    while (col < line.len and !isWordSep(line[col])) : (col += 1) {}
    self.cursor_col = if (col > 0) col - 1 else 0;
    self.desired_col = self.cursor_col;
}

fn isWordSep(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '.' or c == ',' or
        c == ';' or c == ':' or c == '(' or c == ')' or c == '[' or
        c == ']' or c == '{' or c == '}';
}

fn clampCursor(self: *Self) void {
    const line_len = self.buffer.getLineLen(self.cursor_row);
    if (self.mode == .normal and line_len > 0) {
        self.cursor_col = @min(self.cursor_col, line_len - 1);
    } else {
        self.cursor_col = @min(self.cursor_col, line_len);
    }
}

fn deleteLine(self: *Self) !void {
    const line_count = self.buffer.lineCount();
    if (line_count == 0) return;

    const start = self.buffer.posToOffset(self.cursor_row, 0);
    var end: usize = undefined;
    if (self.cursor_row + 1 < line_count) {
        end = self.buffer.posToOffset(self.cursor_row + 1, 0);
    } else {
        end = self.buffer.length();
        // Include preceding newline if not first line
        if (self.cursor_row > 0 and start > 0) {
            try self.buffer.deleteRange(start - 1, end - start + 1);
            self.cursor_row -= 1;
            self.clampCursor();
            return;
        }
    }

    if (end > start) {
        try self.buffer.deleteRange(start, end - start);
    }
    if (self.cursor_row >= self.buffer.lineCount() and self.cursor_row > 0) {
        self.cursor_row -= 1;
    }
    self.clampCursor();
}

// ── Scroll Management ─────────────────────────────────────────────────

pub fn updateScroll(self: *Self) void {
    // Vertical
    if (self.cursor_row < self.scroll_row) {
        self.scroll_row = self.cursor_row;
    }
    if (self.cursor_row >= self.scroll_row + self.view_height) {
        self.scroll_row = self.cursor_row - self.view_height + 1;
    }
    // Horizontal
    if (self.cursor_col < self.scroll_col) {
        self.scroll_col = self.cursor_col;
    }
    if (self.cursor_col >= self.scroll_col + self.view_width) {
        self.scroll_col = self.cursor_col - self.view_width + 1;
    }
}

// ── File Operations ───────────────────────────────────────────────────

fn save(self: *Self) !void {
    if (self.file_path) |path| {
        try self.buffer.saveFile(path);
        self.status.set("File saved", false);
        if (self.plugin_mgr) |pm| {
            var event = @import("plugin.zig").PluginEvent{ .type = .file_save, .editor = self };
            pm.broadcast(&event);
        }
    } else {
        self.status.set("No filename. Use :w <filename>", true);
    }
}

fn saveAs(self: *Self, path: []const u8) !void {
    try self.buffer.saveFile(path);
    const owned = try self.allocator.dupe(u8, path);
    if (self.file_path_owned) |old| self.allocator.free(old);
    self.file_path_owned = owned;
    self.file_path = owned;
    self.status.set("File saved", false);
}

// ── Rendering ─────────────────────────────────────────────────────────

pub fn render(self: *Self, renderer: *Renderer) !void {
    self.updateScroll();

    // Reset syntax context for visible lines
    self.line_ctx = .{};

    // Pre-scan for code blocks before visible area
    for (0..self.scroll_row) |row| {
        if (row >= self.buffer.lineCount()) break;
        const line = self.buffer.getLine(row);
        if (syntax.isCodeFence(line)) {
            self.line_ctx.in_code_block = !self.line_ctx.in_code_block;
        }
    }

    // Draw line numbers + content
    const vx = self.view_x;
    const vy = self.view_y;

    // Line number gutter width
    const gutter_w: u16 = 4;

    for (0..self.view_height) |screen_row| {
        const buf_row = self.scroll_row + screen_row;
        const y = vy + @as(u16, @intCast(screen_row));

        if (buf_row >= self.buffer.lineCount()) {
            // Tilde for empty lines
            renderer.putChar(vx, y, '~', .bright_black, .default, .{});
            continue;
        }

        // Line number
        var num_buf: [8]u8 = undefined;
        const num_str = std.fmt.bufPrint(&num_buf, "{d: >3} ", .{buf_row + 1}) catch "??? ";
        const tc_ = @import("themes.zig").currentColors();
        const num_color: Terminal.Color = if (buf_row == self.cursor_row) tc_.gutter_active else tc_.gutter;
        renderer.putStr(vx, y, num_str, num_color, .default, .{});

        // Line content with syntax highlighting
        const line = self.buffer.getLine(buf_row);
        try syntax.tokenizeLine(self.allocator, line, &self.line_ctx, &self.spans);

        if (self.spans.items.len == 0) continue;

        for (self.spans.items) |span| {
            const fg = syntax.Theme.getFg(span.token);
            const bg = syntax.Theme.getBg(span.token);
            const style = syntax.Theme.getStyle(span.token);

            const text = line[span.start..span.end];
            var col: u16 = @intCast(span.start);
            for (text) |ch| {
                if (col >= self.scroll_col and col - @as(u16, @intCast(self.scroll_col)) + gutter_w < self.view_width) {
                    const screen_col = vx + gutter_w + @as(u16, @intCast(col)) - @as(u16, @intCast(self.scroll_col));
                    renderer.putChar(screen_col, y, ch, fg, bg, style);
                }
                col += 1;
            }
        }

        // Cursor highlight in this row
        if (buf_row == self.cursor_row) {
            const cx = vx + gutter_w + @as(u16, @intCast(self.cursor_col)) -| @as(u16, @intCast(self.scroll_col));
            if (cx < vx + self.view_width) {
                const idx = @as(usize, y) * @as(usize, renderer.width) + @as(usize, cx);
                if (idx < renderer.back.len) {
                    renderer.back[idx].style.reverse = true;
                }
            }
        }
    }
}

pub fn renderStatusBar(self: *Self, renderer: *Renderer, y: u16) void {
    const tc = @import("themes.zig").currentColors();
    // Fill status bar background
    renderer.fillRow(y, ' ', tc.status_fg, tc.status_bg, .{});

    // Mode indicator
    const mode_str = switch (self.mode) {
        .normal => " NORMAL ",
        .insert => " INSERT ",
        .command => " COMMAND ",
    };
    const mode_bg: Terminal.Color = switch (self.mode) {
        .normal => tc.mode_normal_bg,
        .insert => tc.mode_insert_bg,
        .command => tc.mode_command_bg,
    };
    renderer.putStr(0, y, mode_str, tc.title_fg, mode_bg, .{ .bold = true });

    // Filename + dirty indicator
    const name = self.file_path orelse "[No File]";
    const dirty_str: []const u8 = if (self.buffer.dirty) " [+]" else "";
    var file_buf: [128]u8 = undefined;
    const file_str = std.fmt.bufPrint(&file_buf, " {s}{s}", .{ name, dirty_str }) catch " ???";
    renderer.putStr(@intCast(mode_str.len), y, file_str, tc.status_fg, tc.status_bg, .{});

    // Position info (right-aligned)
    var pos_buf: [32]u8 = undefined;
    const pos_str = std.fmt.bufPrint(&pos_buf, "Ln {d}, Col {d} ", .{ self.cursor_row + 1, self.cursor_col + 1 }) catch "";
    if (pos_str.len < renderer.width) {
        renderer.putStr(@intCast(renderer.width - @as(u16, @intCast(pos_str.len))), y, pos_str, tc.status_fg, tc.status_bg, .{});
    }
}

pub fn renderCommandBar(self: *Self, renderer: *Renderer, y: u16) void {
    if (self.mode == .command) {
        renderer.putChar(0, y, ':', .bright_white, .default, .{ .bold = true });
        renderer.putStr(1, y, self.cmd_buf[0..self.cmd_len], .white, .default, .{});
    } else if (self.status.len > 0) {
        const tc2 = @import("themes.zig").currentColors();
        const fg: Terminal.Color = if (self.status.is_error) tc2.err_color else tc2.success;
        renderer.putStr(0, y, self.status.slice(), fg, .default, .{});
    }
}

// ── Tests ─────────────────────────────────────────────────────────────

test "editor init and insert" {
    var editor = try init(std.testing.allocator);
    defer editor.deinit();

    try std.testing.expectEqual(Mode.normal, editor.mode);

    // Simulate 'i' to enter insert mode
    try editor.handleEvent(.{ .key = Key.char('i') });
    try std.testing.expectEqual(Mode.insert, editor.mode);

    // Type 'H'
    try editor.handleEvent(.{ .key = Key.char('H') });
    try std.testing.expectEqual(@as(usize, 1), editor.buffer.length());

    // Escape to normal
    try editor.handleEvent(.{ .key = .{ .code = .escape } });
    try std.testing.expectEqual(Mode.normal, editor.mode);
}

test "cursor movement" {
    var editor = try init(std.testing.allocator);
    defer editor.deinit();

    // Insert multi-line text
    try editor.buffer.insertSlice(0, "Hello\nWorld\nTest");

    // Start at 0,0
    try std.testing.expectEqual(@as(usize, 0), editor.cursor_row);

    // Move down
    try editor.handleEvent(.{ .key = Key.char('j') });
    try std.testing.expectEqual(@as(usize, 1), editor.cursor_row);

    // Move right
    try editor.handleEvent(.{ .key = Key.char('l') });
    try std.testing.expectEqual(@as(usize, 1), editor.cursor_col);

    // Move up
    try editor.handleEvent(.{ .key = Key.char('k') });
    try std.testing.expectEqual(@as(usize, 0), editor.cursor_row);
}
