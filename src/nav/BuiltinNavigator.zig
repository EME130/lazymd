const std = @import("std");
const Allocator = std.mem.Allocator;
const Buffer = @import("../Buffer.zig");
const Navigator = @import("Navigator.zig");

const Self = @This();

// ── State ────────────────────────────────────────────────────────────

buffer: *Buffer,

// ── Init ─────────────────────────────────────────────────────────────

pub fn init(buffer: *Buffer) Self {
    return .{ .buffer = buffer };
}

pub fn navigator(self: *Self) Navigator {
    return .{
        .ptr = @ptrCast(self),
        .vtable = &vtable,
    };
}

const vtable = Navigator.VTable{
    .readSection = readSectionImpl,
    .listTasks = listTasksImpl,
    .updateTask = updateTaskImpl,
    .getBreadcrumb = getBreadcrumbImpl,
    .moveSection = moveSectionImpl,
    .readSectionRange = readSectionRangeImpl,
};

// ── Heading Helpers ──────────────────────────────────────────────────

const HeadingMatch = struct {
    line: usize,
    level: usize,
    title: []const u8,
};

fn parseHeading(line_text: []const u8) ?HeadingMatch {
    if (line_text.len == 0 or line_text[0] != '#') return null;
    var level: usize = 0;
    while (level < line_text.len and line_text[level] == '#') level += 1;
    if (level > 6 or level >= line_text.len or line_text[level] != ' ') return null;
    const title = std.mem.trimRight(u8, line_text[level + 1 ..], " \t\r");
    return .{ .line = 0, .level = level, .title = title };
}

/// Find section boundaries: start line (heading) and end line (exclusive).
fn findSectionBounds(buf: *Buffer, heading_line: usize, heading_level: usize) struct { usize, usize } {
    const line_count = buf.lineCount();
    var end: usize = line_count;
    var i: usize = heading_line + 1;
    while (i < line_count) : (i += 1) {
        const line = buf.getLine(i);
        if (parseHeading(line)) |h| {
            if (h.level <= heading_level) {
                end = i;
                break;
            }
        }
    }
    return .{ heading_line, end };
}

/// Resolve a slash-separated heading path (e.g. "Plan/Step 1/Subtask A").
/// Returns the line number and level of the matched heading.
fn resolveHeadingPath(buf: *Buffer, path: []const u8) ?HeadingMatch {
    const line_count = buf.lineCount();

    // Split path by '/'
    var segments_buf: [32][]const u8 = undefined;
    var seg_count: usize = 0;
    var iter = std.mem.splitScalar(u8, path, '/');
    while (iter.next()) |seg| {
        const trimmed = std.mem.trim(u8, seg, " \t");
        if (trimmed.len == 0) continue;
        if (seg_count >= 32) return null;
        segments_buf[seg_count] = trimmed;
        seg_count += 1;
    }
    if (seg_count == 0) return null;
    const segments = segments_buf[0..seg_count];

    // Walk through headings matching each segment in order
    var seg_idx: usize = 0;
    var search_start: usize = 0;
    var parent_level: usize = 0;
    var last_match: ?HeadingMatch = null;

    while (seg_idx < segments.len) {
        var found = false;
        var i: usize = search_start;
        while (i < line_count) : (i += 1) {
            const line = buf.getLine(i);
            if (parseHeading(line)) |h| {
                // If we're past root level, only match children of current parent
                if (seg_idx > 0 and h.level <= parent_level) break;

                if (std.ascii.eqlIgnoreCase(h.title, segments[seg_idx])) {
                    last_match = .{ .line = i, .level = h.level, .title = h.title };
                    parent_level = h.level;
                    search_start = i + 1;
                    seg_idx += 1;
                    found = true;
                    break;
                }
            }
        }
        if (!found) return null;
    }

    return last_match;
}

