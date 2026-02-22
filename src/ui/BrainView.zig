const std = @import("std");
const Renderer = @import("../Renderer.zig");
const Terminal = @import("../Terminal.zig");
const Input = @import("../Input.zig");
const Graph = @import("../brain/Graph.zig");
const Layout = @import("Layout.zig");
const Self = @This();

const Color = Terminal.Color;
const Style = Terminal.Style;

// ── State ─────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
graph: ?*Graph = null,
positions: ?[]Pos = null,
selected_node: ?u16 = null,
current_file_node: ?u16 = null,
viewport_x: f32 = 0,
viewport_y: f32 = 0,
zoom: f32 = 1.0,
local_mode: bool = false,
settled: bool = false,
iteration: u32 = 0,

const Pos = struct { x: f32, y: f32 };

const MAX_ITERATIONS: u32 = 100;
const REPULSION: f32 = 500.0;
const ATTRACTION: f32 = 0.05;
const DAMPING: f32 = 0.9;
const CENTER_PULL: f32 = 0.01;
const MIN_DIST: f32 = 1.0;

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    if (self.positions) |pos| self.allocator.free(pos);
}

// ── Graph Management ──────────────────────────────────────────────────

pub fn setGraph(self: *Self, graph: *Graph) void {
    if (self.positions) |pos| self.allocator.free(pos);
    self.positions = null;
    self.graph = graph;
    self.settled = false;
    self.iteration = 0;
    self.selected_node = if (graph.nodeCount() > 0) 0 else null;
    self.initPositions() catch {};
}

pub fn setCurrentFile(self: *Self, name: []const u8) void {
    if (self.graph) |g| {
        self.current_file_node = g.resolve(name);
    }
}

fn initPositions(self: *Self) !void {
    const g = self.graph orelse return;
    const n = g.nodeCount();
    if (n == 0) return;

    self.positions = try self.allocator.alloc(Pos, n);
    const pos = self.positions.?;

    // Place nodes in a circle for a stable starting layout
    const radius: f32 = @as(f32, @floatFromInt(@min(n * 3, 40)));
    for (pos, 0..) |*p, i| {
        const angle: f32 = @as(f32, @floatFromInt(i)) * (2.0 * std.math.pi / @as(f32, @floatFromInt(n)));
        p.x = radius * @cos(angle);
        p.y = radius * @sin(angle);
    }
}

// ── Force-Directed Layout ─────────────────────────────────────────────

pub fn stepLayout(self: *Self) void {
    if (self.settled or self.iteration >= MAX_ITERATIONS) return;
    const g = self.graph orelse return;
    const pos = self.positions orelse return;
    const n = g.nodeCount();
    if (n <= 1) {
        self.settled = true;
        return;
    }

    var forces = self.allocator.alloc(Pos, n) catch return;
    defer self.allocator.free(forces);
    @memset(forces, Pos{ .x = 0, .y = 0 });

    // Repulsion between all pairs
    for (0..n) |i| {
        for (i + 1..n) |j| {
            var dx = pos[j].x - pos[i].x;
            var dy = pos[j].y - pos[i].y;
            var dist = @sqrt(dx * dx + dy * dy);
            if (dist < MIN_DIST) {
                dist = MIN_DIST;
                dx = 0.5;
                dy = 0.5;
            }
            const force = REPULSION / (dist * dist);
            const fx = (dx / dist) * force;
            const fy = (dy / dist) * force;
            forces[i].x -= fx;
            forces[i].y -= fy;
            forces[j].x += fx;
            forces[j].y += fy;
        }
    }

    // Attraction along edges
    for (g.edges.items) |edge| {
        const dx = pos[edge.to].x - pos[edge.from].x;
        const dy = pos[edge.to].y - pos[edge.from].y;
        const fx = dx * ATTRACTION;
        const fy = dy * ATTRACTION;
        forces[edge.from].x += fx;
        forces[edge.from].y += fy;
        forces[edge.to].x -= fx;
        forces[edge.to].y -= fy;
    }

    // Center pull
    for (0..n) |i| {
        forces[i].x -= pos[i].x * CENTER_PULL;
        forces[i].y -= pos[i].y * CENTER_PULL;
    }

    // Apply forces with damping
    var max_move: f32 = 0;
    for (0..n) |i| {
        const fx = forces[i].x * DAMPING;
        const fy = forces[i].y * DAMPING;
        pos[i].x += fx;
        pos[i].y += fy;
        const move = @abs(fx) + @abs(fy);
        if (move > max_move) max_move = move;
    }

    self.iteration += 1;
    if (max_move < 0.1 or self.iteration >= MAX_ITERATIONS) {
        self.settled = true;
    }
}

// ── Input Handling ────────────────────────────────────────────────────

