const std = @import("std");
const Allocator = std.mem.Allocator;
const Self = @This();

// ── Types ─────────────────────────────────────────────────────────────

pub const Node = struct {
    id: u16,
    name: []const u8, // filename stem ("daily-note")
    path: []const u8, // relative path ("notes/daily-note.md")
    out_links: []u16, // nodes this file links TO
    in_links: []u16, // nodes that link TO this file (backlinks)
};

pub const Edge = struct {
    from: u16,
    to: u16,
};

// ── State ─────────────────────────────────────────────────────────────

allocator: Allocator,
nodes: std.ArrayList(Node) = .{},
edges: std.ArrayList(Edge) = .{},
name_to_id: std.StringHashMap(u16),

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: Allocator) Self {
    return .{
        .allocator = allocator,
        .name_to_id = std.StringHashMap(u16).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    for (self.nodes.items) |node| {
        self.allocator.free(node.name);
        self.allocator.free(node.path);
        if (node.out_links.len > 0) self.allocator.free(node.out_links);
        if (node.in_links.len > 0) self.allocator.free(node.in_links);
    }
    self.nodes.deinit(self.allocator);
    self.edges.deinit(self.allocator);
    self.name_to_id.deinit();
}

// ── Graph Building ────────────────────────────────────────────────────

pub fn addNode(self: *Self, name: []const u8, path: []const u8) !u16 {
    const id: u16 = @intCast(self.nodes.items.len);
    const owned_name = try self.allocator.dupe(u8, name);
    const owned_path = try self.allocator.dupe(u8, path);

    try self.nodes.append(self.allocator, .{
        .id = id,
        .name = owned_name,
        .path = owned_path,
        .out_links = &.{},
        .in_links = &.{},
    });

    try self.name_to_id.put(owned_name, id);
    return id;
}

pub fn addEdge(self: *Self, from: u16, to: u16) !void {
    for (self.edges.items) |e| {
        if (e.from == from and e.to == to) return;
    }
    try self.edges.append(self.allocator, .{ .from = from, .to = to });
}

/// Resolve a wiki-link text to a node id.
pub fn resolve(self: *Self, wiki_link_text: []const u8) ?u16 {
    const target = if (std.mem.lastIndexOfScalar(u8, wiki_link_text, '/')) |slash|
        wiki_link_text[slash + 1 ..]
    else
        wiki_link_text;

    const name = if (std.mem.indexOfScalar(u8, target, '|')) |pipe|
        target[0..pipe]
    else
        target;

    if (self.name_to_id.get(name)) |id| return id;

    for (self.nodes.items) |node| {
        if (std.ascii.eqlIgnoreCase(node.name, name)) return node.id;
    }

    return null;
}

/// Build in_links and out_links arrays from the edge list.
pub fn buildLinks(self: *Self) !void {
    const n = self.nodes.items.len;

    var out_counts = try self.allocator.alloc(usize, n);
    defer self.allocator.free(out_counts);
    var in_counts = try self.allocator.alloc(usize, n);
    defer self.allocator.free(in_counts);
    @memset(out_counts, 0);
    @memset(in_counts, 0);

    for (self.edges.items) |e| {
        out_counts[e.from] += 1;
        in_counts[e.to] += 1;
    }

    for (self.nodes.items, 0..) |*node, i| {
        if (node.out_links.len > 0) self.allocator.free(node.out_links);
        if (node.in_links.len > 0) self.allocator.free(node.in_links);
        node.out_links = try self.allocator.alloc(u16, out_counts[i]);
        node.in_links = try self.allocator.alloc(u16, in_counts[i]);
    }

    @memset(out_counts, 0);
    @memset(in_counts, 0);

    for (self.edges.items) |e| {
        self.nodes.items[e.from].out_links[out_counts[e.from]] = e.to;
        out_counts[e.from] += 1;
        self.nodes.items[e.to].in_links[in_counts[e.to]] = e.from;
        in_counts[e.to] += 1;
    }
}

pub fn getBacklinks(self: *Self, node_id: u16) []u16 {
    if (node_id >= self.nodes.items.len) return &.{};
    return self.nodes.items[node_id].in_links;
}

pub fn getOrphans(self: *Self) ![]u16 {
    var orphans: std.ArrayList(u16) = .{};
    for (self.nodes.items) |node| {
        if (node.in_links.len == 0 and node.out_links.len == 0) {
            try orphans.append(self.allocator, node.id);
        }
    }
    return orphans.toOwnedSlice(self.allocator);
}

/// BFS to find all neighbors within `depth` hops of `node_id`.
pub fn getNeighbors(self: *Self, node_id: u16, depth: u16) ![]u16 {
    if (node_id >= self.nodes.items.len) return &.{};

    const n = self.nodes.items.len;
    var visited = try self.allocator.alloc(bool, n);
    defer self.allocator.free(visited);
    @memset(visited, false);

    const QItem = struct { id: u16, d: u16 };
    var queue: std.ArrayList(QItem) = .{};
    defer queue.deinit(self.allocator);

    var result: std.ArrayList(u16) = .{};

    visited[node_id] = true;
    try queue.append(self.allocator, .{ .id = node_id, .d = 0 });

    while (queue.items.len > 0) {
        const item = queue.orderedRemove(0);
        try result.append(self.allocator, item.id);

        if (item.d >= depth) continue;

        const node = self.nodes.items[item.id];
        for (node.out_links) |next| {
            if (!visited[next]) {
                visited[next] = true;
                try queue.append(self.allocator, .{ .id = next, .d = item.d + 1 });
            }
        }
        for (node.in_links) |next| {
            if (!visited[next]) {
                visited[next] = true;
                try queue.append(self.allocator, .{ .id = next, .d = item.d + 1 });
            }
        }
    }

    return result.toOwnedSlice(self.allocator);
}

pub fn nodeCount(self: *Self) usize {
    return self.nodes.items.len;
}

pub fn edgeCount(self: *Self) usize {
    return self.edges.items.len;
}

// ── Tests ─────────────────────────────────────────────────────────────

test "add nodes and edges" {
    const allocator = std.testing.allocator;
    var graph = init(allocator);
    defer graph.deinit();

    const a = try graph.addNode("note-a", "notes/note-a.md");
    const b = try graph.addNode("note-b", "notes/note-b.md");
    const c = try graph.addNode("note-c", "note-c.md");

    try graph.addEdge(a, b);
    try graph.addEdge(a, c);
    try graph.addEdge(b, c);
    try graph.buildLinks();

    try std.testing.expectEqual(@as(usize, 3), graph.nodeCount());
    try std.testing.expectEqual(@as(usize, 3), graph.edgeCount());

    try std.testing.expectEqual(@as(usize, 2), graph.nodes.items[a].out_links.len);
    try std.testing.expectEqual(@as(usize, 1), graph.nodes.items[b].out_links.len);
    try std.testing.expectEqual(@as(usize, 0), graph.nodes.items[c].out_links.len);

    try std.testing.expectEqual(@as(usize, 0), graph.nodes.items[a].in_links.len);
    try std.testing.expectEqual(@as(usize, 1), graph.nodes.items[b].in_links.len);
    try std.testing.expectEqual(@as(usize, 2), graph.nodes.items[c].in_links.len);
}

test "resolve wiki-links" {
    const allocator = std.testing.allocator;
    var graph = init(allocator);
    defer graph.deinit();

    _ = try graph.addNode("daily-note", "notes/daily-note.md");
    _ = try graph.addNode("README", "README.md");

    try std.testing.expectEqual(@as(u16, 0), graph.resolve("daily-note").?);
    try std.testing.expectEqual(@as(u16, 1), graph.resolve("readme").?);
    try std.testing.expectEqual(@as(u16, 0), graph.resolve("daily-note|My Daily Note").?);
    try std.testing.expectEqual(@as(u16, 0), graph.resolve("notes/daily-note").?);
    try std.testing.expect(graph.resolve("nonexistent") == null);
}

test "duplicate edge prevention" {
    const allocator = std.testing.allocator;
    var graph = init(allocator);
    defer graph.deinit();

    const a = try graph.addNode("a", "a.md");
    const b = try graph.addNode("b", "b.md");
    try graph.addEdge(a, b);
    try graph.addEdge(a, b);
    try std.testing.expectEqual(@as(usize, 1), graph.edgeCount());
}

test "orphan detection" {
    const allocator = std.testing.allocator;
    var graph = init(allocator);
    defer graph.deinit();

    const a = try graph.addNode("a", "a.md");
    const b = try graph.addNode("b", "b.md");
    _ = try graph.addNode("orphan", "orphan.md");
    try graph.addEdge(a, b);
    try graph.buildLinks();

    const orphans = try graph.getOrphans();
    defer allocator.free(orphans);
    try std.testing.expectEqual(@as(usize, 1), orphans.len);
    try std.testing.expectEqual(@as(u16, 2), orphans[0]);
}

test "BFS neighbors" {
    const allocator = std.testing.allocator;
    var graph = init(allocator);
    defer graph.deinit();

    const a = try graph.addNode("a", "a.md");
    const b = try graph.addNode("b", "b.md");
    const c = try graph.addNode("c", "c.md");
    _ = try graph.addNode("d", "d.md");
    try graph.addEdge(a, b);
    try graph.addEdge(b, c);
    try graph.addEdge(c, 3);
    try graph.buildLinks();

    const n1 = try graph.getNeighbors(a, 1);
    defer allocator.free(n1);
    try std.testing.expectEqual(@as(usize, 2), n1.len);

    const n2 = try graph.getNeighbors(a, 2);
    defer allocator.free(n2);
    try std.testing.expectEqual(@as(usize, 3), n2.len);
}