/// Build breadcrumb for a given line by walking backwards through headings.
fn buildBreadcrumb(buf: *Buffer, allocator: Allocator, target_line: usize) ![]const u8 {
    // Collect heading stack up to target_line
    var crumbs_buf: [32][]const u8 = undefined;
    var levels_buf: [32]usize = undefined;
    var crumb_count: usize = 0;

    const line_count = buf.lineCount();
    var i: usize = 0;
    while (i < line_count and i <= target_line) : (i += 1) {
        const line = buf.getLine(i);
        if (parseHeading(line)) |h| {
            // Pop any headings at same or deeper level
            while (crumb_count > 0 and levels_buf[crumb_count - 1] >= h.level) {
                crumb_count -= 1;
            }
            if (crumb_count < 32) {
                crumbs_buf[crumb_count] = h.title;
                levels_buf[crumb_count] = h.level;
                crumb_count += 1;
            }
        }
    }

    if (crumb_count == 0) return try allocator.dupe(u8, "(no heading)");

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(allocator);
    for (crumbs_buf[0..crumb_count], 0..) |crumb, idx| {
        if (idx > 0) try w.writeAll(" > ");
        try w.writeAll(crumb);
    }
    return result.toOwnedSlice(allocator);
}

// ── VTable Implementations ───────────────────────────────────────────

fn readSectionImpl(ctx: *anyopaque, allocator: Allocator, heading_path: []const u8) anyerror!Navigator.SectionContent {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const buf = self.buffer;

    const match = resolveHeadingPath(buf, heading_path) orelse return error.HeadingNotFound;
    const bounds = findSectionBounds(buf, match.line, match.level);
    const start_line = bounds[0];
    const end_line = bounds[1];

    // Build content string (heading + body)
    var result: std.ArrayList(u8) = .{};
    const w = result.writer(allocator);
    var i: usize = start_line;
    while (i < end_line) : (i += 1) {
        const line = buf.getLine(i);
        try w.writeAll(line);
        if (i + 1 < end_line) try w.writeByte('\n');
    }

    return .{
        .heading_line = start_line,
        .level = match.level,
        .title = match.title,
        .content = try result.toOwnedSlice(allocator),
        .start_line = @min(start_line + 1, end_line),
        .end_line = end_line,
    };
}

fn listTasksImpl(ctx: *anyopaque, allocator: Allocator, section: ?[]const u8, status: u8) anyerror![]Navigator.TaskItem {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const buf = self.buffer;

    // Determine line range
    var range_start: usize = 0;
    var range_end: usize = buf.lineCount();

    if (section) |sec_path| {
        const match = resolveHeadingPath(buf, sec_path) orelse return error.HeadingNotFound;
        const bounds = findSectionBounds(buf, match.line, match.level);
        range_start = bounds[0];
        range_end = bounds[1];
    }

    var tasks: std.ArrayList(Navigator.TaskItem) = .{};

    var i: usize = range_start;
    while (i < range_end) : (i += 1) {
        const line = buf.getLine(i);
        const trimmed = std.mem.trimLeft(u8, line, " \t");

        // Match "- [ ] " or "- [x] " or "- [X] " or "* [ ] " etc.
        if (trimmed.len >= 6 and
            (trimmed[0] == '-' or trimmed[0] == '*' or trimmed[0] == '+') and
            trimmed[1] == ' ' and trimmed[2] == '[')
        {
            const check_char = trimmed[3];
            const is_done = (check_char == 'x' or check_char == 'X');
            const is_pending = (check_char == ' ');

            if ((is_done or is_pending) and trimmed[4] == ']') {
                // Filter by status: 0=all, 1=pending, 2=done
                if (status == 1 and is_done) continue;
                if (status == 2 and !is_done) continue;

                const text_start: usize = if (trimmed.len > 5 and trimmed[5] == ' ') 6 else 5;
                const task_text = if (text_start < trimmed.len) trimmed[text_start..] else "";

                const breadcrumb = try buildBreadcrumb(buf, allocator, i);

                try tasks.append(allocator, .{
                    .line = i,
                    .done = is_done,
                    .text = task_text,
                    .breadcrumb = breadcrumb,
                });
            }
        }
    }

    return tasks.toOwnedSlice(allocator);
}

