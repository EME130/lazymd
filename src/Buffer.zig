const std = @import("std");
const Allocator = std.mem.Allocator;
const Self = @This();

const INITIAL_GAP: usize = 1024;
const MIN_GAP: usize = 256;

pub const Position = struct {
    row: usize,
    col: usize,
};

const UndoOp = union(enum) {
    insert: struct { pos: usize, len: usize },
    delete: struct { pos: usize, text: []const u8 },
};

// ── State ─────────────────────────────────────────────────────────────

allocator: Allocator,
data: []u8,
gap_start: usize,
gap_end: usize,
line_starts: std.ArrayList(usize),
dirty: bool,
undo_stack: std.ArrayList(UndoOp),
redo_stack: std.ArrayList(UndoOp),

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: Allocator) !Self {
    const data = try allocator.alloc(u8, INITIAL_GAP);
    var line_starts: std.ArrayList(usize) = .{};
    try line_starts.append(allocator, 0);

    return .{
        .allocator = allocator,
        .data = data,
        .gap_start = 0,
        .gap_end = INITIAL_GAP,
        .line_starts = line_starts,
        .dirty = false,
        .undo_stack = .{},
        .redo_stack = .{},
    };
}

pub fn deinit(self: *Self) void {
    self.freeUndoStack();
    self.freeRedoStack();
    self.undo_stack.deinit(self.allocator);
    self.redo_stack.deinit(self.allocator);
    self.line_starts.deinit(self.allocator);
    self.allocator.free(self.data);
}

fn freeUndoStack(self: *Self) void {
    for (self.undo_stack.items) |op| {
        switch (op) {
            .delete => |d| self.allocator.free(d.text),
            .insert => {},
        }
    }
    self.undo_stack.clearRetainingCapacity();
}

fn freeRedoStack(self: *Self) void {
    for (self.redo_stack.items) |op| {
        switch (op) {
            .delete => |d| self.allocator.free(d.text),
            .insert => {},
        }
    }
    self.redo_stack.clearRetainingCapacity();
}

// ── Content Access ────────────────────────────────────────────────────

pub fn length(self: *const Self) usize {
    return self.data.len - self.gapSize();
}

fn gapSize(self: *const Self) usize {
    return self.gap_end - self.gap_start;
}

pub fn lineCount(self: *const Self) usize {
    return self.line_starts.items.len;
}

pub fn getLine(self: *Self, line: usize) []const u8 {
    if (line >= self.line_starts.items.len) return "";
    const start = self.line_starts.items[line];
    const end = if (line + 1 < self.line_starts.items.len)
        self.line_starts.items[line + 1] - 1
    else
        self.length();
    if (start >= end) return "";
    // Move gap out of the way so we can return a contiguous slice
    if (start < self.gap_start and end > self.gap_start) {
        self.moveGap(end);
    }
    return self.sliceContent(start, end);
}

pub fn getLineLen(self: *const Self, line: usize) usize {
    if (line >= self.line_starts.items.len) return 0;
    const start = self.line_starts.items[line];
    const end = if (line + 1 < self.line_starts.items.len)
        self.line_starts.items[line + 1] - 1
    else
        self.length();
    return end - start;
}

fn sliceContent(self: *const Self, start: usize, end: usize) []const u8 {
    if (end <= self.gap_start) {
        return self.data[start..end];
    }
    if (start >= self.gap_start) {
        const real_start = start + self.gapSize();
        const real_end = end + self.gapSize();
        return self.data[real_start..real_end];
    }
    // Spans gap - return part before gap
    return self.data[start..self.gap_start];
}

pub fn byteAt(self: *const Self, pos: usize) u8 {
    if (pos < self.gap_start) return self.data[pos];
    return self.data[pos + self.gapSize()];
}

// ── Editing ───────────────────────────────────────────────────────────

pub fn insertChar(self: *Self, pos: usize, ch: u8) !void {
    try self.insertSlice(pos, &[_]u8{ch});
}

