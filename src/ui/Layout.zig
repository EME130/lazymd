const std = @import("std");
const Renderer = @import("../Renderer.zig");
const Terminal = @import("../Terminal.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

pub const Panel = enum {
    file_tree,
    editor,
    preview,
};

pub const Rect = struct {
    x: u16,
    y: u16,
    w: u16,
    h: u16,
};

// ── State ─────────────────────────────────────────────────────────────

show_file_tree: bool = true,
show_preview: bool = true,
active_panel: Panel = .editor,
// Computed rects
title_rect: Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
tree_rect: Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
editor_rect: Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
preview_rect: Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
status_rect: Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
cmd_rect: Rect = .{ .x = 0, .y = 0, .w = 0, .h = 0 },
width: u16 = 0,
height: u16 = 0,

// ── Layout Calculation ────────────────────────────────────────────────

pub fn compute(self: *Self, w: u16, h: u16) void {
    self.width = w;
    self.height = h;

    // Reserve: 1 row title, 1 row status, 1 row command
    const chrome_rows: u16 = 3;
    const content_h = if (h > chrome_rows) h - chrome_rows else 1;
    const content_y: u16 = 1; // after title

    self.title_rect = .{ .x = 0, .y = 0, .w = w, .h = 1 };
    self.status_rect = .{ .x = 0, .y = h -| 2, .w = w, .h = 1 };
    self.cmd_rect = .{ .x = 0, .y = h -| 1, .w = w, .h = 1 };

    // Panel widths
    const tree_w: u16 = if (self.show_file_tree) @min(w / 5, 30) else 0;
    const preview_w: u16 = if (self.show_preview) @min(w / 4, 40) else 0;
    const editor_w = w -| tree_w -| preview_w;

    if (self.show_file_tree) {
        self.tree_rect = .{ .x = 0, .y = content_y, .w = tree_w, .h = content_h };
    }

    self.editor_rect = .{ .x = tree_w, .y = content_y, .w = editor_w, .h = content_h };

    if (self.show_preview) {
        self.preview_rect = .{ .x = tree_w + editor_w, .y = content_y, .w = preview_w, .h = content_h };
    }
}

pub fn togglePanel(self: *Self, panel: Panel) void {
    switch (panel) {
        .file_tree => self.show_file_tree = !self.show_file_tree,
        .preview => self.show_preview = !self.show_preview,
        .editor => {},
    }
}

pub fn cyclePanel(self: *Self) void {
    self.active_panel = switch (self.active_panel) {
        .file_tree => .editor,
        .editor => if (self.show_preview) .preview else .file_tree,
        .preview => if (self.show_file_tree) .file_tree else .editor,
    };
}

// ── Rendering ─────────────────────────────────────────────────────────

pub fn renderChrome(self: *Self, renderer: *Renderer) void {
    // Title bar
    renderer.fillRow(self.title_rect.y, ' ', .bright_white, .blue, .{});
    const title = " lazy-md v0.1.0";
    renderer.putStr(0, 0, title, .bright_white, .blue, .{ .bold = true });

    // Keyboard hints on title bar (right-aligned)
    const hints = "Tab:panels  1:tree  2:preview  :q quit ";
    if (hints.len < self.width) {
        renderer.putStr(self.width -| @as(u16, @intCast(hints.len)), 0, hints, .bright_cyan, .blue, .{});
    }

    // Panel borders
    if (self.show_file_tree and self.tree_rect.w > 0) {
        renderer.drawVLine(self.tree_rect.x + self.tree_rect.w -| 1, self.tree_rect.y, self.tree_rect.h, .bright_black, .default);
    }
    if (self.show_preview and self.preview_rect.w > 0) {
        renderer.drawVLine(self.preview_rect.x, self.preview_rect.y, self.preview_rect.h, .bright_black, .default);
    }
}

pub fn renderFileTree(self: *Self, renderer: *Renderer, entries: []const FileEntry) void {
    if (!self.show_file_tree) return;

    const r = self.tree_rect;
    const is_active = self.active_panel == .file_tree;
    const border_fg: Terminal.Color = if (is_active) .bright_cyan else .bright_black;

    // Panel header
    renderer.putStr(r.x + 1, r.y, " Files ", .bright_white, .default, .{ .bold = true });
    renderer.drawVLine(r.x + r.w -| 1, r.y, r.h, border_fg, .default);

    // File entries
    const max_entries = if (r.h > 2) r.h - 1 else 0;
    for (entries, 0..) |entry, i| {
        if (i >= max_entries) break;
        const y = r.y + 1 + @as(u16, @intCast(i));
        const icon: []const u8 = if (entry.is_dir) "  " else "  ";
        const fg: Terminal.Color = if (entry.is_dir) .bright_blue else if (entry.is_md) .bright_green else .white;
        renderer.putStrTrunc(r.x + 1, y, icon, r.w -| 2, fg, .default, .{});
        renderer.putStrTrunc(r.x + 3, y, entry.name, r.w -| 4, fg, .default, .{});
    }
}

pub fn renderPreview(self: *Self, renderer: *Renderer, editor: *Editor) void {
    if (!self.show_preview) return;

    const r = self.preview_rect;
    const is_active = self.active_panel == .preview;
    const border_fg: Terminal.Color = if (is_active) .bright_cyan else .bright_black;

    // Panel border and header
    renderer.drawVLine(r.x, r.y, r.h, border_fg, .default);
    renderer.putStr(r.x + 1, r.y, " Preview ", .bright_white, .default, .{ .bold = true });

    // Simple preview: render markdown with basic formatting hints
    const content_x = r.x + 2;
    const content_w = if (r.w > 3) r.w - 3 else 1;

    var preview_ctx: @import("../markdown/syntax.zig").LineContext = .{};
    var spans: std.ArrayList(@import("../markdown/syntax.zig").Span) = .{};
    defer spans.deinit(editor.allocator);

    for (0..r.h -| 1) |screen_row| {
        const buf_row = editor.scroll_row + screen_row;
        if (buf_row >= editor.buffer.lineCount()) break;
        const y = r.y + 1 + @as(u16, @intCast(screen_row));
        const line = editor.buffer.getLine(buf_row);

        @import("../markdown/syntax.zig").tokenizeLine(editor.allocator, line, &preview_ctx, &spans) catch continue;

        if (spans.items.len == 0) continue;

        // Render based on primary token
        const primary = spans.items[0].token;
        const fg = @import("../markdown/syntax.zig").Theme.getFg(primary);
        const style = @import("../markdown/syntax.zig").Theme.getStyle(primary);

        renderer.putStrTrunc(content_x, y, line, content_w, fg, .default, style);
    }
}

pub const FileEntry = struct {
    name: []const u8,
    is_dir: bool,
    is_md: bool,
};

// ── Tests ─────────────────────────────────────────────────────────────

test "layout computation" {
    var layout = Self{};
    layout.compute(120, 40);

    try std.testing.expect(layout.editor_rect.w > 0);
    try std.testing.expect(layout.tree_rect.w > 0);
    try std.testing.expect(layout.preview_rect.w > 0);
    try std.testing.expectEqual(@as(u16, 0), layout.title_rect.y);
}

test "toggle panels" {
    var layout = Self{};
    layout.compute(120, 40);

    const old_tree_w = layout.tree_rect.w;
    layout.togglePanel(.file_tree);
    layout.compute(120, 40);
    try std.testing.expect(!layout.show_file_tree);
    _ = old_tree_w;
}