pub fn handleKey(self: *Self, key: Input.Key) bool {
    const g = self.graph orelse return false;
    const n = g.nodeCount();
    if (n == 0) return false;

    if (key.code == .char) {
        switch (key.code.char) {
            'j' => {
                self.moveSelection(1, n);
                return true;
            },
            'k' => {
                self.moveSelection(-1, n);
                return true;
            },
            'f' => {
                self.local_mode = !self.local_mode;
                return true;
            },
            '+', '=' => {
                self.zoom = @min(self.zoom + 0.2, 3.0);
                return true;
            },
            '-' => {
                self.zoom = @max(self.zoom - 0.2, 0.3);
                return true;
            },
            'h' => {
                self.viewport_x -= 3;
                return true;
            },
            'l' => {
                self.viewport_x += 3;
                return true;
            },
            else => {},
        }
    } else if (key.code == .down) {
        self.moveSelection(1, n);
        return true;
    } else if (key.code == .up) {
        self.moveSelection(-1, n);
        return true;
    }
    return false;
}

fn moveSelection(self: *Self, delta: i32, n: usize) void {
    const cur: i32 = if (self.selected_node) |s| @intCast(s) else 0;
    const nn: i32 = @intCast(n);
    const next = @mod(cur + delta + nn, nn);
    self.selected_node = @intCast(next);
}

// ── Rendering ─────────────────────────────────────────────────────────

pub fn render(self: *Self, renderer: *Renderer, rect: Layout.Rect) void {
    const tc = @import("../themes.zig").currentColors();
    const g = self.graph orelse {
        renderer.putStr(rect.x + 2, rect.y + 2, "No graph loaded", tc.text, .default, .{});
        return;
    };

    if (g.nodeCount() == 0) {
        renderer.putStr(rect.x + 2, rect.y + 2, "No notes found", tc.text, .default, .{});
        return;
    }

    // Run a few layout steps per frame
    if (!self.settled) {
        for (0..3) |_| self.stepLayout();
    }

    const pos = self.positions orelse return;
    const cx: f32 = @as(f32, @floatFromInt(rect.w)) / 2.0;
    const cy: f32 = @as(f32, @floatFromInt(rect.h)) / 2.0;

    // Determine visible nodes
    const visible = self.getVisibleNodes(g) catch return;
    defer self.allocator.free(visible);

    // Draw edges first (behind nodes)
    for (g.edges.items) |edge| {
        if (!isVisible(visible, edge.from) or !isVisible(visible, edge.to)) continue;
        const x1 = self.worldToScreenX(pos[edge.from].x, cx, rect.x);
        const y1 = self.worldToScreenY(pos[edge.from].y, cy, rect.y);
        const x2 = self.worldToScreenX(pos[edge.to].x, cx, rect.x);
        const y2 = self.worldToScreenY(pos[edge.to].y, cy, rect.y);
        self.drawEdge(renderer, x1, y1, x2, y2, rect, .{ .rgb = .{ .r = 88, .g = 166, .b = 255 } });
    }

    // Draw nodes
    for (visible) |nid| {
        const node = g.nodes.items[nid];
        const sx = self.worldToScreenX(pos[nid].x, cx, rect.x);
        const sy = self.worldToScreenY(pos[nid].y, cy, rect.y);

        if (sx < rect.x or sx >= rect.x + rect.w or sy < rect.y or sy >= rect.y + rect.h) continue;

        const is_selected = self.selected_node != null and self.selected_node.? == nid;
        const is_current = self.current_file_node != null and self.current_file_node.? == nid;

        const fg: Color = if (is_current) .bright_green else if (is_selected) .bright_cyan else tc.text;
        const style: Style = if (is_selected or is_current) .{ .bold = true } else .{};

        // Draw node label
        const max_name_len = @min(node.name.len, @as(usize, @intCast(rect.x + rect.w -| sx -| 1)));
        if (max_name_len > 0) {
            renderer.putStr(sx, sy, node.name[0..max_name_len], fg, .default, style);
        }

        // Draw dot marker at node position
        if (sx > rect.x) {
            const marker: u21 = if (is_current) 0x25C9 else if (is_selected) 0x25CB else 0x2022; // ◉ ○ •
            renderer.putChar(sx -| 1, sy, marker, fg, .default, style);
        }
    }

    // Status bar at bottom of rect
    self.renderStatus(renderer, g, rect, tc);
}

fn renderStatus(self: *Self, renderer: *Renderer, g: *Graph, rect: Layout.Rect, tc: anytype) void {
    const status_y = rect.y + rect.h -| 1;
    if (status_y <= rect.y) return;

    var buf: [128]u8 = undefined;
    if (self.selected_node) |sel| {
        const node = g.nodes.items[sel];
        const msg = std.fmt.bufPrint(&buf, " {s}  out:{d} in:{d} ", .{
            node.name,
            node.out_links.len,
            node.in_links.len,
        }) catch return;
        renderer.putStr(rect.x + 1, status_y, msg, tc.title_fg, .default, .{ .bold = true });
    }

    // Mode indicator on right
    const mode = if (self.local_mode) " LOCAL " else " GRAPH ";
    const mode_x = rect.x + rect.w -| @as(u16, @intCast(mode.len)) -| 1;
    renderer.putStr(mode_x, status_y, mode, .bright_magenta, .default, .{ .bold = true });
}