pub fn insertSlice(self: *Self, pos: usize, text: []const u8) !void {
    if (text.len == 0) return;
    try self.ensureGap(text.len);
    self.moveGap(pos);

    @memcpy(self.data[self.gap_start .. self.gap_start + text.len], text);
    self.gap_start += text.len;
    self.dirty = true;

    try self.undo_stack.append(self.allocator, .{ .insert = .{ .pos = pos, .len = text.len } });
    self.freeRedoStack();
    self.rebuildLineStarts();
}

pub fn deleteRange(self: *Self, pos: usize, len: usize) !void {
    if (len == 0) return;
    const deleted = try self.allocator.alloc(u8, len);
    for (0..len) |i| {
        deleted[i] = self.byteAt(pos + i);
    }

    self.moveGap(pos);
    self.gap_end += len;
    self.dirty = true;

    try self.undo_stack.append(self.allocator, .{ .delete = .{ .pos = pos, .text = deleted } });
    self.freeRedoStack();
    self.rebuildLineStarts();
}

pub fn deleteChar(self: *Self, pos: usize) !void {
    if (pos >= self.length()) return;
    try self.deleteRange(pos, 1);
}

// ── Undo / Redo ───────────────────────────────────────────────────────

pub fn undo(self: *Self) !void {
    if (self.undo_stack.items.len == 0) return;
    const op = self.undo_stack.pop() orelse return;
    switch (op) {
        .insert => |ins| {
            const deleted = try self.allocator.alloc(u8, ins.len);
            for (0..ins.len) |i| {
                deleted[i] = self.byteAt(ins.pos + i);
            }
            self.moveGap(ins.pos);
            self.gap_end += ins.len;
            try self.redo_stack.append(self.allocator, .{ .delete = .{ .pos = ins.pos, .text = deleted } });
            self.rebuildLineStarts();
        },
        .delete => |del| {
            try self.ensureGap(del.text.len);
            self.moveGap(del.pos);
            @memcpy(self.data[self.gap_start .. self.gap_start + del.text.len], del.text);
            self.gap_start += del.text.len;
            try self.redo_stack.append(self.allocator, .{ .insert = .{ .pos = del.pos, .len = del.text.len } });
            self.allocator.free(del.text);
            self.rebuildLineStarts();
        },
    }
    self.dirty = true;
}

pub fn redo(self: *Self) !void {
    if (self.redo_stack.items.len == 0) return;
    const op = self.redo_stack.pop() orelse return;
    switch (op) {
        .delete => |del| {
            self.moveGap(del.pos);
            self.gap_end += del.text.len;
            try self.undo_stack.append(self.allocator, .{ .delete = .{ .pos = del.pos, .text = del.text } });
            self.rebuildLineStarts();
        },
        .insert => |ins| {
            try self.undo_stack.append(self.allocator, .{ .insert = .{ .pos = ins.pos, .len = ins.len } });
            self.rebuildLineStarts();
        },
    }
    self.dirty = true;
}

// ── Position Conversion ───────────────────────────────────────────────

pub fn posToOffset(self: *const Self, row: usize, col: usize) usize {
    if (row >= self.line_starts.items.len) return self.length();
    const line_start = self.line_starts.items[row];
    const line_len = self.getLineLen(row);
    return line_start + @min(col, line_len);
}

pub fn offsetToPos(self: *const Self, offset: usize) Position {
    var row: usize = 0;
    for (self.line_starts.items, 0..) |start, i| {
        if (start > offset) break;
        row = i;
    }
    return .{ .row = row, .col = offset - self.line_starts.items[row] };
}

// ── File I/O ──────────────────────────────────────────────────────────

pub fn loadFile(self: *Self, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const size = stat.size;

    const new_cap = size + INITIAL_GAP;
    self.allocator.free(self.data);
    self.data = try self.allocator.alloc(u8, new_cap);

    const bytes_read = try file.readAll(self.data[0..size]);
    self.gap_start = bytes_read;
    self.gap_end = new_cap;
    self.dirty = false;

    self.freeUndoStack();
    self.freeRedoStack();
    self.rebuildLineStarts();
}