fn updateTaskImpl(ctx: *anyopaque, allocator: Allocator, line: usize, done: bool) anyerror![]const u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const buf = self.buffer;

    if (line >= buf.lineCount()) return error.InvalidArgument;

    const line_text = buf.getLine(line);
    const trimmed = std.mem.trimLeft(u8, line_text, " \t");
    const indent_len = line_text.len - trimmed.len;

    if (trimmed.len < 6 or
        (trimmed[0] != '-' and trimmed[0] != '*' and trimmed[0] != '+') or
        trimmed[1] != ' ' or trimmed[2] != '[' or trimmed[4] != ']')
    {
        return error.InvalidArgument;
    }

    const check_char = trimmed[3];
    if (check_char != ' ' and check_char != 'x' and check_char != 'X') return error.InvalidArgument;

    // Build new line
    const new_check: u8 = if (done) 'x' else ' ';
    const new_line = try std.fmt.allocPrint(allocator, "{s}{c} [{c}]{s}\n", .{
        line_text[0..indent_len],
        trimmed[0],
        new_check,
        trimmed[4..],
    });
    defer allocator.free(new_line);

    // Replace the line in the buffer
    const start_offset = buf.posToOffset(line, 0);
    const end_offset = if (line + 1 < buf.lineCount())
        buf.posToOffset(line + 1, 0)
    else
        buf.length();

    if (end_offset > start_offset) {
        try buf.deleteRange(start_offset, end_offset - start_offset);
    }
    try buf.insertSlice(start_offset, new_line);

    // Return the updated line (without trailing newline)
    const display = std.mem.trimRight(u8, new_line, "\n");
    return try allocator.dupe(u8, display);
}

fn getBreadcrumbImpl(ctx: *anyopaque, allocator: Allocator, line: usize) anyerror![]const u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (line >= self.buffer.lineCount()) return error.InvalidArgument;
    return buildBreadcrumb(self.buffer, allocator, line);
}

fn moveSectionImpl(ctx: *anyopaque, allocator: Allocator, heading: []const u8, target: []const u8, before: bool) anyerror![]const u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const buf = self.buffer;
    const line_count = buf.lineCount();

    // Find source section
    var src_line: ?usize = null;
    var src_level: usize = 0;
    var i: usize = 0;
    while (i < line_count) : (i += 1) {
        const line = buf.getLine(i);
        if (parseHeading(line)) |h| {
            if (std.ascii.eqlIgnoreCase(h.title, heading)) {
                src_line = i;
                src_level = h.level;
                break;
            }
        }
    }
    const src_start = src_line orelse return error.HeadingNotFound;
    const src_bounds = findSectionBounds(buf, src_start, src_level);
    const src_end = src_bounds[1];

    // Find target section
    var tgt_line: ?usize = null;
    var tgt_level: usize = 0;
    i = 0;
    while (i < line_count) : (i += 1) {
        const line = buf.getLine(i);
        if (parseHeading(line)) |h| {
            if (std.ascii.eqlIgnoreCase(h.title, target)) {
                tgt_line = i;
                tgt_level = h.level;
                break;
            }
        }
    }
    const tgt_start = tgt_line orelse return error.HeadingNotFound;

    // Determine insertion point
    const insert_line = if (before) tgt_start else findSectionBounds(buf, tgt_start, tgt_level)[1];

    // Extract source section text
    var section_text: std.ArrayList(u8) = .{};
    const w = section_text.writer(allocator);
    i = src_start;
    while (i < src_end) : (i += 1) {
        const line = buf.getLine(i);
        try w.writeAll(line);
        try w.writeByte('\n');
    }
    const extracted = try section_text.toOwnedSlice(allocator);
    defer allocator.free(extracted);

    // Delete source first, then insert at adjusted position
    // If source is before insert point, adjust insert after deletion
    const src_start_offset = buf.posToOffset(src_start, 0);
    const src_end_offset = if (src_end < buf.lineCount()) buf.posToOffset(src_end, 0) else buf.length();
    const src_byte_len = src_end_offset - src_start_offset;
    const src_line_count = src_end - src_start;

    try buf.deleteRange(src_start_offset, src_byte_len);

    // Adjust insert line after deletion
    const adj_insert_line = if (insert_line > src_start)
        insert_line - src_line_count
    else
        insert_line;

    const insert_offset = if (adj_insert_line < buf.lineCount())
        buf.posToOffset(adj_insert_line, 0)
    else
        buf.length();

    try buf.insertSlice(insert_offset, extracted);

    // Report new location
    const new_end = adj_insert_line + src_line_count;
    return std.fmt.allocPrint(allocator, "Moved '{s}' to lines {}-{}", .{
        heading,
        adj_insert_line + 1,
        new_end,
    });
}

