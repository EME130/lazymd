const std = @import("std");
const Graph = @import("Graph.zig");
const Allocator = std.mem.Allocator;

const MAX_FILE_SIZE = 64 * 1024;

/// Recursively scan a vault directory for .md/.rndm files,
/// extract [[wiki-links]], and build a Graph.
pub fn scan(allocator: Allocator, root_path: []const u8) !Graph {
    var graph = Graph.init(allocator);
    errdefer graph.deinit();

    // Phase 1: Collect all markdown files and create nodes
    var file_paths: std.ArrayList([]const u8) = .{};
    defer {
        for (file_paths.items) |p| allocator.free(p);
        file_paths.deinit(allocator);
    }

    try walkDir(allocator, root_path, "", &file_paths);

    for (file_paths.items) |rel_path| {
        const stem = extractStem(rel_path);
        _ = try graph.addNode(stem, rel_path);
    }

    // Phase 2: Read each file, extract links, create edges
    for (file_paths.items, 0..) |rel_path, node_idx| {
        const content = readFile(allocator, root_path, rel_path) orelse continue;
        defer allocator.free(content);

        var links = try extractWikiLinks(allocator, content);
        defer {
            for (links.items) |link| allocator.free(link);
            links.deinit(allocator);
        }

        for (links.items) |link_target| {
            if (graph.resolve(link_target)) |target_id| {
                try graph.addEdge(@intCast(node_idx), target_id);
            }
        }
    }

    // Phase 3: Build backlink/outlink arrays
    try graph.buildLinks();

    return graph;
}

/// Extract all [[wiki-link]] targets from content.
pub fn extractWikiLinks(allocator: Allocator, content: []const u8) !std.ArrayList([]const u8) {
    var links: std.ArrayList([]const u8) = .{};
    errdefer {
        for (links.items) |l| allocator.free(l);
        links.deinit(allocator);
    }

    var i: usize = 0;
    while (i + 3 < content.len) : (i += 1) {
        if (content[i] == '[' and content[i + 1] == '[') {
            const start = i + 2;
            if (findLinkEnd(content, start)) |end| {
                const raw = content[start..end];
                const target = if (std.mem.indexOfScalar(u8, raw, '|')) |pipe|
                    raw[0..pipe]
                else
                    raw;

                if (target.len > 0) {
                    try links.append(allocator, try allocator.dupe(u8, target));
                }
                i = end + 1;
            }
        }
    }

    return links;
}

// ── Internal Helpers ──────────────────────────────────────────────────

fn walkDir(allocator: Allocator, root: []const u8, prefix: []const u8, out: *std.ArrayList([]const u8)) !void {
    const full_path = if (prefix.len > 0)
        try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root, prefix })
    else
        try allocator.dupe(u8, root);
    defer allocator.free(full_path);

    var dir = std.fs.cwd().openDir(full_path, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.name[0] == '.') continue;

        const rel = if (prefix.len > 0)
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ prefix, entry.name })
        else
            try allocator.dupe(u8, entry.name);

        if (entry.kind == .directory) {
            defer allocator.free(rel);
            try walkDir(allocator, root, rel, out);
        } else if (entry.kind == .file) {
            if (isMarkdown(entry.name)) {
                try out.append(allocator, rel);
            } else {
                allocator.free(rel);
            }
        } else {
            allocator.free(rel);
        }
    }
}

fn readFile(allocator: Allocator, root: []const u8, rel_path: []const u8) ?[]const u8 {
    const full_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ root, rel_path }) catch return null;
    defer allocator.free(full_path);

    const file = std.fs.cwd().openFile(full_path, .{}) catch return null;
    defer file.close();

    const stat = file.stat() catch return null;
    if (stat.size > MAX_FILE_SIZE) return null;

    return file.readToEndAlloc(allocator, MAX_FILE_SIZE) catch null;
}

fn findLinkEnd(content: []const u8, start: usize) ?usize {
    var i = start;
    while (i + 1 < content.len) : (i += 1) {
        if (content[i] == ']' and content[i + 1] == ']') return i;
        if (content[i] == '\n') return null;
    }
    return null;
}

fn extractStem(path: []const u8) []const u8 {
    const basename = if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash|
        path[slash + 1 ..]
    else
        path;
    return if (std.mem.lastIndexOfScalar(u8, basename, '.')) |dot|
        basename[0..dot]
    else
        basename;
}

fn isMarkdown(name: []const u8) bool {
    return std.mem.endsWith(u8, name, ".md") or std.mem.endsWith(u8, name, ".rndm");
}

// ── Tests ─────────────────────────────────────────────────────────────

test "extract wiki-links" {
    const allocator = std.testing.allocator;
    var links = try extractWikiLinks(allocator, "See [[foo]] and [[bar|Bar Note]] here");
    defer {
        for (links.items) |l| allocator.free(l);
        links.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 2), links.items.len);
    try std.testing.expectEqualStrings("foo", links.items[0]);
    try std.testing.expectEqualStrings("bar", links.items[1]);
}

test "extract wiki-links ignores broken" {
    const allocator = std.testing.allocator;
    var links = try extractWikiLinks(allocator, "[[good]] and [[broken\nlink]] end");
    defer {
        for (links.items) |l| allocator.free(l);
        links.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), links.items.len);
    try std.testing.expectEqualStrings("good", links.items[0]);
}

test "extract stem" {
    try std.testing.expectEqualStrings("daily-note", extractStem("notes/daily-note.md"));
    try std.testing.expectEqualStrings("README", extractStem("README.md"));
    try std.testing.expectEqualStrings("test", extractStem("a/b/c/test.rndm"));
    try std.testing.expectEqualStrings("noext", extractStem("noext"));
}

test "isMarkdown" {
    try std.testing.expect(isMarkdown("test.md"));
    try std.testing.expect(isMarkdown("test.rndm"));
    try std.testing.expect(!isMarkdown("test.txt"));
    try std.testing.expect(!isMarkdown("test.zig"));
}