pub fn saveFile(self: *Self, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    if (self.gap_start > 0) {
        try file.writeAll(self.data[0..self.gap_start]);
    }
    if (self.gap_end < self.data.len) {
        try file.writeAll(self.data[self.gap_end..]);
    }
    self.dirty = false;
}

// ── Internal ──────────────────────────────────────────────────────────

fn moveGap(self: *Self, pos: usize) void {
    if (pos == self.gap_start) return;
    if (pos < self.gap_start) {
        const move_len = self.gap_start - pos;
        const src = self.data[pos..self.gap_start];
        const dest_start = self.gap_end - move_len;
        std.mem.copyBackwards(u8, self.data[dest_start..self.gap_end], src);
        self.gap_start = pos;
        self.gap_end = dest_start;
    } else {
        const move_len = pos - self.gap_start;
        const src = self.data[self.gap_end .. self.gap_end + move_len];
        @memcpy(self.data[self.gap_start .. self.gap_start + move_len], src);
        self.gap_start += move_len;
        self.gap_end += move_len;
    }
}

fn ensureGap(self: *Self, needed: usize) !void {
    if (self.gapSize() >= needed + MIN_GAP) return;
    const new_gap = @max(needed + INITIAL_GAP, self.data.len / 2);
    const old_len = self.data.len;
    const new_len = old_len + new_gap - self.gapSize() + needed;

    const new_data = try self.allocator.alloc(u8, new_len);
    @memcpy(new_data[0..self.gap_start], self.data[0..self.gap_start]);
    const after_gap_len = old_len - self.gap_end;
    const new_gap_end = new_len - after_gap_len;
    @memcpy(new_data[new_gap_end..], self.data[self.gap_end..]);

    self.allocator.free(self.data);
    self.data = new_data;
    self.gap_end = new_gap_end;
}

fn rebuildLineStarts(self: *Self) void {
    self.line_starts.clearRetainingCapacity();
    self.line_starts.append(self.allocator, 0) catch return;
    const total = self.length();
    for (0..total) |i| {
        if (self.byteAt(i) == '\n') {
            self.line_starts.append(self.allocator, i + 1) catch return;
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────

test "insert and read" {
    var buf = try init(std.testing.allocator);
    defer buf.deinit();

    try buf.insertSlice(0, "Hello\nWorld");
    try std.testing.expectEqual(@as(usize, 11), buf.length());
    try std.testing.expectEqual(@as(usize, 2), buf.lineCount());
    try std.testing.expectEqualStrings("Hello", buf.getLine(0));
    try std.testing.expectEqualStrings("World", buf.getLine(1));
}

test "delete" {
    var buf = try init(std.testing.allocator);
    defer buf.deinit();

    try buf.insertSlice(0, "ABCDE");
    try buf.deleteRange(1, 2);
    try std.testing.expectEqual(@as(usize, 3), buf.length());
    try std.testing.expectEqualStrings("ADE", buf.getLine(0));
}

test "undo insert" {
    var buf = try init(std.testing.allocator);
    defer buf.deinit();

    try buf.insertSlice(0, "Hello");
    try std.testing.expectEqual(@as(usize, 5), buf.length());
    try buf.undo();
    try std.testing.expectEqual(@as(usize, 0), buf.length());
}

test "position conversion" {
    var buf = try init(std.testing.allocator);
    defer buf.deinit();

    try buf.insertSlice(0, "Line1\nLine2\nLine3");
    const pos = buf.offsetToPos(7);
    try std.testing.expectEqual(@as(usize, 1), pos.row);
    try std.testing.expectEqual(@as(usize, 1), pos.col);

    const off = buf.posToOffset(2, 3);
    try std.testing.expectEqual(@as(usize, 15), off);
}