fn getVisibleNodes(self: *Self, g: *Graph) ![]u16 {
    if (self.local_mode) {
        if (self.current_file_node orelse self.selected_node) |center| {
            return g.getNeighbors(center, 2);
        }
    }
    // Full graph: return all node ids
    const all = try self.allocator.alloc(u16, g.nodeCount());
    for (all, 0..) |*v, i| v.* = @intCast(i);
    return all;
}

fn isVisible(visible: []u16, id: u16) bool {
    for (visible) |v| {
        if (v == id) return true;
    }
    return false;
}

fn worldToScreenX(self: *Self, wx: f32, cx: f32, base_x: u16) u16 {
    const sx = (wx * self.zoom - self.viewport_x) + cx;
    if (sx < 0) return base_x;
    return base_x +| @as(u16, @intFromFloat(@min(sx, 500)));
}

fn worldToScreenY(self: *Self, wy: f32, cy: f32, base_y: u16) u16 {
    const sy = (wy * self.zoom * 0.5 - self.viewport_y) + cy; // 0.5 aspect ratio correction
    if (sy < 0) return base_y;
    return base_y +| @as(u16, @intFromFloat(@min(sy, 500)));
}

fn drawEdge(self: *Self, renderer: *Renderer, x1: u16, y1: u16, x2: u16, y2: u16, rect: Layout.Rect, color: Color) void {
    _ = self;
    // Simple dot trail between two points (Bresenham-lite)
    const dx: i32 = @as(i32, @intCast(x2)) - @as(i32, @intCast(x1));
    const dy: i32 = @as(i32, @intCast(y2)) - @as(i32, @intCast(y1));
    const steps: u32 = @intCast(@max(@abs(dx), @abs(dy)));
    if (steps == 0) return;

    const sx: f32 = @as(f32, @floatFromInt(dx)) / @as(f32, @floatFromInt(steps));
    const sy: f32 = @as(f32, @floatFromInt(dy)) / @as(f32, @floatFromInt(steps));

    var px: f32 = @floatFromInt(x1);
    var py: f32 = @floatFromInt(y1);

    const max_steps = @min(steps, 200); // cap to prevent huge draws
    for (0..max_steps) |_| {
        const ix: u16 = @intFromFloat(@max(@min(px, @as(f32, @floatFromInt(rect.x + rect.w -| 1))), @as(f32, @floatFromInt(rect.x))));
        const iy: u16 = @intFromFloat(@max(@min(py, @as(f32, @floatFromInt(rect.y + rect.h -| 1))), @as(f32, @floatFromInt(rect.y))));
        renderer.putChar(ix, iy, 0xB7, color, .default, .{ .dim = true }); // ·
        px += sx;
        py += sy;
    }
}

// ── Tests ─────────────────────────────────────────────────────────────

test "init and deinit" {
    const allocator = std.testing.allocator;
    var view = init(allocator);
    defer view.deinit();
    try std.testing.expect(view.graph == null);
}

test "force layout converges" {
    const allocator = std.testing.allocator;
    var graph = Graph.init(allocator);
    defer graph.deinit();

    const a = try graph.addNode("a", "a.md");
    const b = try graph.addNode("b", "b.md");
    const c = try graph.addNode("c", "c.md");
    try graph.addEdge(a, b);
    try graph.addEdge(b, c);
    try graph.buildLinks();

    var view = init(allocator);
    defer view.deinit();
    view.setGraph(&graph);

    // Run until settled
    for (0..200) |_| view.stepLayout();
    try std.testing.expect(view.settled);
}

test "node selection wraps" {
    const allocator = std.testing.allocator;
    var graph = Graph.init(allocator);
    defer graph.deinit();
    _ = try graph.addNode("a", "a.md");
    _ = try graph.addNode("b", "b.md");
    _ = try graph.addNode("c", "c.md");
    try graph.buildLinks();

    var view = init(allocator);
    defer view.deinit();
    view.setGraph(&graph);

    try std.testing.expectEqual(@as(u16, 0), view.selected_node.?);
    _ = view.handleKey(.{ .code = .{ .char = 'j' } });
    try std.testing.expectEqual(@as(u16, 1), view.selected_node.?);
    _ = view.handleKey(.{ .code = .{ .char = 'k' } });
    try std.testing.expectEqual(@as(u16, 0), view.selected_node.?);
    _ = view.handleKey(.{ .code = .{ .char = 'k' } }); // wrap to end
    try std.testing.expectEqual(@as(u16, 2), view.selected_node.?);
}