fn readSectionRangeImpl(ctx: *anyopaque, allocator: Allocator, heading_path: []const u8, start_offset_opt: ?usize, end_offset_opt: ?usize) anyerror![]const u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const buf = self.buffer;

    const match = resolveHeadingPath(buf, heading_path) orelse return error.HeadingNotFound;
    const bounds = findSectionBounds(buf, match.line, match.level);
    const section_start = bounds[0];
    const section_end = bounds[1];

    const start_off = start_offset_opt orelse 0;
    const abs_start = @min(section_start + start_off, section_end);
    const abs_end = if (end_offset_opt) |eo| @min(section_start + eo, section_end) else section_end;

    if (abs_start >= abs_end) return try allocator.dupe(u8, "(empty range)");

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(allocator);
    var i: usize = abs_start;
    while (i < abs_end) : (i += 1) {
        const line = buf.getLine(i);
        try w.print("L{}: {s}\n", .{ i + 1, line });
    }

    return result.toOwnedSlice(allocator);
}

// ── Tests ────────────────────────────────────────────────────────────

test "resolve heading path - simple" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Plan\nSome text\n## Step 1\nContent\n### Subtask A\nDetails");

    const match = resolveHeadingPath(&buffer, "Plan/Step 1/Subtask A").?;
    try std.testing.expectEqual(@as(usize, 4), match.line);
    try std.testing.expectEqual(@as(usize, 3), match.level);
}

test "resolve heading path - not found" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Plan\n## Step 1");

    try std.testing.expect(resolveHeadingPath(&buffer, "Plan/Nonexistent") == null);
}

test "read section" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Plan\nIntro\n## Step 1\nContent 1\n## Step 2\nContent 2");

    var nav = init(&buffer);
    const section = try nav.navigator().readSection(allocator, "Plan/Step 1");
    defer allocator.free(section.content);

    try std.testing.expectEqual(@as(usize, 2), section.heading_line);
    try std.testing.expectEqual(@as(usize, 2), section.level);
    try std.testing.expect(std.mem.indexOf(u8, section.content, "Content 1") != null);
    // Should NOT contain Step 2's content
    try std.testing.expect(std.mem.indexOf(u8, section.content, "Content 2") == null);
}

test "list tasks" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Plan\n- [x] Done task\n- [ ] Pending task\nSome text\n- [ ] Another pending");

    var nav = init(&buffer);
    const all = try nav.navigator().listTasks(allocator, null, 0);
    defer {
        for (all) |t| allocator.free(t.breadcrumb);
        allocator.free(all);
    }
    try std.testing.expectEqual(@as(usize, 3), all.len);
    try std.testing.expect(all[0].done);
    try std.testing.expect(!all[1].done);

    // Filter pending only
    const pending = try nav.navigator().listTasks(allocator, null, 1);
    defer {
        for (pending) |t| allocator.free(t.breadcrumb);
        allocator.free(pending);
    }
    try std.testing.expectEqual(@as(usize, 2), pending.len);
}

test "update task" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Plan\n- [ ] My task\nEnd");

    var nav = init(&buffer);
    const result = try nav.navigator().updateTask(allocator, 1, true);
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "[x]") != null);
    // Verify buffer was updated
    const line = buffer.getLine(1);
    try std.testing.expect(std.mem.indexOf(u8, line, "[x]") != null);
}

test "get breadcrumb" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Doc\n## Section A\n### Sub\nContent here");

    var nav = init(&buffer);
    const bc = try nav.navigator().getBreadcrumb(allocator, 3);
    defer allocator.free(bc);
    try std.testing.expectEqualStrings("Doc > Section A > Sub", bc);
}

test "build breadcrumb - no heading" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "Just some text\nNo headings");

    const bc = try buildBreadcrumb(&buffer, allocator, 0);
    defer allocator.free(bc);
    try std.testing.expectEqualStrings("(no heading)", bc);
}

test "read section range" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Doc\n## Section\nLine A\nLine B\nLine C\n## Other");

    var nav = init(&buffer);
    const ranged = try nav.navigator().readSectionRange(allocator, "Doc/Section", 1, 3);
    defer allocator.free(ranged);

    try std.testing.expect(std.mem.indexOf(u8, ranged, "Line A") != null);
    try std.testing.expect(std.mem.indexOf(u8, ranged, "Line B") != null);
    // Line C is at offset 3 within the section (lines 2,3,4 = offsets 0,1,2 after heading at line 1)
    // section starts at line 1 (heading), so start_offset=1 -> line 2, end_offset=3 -> line 4
}
