const std = @import("std");
const Buffer = @import("../Buffer.zig");
const Navigator = @import("../nav/Navigator.zig");
const BuiltinNavigator = @import("../nav/BuiltinNavigator.zig");
const Scanner = @import("../brain/Scanner.zig");
const Graph = @import("../brain/Graph.zig");
const Allocator = std.mem.Allocator;
const posix = std.posix;

const Self = @This();

const PROTOCOL_VERSION = "2024-11-05";

// ── State ─────────────────────────────────────────────────────────────

allocator: Allocator,
buffer: *Buffer,
builtin_nav: BuiltinNavigator,
file_path: ?[]const u8,
file_path_owned: ?[]u8,
initialized: bool,
should_quit: bool,
read_buf: std.ArrayList(u8),

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: Allocator, buffer: *Buffer) Self {
    return .{
        .allocator = allocator,
        .buffer = buffer,
        .builtin_nav = BuiltinNavigator.init(buffer),
        .file_path = null,
        .file_path_owned = null,
        .initialized = false,
        .should_quit = false,
        .read_buf = .{},
    };
}

pub fn deinit(self: *Self) void {
    self.read_buf.deinit(self.allocator);
    if (self.file_path_owned) |p| self.allocator.free(p);
}

// ── Main Loop ─────────────────────────────────────────────────────────

pub fn run(self: *Self) !void {
    log("MCP server starting (protocol {s})", .{PROTOCOL_VERSION});

    while (!self.should_quit) {
        const line = self.readLine() catch |err| {
            if (err == error.EndOfStream) {
                log("stdin closed, shutting down", .{});
                break;
            }
            log("read error: {}", .{err});
            continue;
        };
        defer self.allocator.free(line);

        if (line.len == 0) continue;

        self.handleMessage(line) catch |err| {
            log("handle error: {}", .{err});
        };
    }

    log("MCP server stopped", .{});
}

// ── Message Handling ──────────────────────────────────────────────────

fn handleMessage(self: *Self, line: []const u8) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, line, .{}) catch {
        try self.sendError(null, -32700, "Parse error");
        return;
    };
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) {
        try self.sendError(null, -32600, "Invalid Request");
        return;
    }

    const method_val = root.object.get("method") orelse {
        try self.sendError(null, -32600, "Missing method");
        return;
    };
    if (method_val != .string) {
        try self.sendError(null, -32600, "Method must be string");
        return;
    }
    const method = method_val.string;

    const id = root.object.get("id");
    const params = root.object.get("params");

    if (std.mem.eql(u8, method, "initialize")) {
        try self.handleInitialize(id);
    } else if (std.mem.eql(u8, method, "notifications/initialized")) {
        self.initialized = true;
        log("client initialized", .{});
    } else if (std.mem.eql(u8, method, "tools/list")) {
        try self.handleToolsList(id);
    } else if (std.mem.eql(u8, method, "tools/call")) {
        try self.handleToolsCall(id, params);
    } else if (std.mem.eql(u8, method, "resources/list")) {
        try self.handleResourcesList(id);
    } else if (std.mem.eql(u8, method, "resources/read")) {
        try self.handleResourcesRead(id, params);
    } else if (std.mem.eql(u8, method, "ping")) {
        try self.sendRawResult(id, "{}");
    } else if (std.mem.eql(u8, method, "notifications/cancelled")) {
        // noop
    } else {
        log("unknown method: {s}", .{method});
        if (id != null) {
            try self.sendError(id, -32601, "Method not found");
        }
    }
}

// ── Protocol Handlers ─────────────────────────────────────────────────

fn handleInitialize(self: *Self, id: ?std.json.Value) !void {
    try self.sendRawResult(id,
        \\{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":false},"resources":{"subscribe":false,"listChanged":false}},"serverInfo":{"name":"lazy-md","version":"0.1.0"}}
    );
}

fn handleToolsList(self: *Self, id: ?std.json.Value) !void {
    const tools_json = @embedFile("tools.json");
    try self.sendRawResult(id, tools_json);
}

fn handleToolsCall(self: *Self, id: ?std.json.Value, params: ?std.json.Value) !void {
    const p = params orelse {
        try self.sendError(id, -32602, "Missing params");
        return;
    };
    if (p != .object) {
        try self.sendError(id, -32602, "Params must be object");
        return;
    }

    const name_val = p.object.get("name") orelse {
        try self.sendError(id, -32602, "Missing tool name");
        return;
    };
    if (name_val != .string) {
        try self.sendError(id, -32602, "Tool name must be string");
        return;
    }
    const name = name_val.string;
    const args = if (p.object.get("arguments")) |a| (if (a == .object) a else null) else null;

    const result = self.dispatchTool(name, args) catch |err| {
        try self.sendToolError(id, err);
        return;
    };
    defer self.allocator.free(result);
    try self.sendToolResult(id, result, false);
}

fn handleResourcesList(self: *Self, id: ?std.json.Value) !void {
    if (self.file_path) |path| {
        var uri_buf: [4096]u8 = undefined;
        const uri = std.fmt.bufPrint(&uri_buf, "file://{s}", .{path}) catch "file://unknown";
        const name = std.fs.path.basename(path);

        const json_str = try std.fmt.allocPrint(self.allocator, "{{\"resources\":[{{\"uri\":\"{s}\",\"name\":\"{s}\",\"description\":\"Current open document\",\"mimeType\":\"text/markdown\"}}]}}", .{ uri, name });
        defer self.allocator.free(json_str);
        try self.sendRawResult(id, json_str);
    } else {
        try self.sendRawResult(id, "{\"resources\":[]}");
    }
}

fn handleResourcesRead(self: *Self, id: ?std.json.Value, params: ?std.json.Value) !void {
    _ = params;
    if (self.file_path == null) {
        try self.sendError(id, -32602, "No document open");
        return;
    }

    const content = try self.getBufferContent();
    defer self.allocator.free(content);

    const escaped = try jsonStringify(self.allocator, content);
    defer self.allocator.free(escaped);

    const response = try std.fmt.allocPrint(self.allocator, "{{\"contents\":[{{\"uri\":\"file://{s}\",\"mimeType\":\"text/markdown\",\"text\":{s}}}]}}", .{ self.file_path.?, escaped });
    defer self.allocator.free(response);
    try self.sendRawResult(id, response);
}

// ── Tool Dispatch ─────────────────────────────────────────────────────

fn dispatchTool(self: *Self, name: []const u8, args: ?std.json.Value) ![]const u8 {
    if (std.mem.eql(u8, name, "open_file")) {
        return self.toolOpenFile(args);
    } else if (std.mem.eql(u8, name, "read_document")) {
        return self.toolReadDocument();
    } else if (std.mem.eql(u8, name, "write_document")) {
        return self.toolWriteDocument(args);
    } else if (std.mem.eql(u8, name, "list_headings")) {
        return self.toolListHeadings();
    } else if (std.mem.eql(u8, name, "edit_section")) {
        return self.toolEditSection(args);
    } else if (std.mem.eql(u8, name, "insert_text")) {
        return self.toolInsertText(args);
    } else if (std.mem.eql(u8, name, "delete_lines")) {
        return self.toolDeleteLines(args);
    } else if (std.mem.eql(u8, name, "search_content")) {
        return self.toolSearchContent(args);
    } else if (std.mem.eql(u8, name, "get_structure")) {
        return self.toolGetStructure();
    } else if (std.mem.eql(u8, name, "read_section")) {
        return self.toolReadSection(args);
    } else if (std.mem.eql(u8, name, "list_tasks")) {
        return self.toolListTasks(args);
    } else if (std.mem.eql(u8, name, "update_task")) {
        return self.toolUpdateTask(args);
    } else if (std.mem.eql(u8, name, "get_breadcrumb")) {
        return self.toolGetBreadcrumb(args);
    } else if (std.mem.eql(u8, name, "move_section")) {
        return self.toolMoveSection(args);
    } else if (std.mem.eql(u8, name, "read_section_range")) {
        return self.toolReadSectionRange(args);
    } else if (std.mem.eql(u8, name, "list_links")) {
        return self.toolListLinks();
    } else if (std.mem.eql(u8, name, "get_backlinks")) {
        return self.toolGetBacklinks(args);
    } else if (std.mem.eql(u8, name, "get_graph")) {
        return self.toolGetGraph(args);
    } else if (std.mem.eql(u8, name, "get_neighbors")) {
        return self.toolGetNeighbors(args);
    } else if (std.mem.eql(u8, name, "find_path")) {
        return self.toolFindPath(args);
    } else if (std.mem.eql(u8, name, "get_orphans")) {
        return self.toolGetOrphans();
    } else if (std.mem.eql(u8, name, "get_hub_notes")) {
        return self.toolGetHubNotes(args);
    } else {
        return error.ToolNotFound;
    }
}

// ── Tool Implementations ──────────────────────────────────────────────

fn toolOpenFile(self: *Self, args: ?std.json.Value) ![]const u8 {
    const path = getStringArg(args, "path") orelse return error.MissingArgument;

    self.buffer.loadFile(path) catch |err| {
        return std.fmt.allocPrint(self.allocator, "Failed to open file: {}", .{err});
    };

    if (self.file_path_owned) |p| self.allocator.free(p);
    const owned = try self.allocator.dupe(u8, path);
    self.file_path_owned = owned;
    self.file_path = owned;

    return std.fmt.allocPrint(self.allocator, "Opened {s} ({} lines, {} bytes)", .{
        path,
        self.buffer.lineCount(),
        self.buffer.length(),
    });
}

fn toolReadDocument(self: *Self) ![]const u8 {
    return self.getBufferContent();
}

fn toolWriteDocument(self: *Self, args: ?std.json.Value) ![]const u8 {
    const path = getStringArg(args, "path") orelse self.file_path orelse return error.MissingArgument;

    self.buffer.saveFile(path) catch |err| {
        return std.fmt.allocPrint(self.allocator, "Failed to save: {}", .{err});
    };

    if (self.file_path == null or !std.mem.eql(u8, self.file_path.?, path)) {
        if (self.file_path_owned) |p| self.allocator.free(p);
        const owned = try self.allocator.dupe(u8, path);
        self.file_path_owned = owned;
        self.file_path = owned;
    }

    return std.fmt.allocPrint(self.allocator, "Saved to {s} ({} bytes)", .{ path, self.buffer.length() });
}

fn toolListHeadings(self: *Self) ![]const u8 {
    var result: std.ArrayList(u8) = .{};

    const line_count = self.buffer.lineCount();
    var i: usize = 0;
    var found: usize = 0;
    while (i < line_count) : (i += 1) {
        const line = self.buffer.getLine(i);
        if (line.len > 0 and line[0] == '#') {
            var level: usize = 0;
            while (level < line.len and line[level] == '#') level += 1;
            if (level <= 6 and level < line.len and line[level] == ' ') {
                const title = std.mem.trimRight(u8, line[level + 1 ..], " \t\r");
                const w = result.writer(self.allocator);
                if (found > 0) try w.writeAll("\n");
                try w.print("L{}: {s} {s}", .{ i + 1, line[0..level], title });
                found += 1;
            }
        }
    }

    if (found == 0) {
        result.deinit(self.allocator);
        return try self.allocator.dupe(u8, "No headings found");
    }

    return result.toOwnedSlice(self.allocator);
}

fn toolEditSection(self: *Self, args: ?std.json.Value) ![]const u8 {
    const heading = getStringArg(args, "heading") orelse return error.MissingArgument;
    const content = getStringArg(args, "content") orelse return error.MissingArgument;

    const line_count = self.buffer.lineCount();

    // Find the heading
    var section_start: ?usize = null;
    var section_level: usize = 0;
    var i: usize = 0;
    while (i < line_count) : (i += 1) {
        const line = self.buffer.getLine(i);
        if (line.len > 0 and line[0] == '#') {
            var level: usize = 0;
            while (level < line.len and line[level] == '#') level += 1;
            if (level <= 6 and level < line.len and line[level] == ' ') {
                const title = std.mem.trimRight(u8, line[level + 1 ..], " \t\r");
                if (std.ascii.eqlIgnoreCase(title, heading)) {
                    section_start = i;
                    section_level = level;
                    break;
                }
            }
        }
    }

    const start = section_start orelse {
        return std.fmt.allocPrint(self.allocator, "Heading '{s}' not found", .{heading});
    };

    // Find section end (next heading of same or higher level, or EOF)
    var section_end: usize = line_count;
    i = start + 1;
    while (i < line_count) : (i += 1) {
        const line = self.buffer.getLine(i);
        if (line.len > 0 and line[0] == '#') {
            var level: usize = 0;
            while (level < line.len and line[level] == '#') level += 1;
            if (level <= section_level) {
                section_end = i;
                break;
            }
        }
    }

    // Calculate byte range to replace (content AFTER heading line)
    const content_start_line = start + 1;
    const start_offset = if (content_start_line < line_count)
        self.buffer.posToOffset(content_start_line, 0)
    else
        self.buffer.length();

    const end_offset = if (section_end < line_count)
        self.buffer.posToOffset(section_end, 0)
    else
        self.buffer.length();

    // Delete old content
    if (end_offset > start_offset) {
        try self.buffer.deleteRange(start_offset, end_offset - start_offset);
    }

    // Insert new content (ensure trailing newline)
    var new_content: []const u8 = content;
    var needs_free = false;
    if (content.len > 0 and content[content.len - 1] != '\n') {
        const with_nl = try std.fmt.allocPrint(self.allocator, "{s}\n", .{content});
        new_content = with_nl;
        needs_free = true;
    }
    defer if (needs_free) self.allocator.free(new_content);

    try self.buffer.insertSlice(start_offset, new_content);

    return std.fmt.allocPrint(self.allocator, "Updated section '{s}' ({} bytes)", .{ heading, new_content.len });
}

fn toolInsertText(self: *Self, args: ?std.json.Value) ![]const u8 {
    const text = getStringArg(args, "text") orelse return error.MissingArgument;
    const line_num = getIntArg(args, "line");

    const offset = if (line_num) |ln| blk: {
        const line: usize = if (ln > 0) @intCast(ln - 1) else 0;
        break :blk self.buffer.posToOffset(@min(line, self.buffer.lineCount()), 0);
    } else self.buffer.length();

    try self.buffer.insertSlice(offset, text);

    return std.fmt.allocPrint(self.allocator, "Inserted {} bytes at offset {}", .{ text.len, offset });
}

fn toolDeleteLines(self: *Self, args: ?std.json.Value) ![]const u8 {
    const start_line = getIntArg(args, "start_line") orelse return error.MissingArgument;
    const end_line = getIntArg(args, "end_line") orelse start_line;

    if (start_line < 1) return error.InvalidArgument;

    const s: usize = @intCast(start_line - 1);
    const e: usize = @intCast(@min(end_line, @as(i64, @intCast(self.buffer.lineCount()))));

    if (s >= self.buffer.lineCount()) {
        return std.fmt.allocPrint(self.allocator, "Line {} out of range (document has {} lines)", .{ start_line, self.buffer.lineCount() });
    }

    const start_offset = self.buffer.posToOffset(s, 0);
    const end_offset = if (e < self.buffer.lineCount())
        self.buffer.posToOffset(e, 0)
    else
        self.buffer.length();

    if (end_offset > start_offset) {
        try self.buffer.deleteRange(start_offset, end_offset - start_offset);
    }

    return std.fmt.allocPrint(self.allocator, "Deleted lines {}-{}", .{ start_line, end_line });
}

fn toolSearchContent(self: *Self, args: ?std.json.Value) ![]const u8 {
    const query = getStringArg(args, "query") orelse return error.MissingArgument;

    var result: std.ArrayList(u8) = .{};

    const line_count = self.buffer.lineCount();
    var found: usize = 0;
    var i: usize = 0;
    while (i < line_count) : (i += 1) {
        const line = self.buffer.getLine(i);
        if (containsIgnoreCase(line, query)) {
            const w = result.writer(self.allocator);
            if (found > 0) try w.writeAll("\n");
            try w.print("L{}: {s}", .{ i + 1, line });
            found += 1;
            if (found >= 50) {
                try w.writeAll("\n... (truncated, 50+ matches)");
                break;
            }
        }
    }

    if (found == 0) {
        result.deinit(self.allocator);
        return std.fmt.allocPrint(self.allocator, "No matches for '{s}'", .{query});
    }

    return result.toOwnedSlice(self.allocator);
}

fn toolGetStructure(self: *Self) ![]const u8 {
    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);

    try w.print("Lines: {}\nBytes: {}\n", .{ self.buffer.lineCount(), self.buffer.length() });

    if (self.file_path) |p| {
        try w.print("File: {s}\n", .{p});
    }
    try w.print("Modified: {}\n\nOutline:\n", .{self.buffer.dirty});

    const line_count = self.buffer.lineCount();
    var i: usize = 0;
    var headings: usize = 0;
    while (i < line_count) : (i += 1) {
        const line = self.buffer.getLine(i);
        if (line.len > 0 and line[0] == '#') {
            var level: usize = 0;
            while (level < line.len and line[level] == '#') level += 1;
            if (level <= 6 and level < line.len and line[level] == ' ') {
                const indent = level - 1;
                var j: usize = 0;
                while (j < indent * 2) : (j += 1) try w.writeByte(' ');
                const title = std.mem.trimRight(u8, line[level + 1 ..], " \t\r");
                try w.print("- {s} (L{})\n", .{ title, i + 1 });
                headings += 1;
            }
        }
    }

    if (headings == 0) try w.writeAll("  (no headings)\n");

    return result.toOwnedSlice(self.allocator);
}

// ── Navigation Tool Implementations ───────────────────────────────────

fn toolReadSection(self: *Self, args: ?std.json.Value) ![]const u8 {
    const heading_path = getStringArg(args, "heading_path") orelse return error.MissingArgument;
    var nav = self.builtin_nav.navigator();
    const section = nav.readSection(self.allocator, heading_path) catch |err| {
        if (err == error.HeadingNotFound)
            return std.fmt.allocPrint(self.allocator, "Heading path '{s}' not found", .{heading_path});
        return err;
    };
    defer self.allocator.free(section.content);

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);
    try w.print("[L{}-L{}, h{}] {s}\n\n{s}", .{
        section.heading_line + 1,
        section.end_line,
        section.level,
        section.title,
        section.content,
    });
    return result.toOwnedSlice(self.allocator);
}

fn toolListTasks(self: *Self, args: ?std.json.Value) ![]const u8 {
    const section = getStringArg(args, "section");
    const status_str = getStringArg(args, "status") orelse "all";
    const status: u8 = if (std.ascii.eqlIgnoreCase(status_str, "pending"))
        1
    else if (std.ascii.eqlIgnoreCase(status_str, "done"))
        2
    else
        0;

    var nav = self.builtin_nav.navigator();
    const tasks = nav.listTasks(self.allocator, section, status) catch |err| {
        if (err == error.HeadingNotFound)
            return std.fmt.allocPrint(self.allocator, "Section not found", .{});
        return err;
    };
    defer {
        for (tasks) |t| self.allocator.free(t.breadcrumb);
        self.allocator.free(tasks);
    }

    if (tasks.len == 0) return try self.allocator.dupe(u8, "No tasks found");

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);
    for (tasks, 0..) |t, idx| {
        if (idx > 0) try w.writeByte('\n');
        const mark: u8 = if (t.done) 'x' else ' ';
        try w.print("L{}: [{c}] {s} (under: {s})", .{ t.line + 1, mark, t.text, t.breadcrumb });
    }
    return result.toOwnedSlice(self.allocator);
}

fn toolUpdateTask(self: *Self, args: ?std.json.Value) ![]const u8 {
    const line_num = getIntArg(args, "line") orelse return error.MissingArgument;
    if (line_num < 1) return error.InvalidArgument;
    const line: usize = @intCast(line_num - 1);

    const done = getBoolArg(args, "done") orelse return error.MissingArgument;

    var nav = self.builtin_nav.navigator();
    const result = nav.updateTask(self.allocator, line, done) catch |err| {
        if (err == error.InvalidArgument)
            return std.fmt.allocPrint(self.allocator, "Line {} is not a task checkbox", .{line_num});
        return err;
    };
    return result;
}

fn toolGetBreadcrumb(self: *Self, args: ?std.json.Value) ![]const u8 {
    const line_num = getIntArg(args, "line") orelse return error.MissingArgument;
    if (line_num < 1) return error.InvalidArgument;
    const line: usize = @intCast(line_num - 1);

    var nav = self.builtin_nav.navigator();
    return nav.getBreadcrumb(self.allocator, line) catch |err| {
        if (err == error.InvalidArgument)
            return std.fmt.allocPrint(self.allocator, "Line {} out of range", .{line_num});
        return err;
    };
}

fn toolMoveSection(self: *Self, args: ?std.json.Value) ![]const u8 {
    const heading = getStringArg(args, "heading") orelse return error.MissingArgument;
    const after = getStringArg(args, "after");
    const before = getStringArg(args, "before");

    const target = after orelse before orelse return error.MissingArgument;
    const is_before = (before != null);

    var nav = self.builtin_nav.navigator();
    return nav.moveSection(self.allocator, heading, target, is_before) catch |err| {
        if (err == error.HeadingNotFound)
            return std.fmt.allocPrint(self.allocator, "Heading not found", .{});
        return err;
    };
}

fn toolReadSectionRange(self: *Self, args: ?std.json.Value) ![]const u8 {
    const heading_path = getStringArg(args, "heading_path") orelse return error.MissingArgument;
    const start_off: ?usize = if (getIntArg(args, "start_offset")) |v| (if (v >= 0) @intCast(v) else null) else null;
    const end_off: ?usize = if (getIntArg(args, "end_offset")) |v| (if (v >= 0) @intCast(v) else null) else null;

    var nav = self.builtin_nav.navigator();
    return nav.readSectionRange(self.allocator, heading_path, start_off, end_off) catch |err| {
        if (err == error.HeadingNotFound)
            return std.fmt.allocPrint(self.allocator, "Heading path '{s}' not found", .{heading_path});
        return err;
    };
}

// ── Brain Tool Implementations ────────────────────────────────────────

fn toolListLinks(self: *Self) ![]const u8 {
    const content = try self.getBufferContent();
    defer self.allocator.free(content);

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);

    try w.writeAll("[");
    var first = true;
    var i: usize = 0;
    var line_num: usize = 1;
    while (i < content.len) {
        if (content[i] == '\n') {
            line_num += 1;
            i += 1;
            continue;
        }
        if (i + 3 < content.len and content[i] == '[' and content[i + 1] == '[') {
            const start = i + 2;
            if (findWikiLinkEnd(content, start)) |end| {
                const raw = content[start..end];
                const target = if (std.mem.indexOfScalar(u8, raw, '|')) |pipe| raw[0..pipe] else raw;
                if (target.len > 0) {
                    if (!first) try w.writeAll(",");
                    first = false;
                    const escaped_target = try jsonStringify(self.allocator, target);
                    defer self.allocator.free(escaped_target);
                    try w.print("{{\"target\":{s},\"line\":{}}}", .{ escaped_target, line_num });
                }
                i = end + 2;
                continue;
            }
        }
        i += 1;
    }
    try w.writeAll("]");

    if (first) {
        result.deinit(self.allocator);
        return try self.allocator.dupe(u8, "No [[wiki-links]] found in current document");
    }

    return result.toOwnedSlice(self.allocator);
}

fn toolGetBacklinks(self: *Self, args: ?std.json.Value) ![]const u8 {
    // Determine target note stem
    const note_arg = getStringArg(args, "note");
    const stem = note_arg orelse blk: {
        const fp = self.file_path orelse return try self.allocator.dupe(u8, "No file open and no 'note' argument provided");
        const basename = std.fs.path.basename(fp);
        if (std.mem.lastIndexOfScalar(u8, basename, '.')) |dot| break :blk basename[0..dot];
        break :blk basename;
    };

    const pattern = try std.fmt.allocPrint(self.allocator, "[[{s}]]", .{stem});
    defer self.allocator.free(pattern);
    const pattern_aliased = try std.fmt.allocPrint(self.allocator, "[[{s}|", .{stem});
    defer self.allocator.free(pattern_aliased);

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);
    try w.writeAll("[");
    var first = true;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        result.deinit(self.allocator);
        return try self.allocator.dupe(u8, "Cannot scan working directory");
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md") and !std.mem.endsWith(u8, entry.name, ".rndm")) continue;

        // Skip self
        if (self.file_path) |fp| {
            if (std.mem.eql(u8, std.fs.path.basename(fp), entry.name)) continue;
        }

        const file = dir.openFile(entry.name, .{}) catch continue;
        defer file.close();
        var read_buf: [65536]u8 = undefined;
        const n = file.readAll(&read_buf) catch continue;
        const file_content = read_buf[0..n];

        if (containsIgnoreCase(file_content, pattern) or containsIgnoreCase(file_content, pattern_aliased)) {
            // Find the line containing the link
            var line_num: usize = 1;
            var context_line: []const u8 = "";
            var pos: usize = 0;
            for (file_content, 0..) |c, ci| {
                if (c == '\n') {
                    const line = file_content[pos..ci];
                    if (containsIgnoreCase(line, pattern) or containsIgnoreCase(line, pattern_aliased)) {
                        context_line = line;
                        break;
                    }
                    line_num += 1;
                    pos = ci + 1;
                }
            }
            // Check last line
            if (context_line.len == 0 and pos < file_content.len) {
                context_line = file_content[pos..];
            }

            if (!first) try w.writeAll(",");
            first = false;
            const escaped_file = try jsonStringify(self.allocator, entry.name);
            defer self.allocator.free(escaped_file);
            const ctx_trunc = context_line[0..@min(context_line.len, 100)];
            const escaped_ctx = try jsonStringify(self.allocator, ctx_trunc);
            defer self.allocator.free(escaped_ctx);
            try w.print("{{\"file\":{s},\"line\":{},\"context\":{s}}}", .{ escaped_file, line_num, escaped_ctx });
        }
    }

    try w.writeAll("]");

    if (first) {
        result.deinit(self.allocator);
        return std.fmt.allocPrint(self.allocator, "No backlinks found for '{s}'", .{stem});
    }

    return result.toOwnedSlice(self.allocator);
}

fn toolGetGraph(self: *Self, args: ?std.json.Value) ![]const u8 {
    var graph = Scanner.scan(self.allocator, ".") catch {
        return try self.allocator.dupe(u8, "Failed to scan vault");
    };
    defer graph.deinit();

    const center_node = getStringArg(args, "node");
    const depth_arg = getIntArg(args, "depth");
    const depth: u16 = if (depth_arg) |d| (if (d > 0 and d <= 10) @intCast(d) else 2) else 2;

    // Determine visible nodes
    var visible_nodes: ?[]u16 = null;
    defer if (visible_nodes) |vn| self.allocator.free(vn);

    if (center_node) |cn| {
        if (graph.resolve(cn)) |nid| {
            visible_nodes = graph.getNeighbors(nid, depth) catch null;
        }
    }

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);

    // Nodes
    try w.writeAll("{\"nodes\":[");
    var first = true;
    for (graph.nodes.items) |node| {
        if (visible_nodes) |vn| {
            var found = false;
            for (vn) |v| {
                if (v == node.id) {
                    found = true;
                    break;
                }
            }
            if (!found) continue;
        }
        if (!first) try w.writeAll(",");
        first = false;
        const escaped_name = try jsonStringify(self.allocator, node.name);
        defer self.allocator.free(escaped_name);
        const escaped_path = try jsonStringify(self.allocator, node.path);
        defer self.allocator.free(escaped_path);
        try w.print("{{\"id\":{},\"name\":{s},\"path\":{s},\"out_links\":{},\"in_links\":{}}}", .{
            node.id, escaped_name, escaped_path, node.out_links.len, node.in_links.len,
        });
    }
    try w.writeAll("],");

    // Edges
    try w.writeAll("\"edges\":[");
    first = true;
    for (graph.edges.items) |edge| {
        if (visible_nodes) |vn| {
            var from_ok = false;
            var to_ok = false;
            for (vn) |v| {
                if (v == edge.from) from_ok = true;
                if (v == edge.to) to_ok = true;
            }
            if (!from_ok or !to_ok) continue;
        }
        if (!first) try w.writeAll(",");
        first = false;
        try w.print("{{\"from\":{},\"to\":{}}}", .{ edge.from, edge.to });
    }
    try w.writeAll("],");

    // Stats
    const orphans = graph.getOrphans() catch &.{};
    defer if (orphans.len > 0) self.allocator.free(orphans);
    try w.print("\"stats\":{{\"total_notes\":{},\"total_links\":{},\"orphans\":{}}}", .{
        graph.nodeCount(), graph.edgeCount(), orphans.len,
    });
    try w.writeAll("}");

    return result.toOwnedSlice(self.allocator);
}

fn toolGetNeighbors(self: *Self, args: ?std.json.Value) ![]const u8 {
    const note_arg = getStringArg(args, "note");
    const depth_arg = getIntArg(args, "depth");
    const depth: u16 = if (depth_arg) |d| (if (d > 0 and d <= 10) @intCast(d) else 1) else 1;

    const stem = note_arg orelse blk: {
        const fp = self.file_path orelse return try self.allocator.dupe(u8, "No file open and no 'note' argument provided");
        const basename = std.fs.path.basename(fp);
        if (std.mem.lastIndexOfScalar(u8, basename, '.')) |dot| break :blk basename[0..dot];
        break :blk basename;
    };

    var graph = Scanner.scan(self.allocator, ".") catch {
        return try self.allocator.dupe(u8, "Failed to scan vault");
    };
    defer graph.deinit();

    const node_id = graph.resolve(stem) orelse {
        return std.fmt.allocPrint(self.allocator, "Note '{s}' not found in vault", .{stem});
    };

    const neighbors = graph.getNeighbors(node_id, depth) catch {
        return try self.allocator.dupe(u8, "Failed to compute neighbors");
    };
    defer self.allocator.free(neighbors);

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);

    const node = graph.nodes.items[node_id];
    try w.print("Neighbors of '{s}' (depth={d}):\n\n", .{ node.name, depth });

    // Outgoing links
    try w.writeAll("Outgoing links:\n");
    if (node.out_links.len == 0) {
        try w.writeAll("  (none)\n");
    } else {
        for (node.out_links) |out| {
            const target = graph.nodes.items[out];
            try w.print("  -> {s} ({s}) [out:{d} in:{d}]\n", .{ target.name, target.path, target.out_links.len, target.in_links.len });
        }
    }

    // Backlinks
    try w.writeAll("\nBacklinks (incoming):\n");
    if (node.in_links.len == 0) {
        try w.writeAll("  (none)\n");
    } else {
        for (node.in_links) |in_id| {
            const source = graph.nodes.items[in_id];
            try w.print("  <- {s} ({s}) [out:{d} in:{d}]\n", .{ source.name, source.path, source.out_links.len, source.in_links.len });
        }
    }

    if (depth > 1) {
        try w.print("\nAll reachable within {d} hops: {d} notes\n", .{ depth, neighbors.len });
        for (neighbors) |nid| {
            if (nid == node_id) continue;
            const n = graph.nodes.items[nid];
            try w.print("  {s} ({s})\n", .{ n.name, n.path });
        }
    }

    return result.toOwnedSlice(self.allocator);
}

fn toolFindPath(self: *Self, args: ?std.json.Value) ![]const u8 {
    const from_str = getStringArg(args, "from") orelse return error.MissingArgument;
    const to_str = getStringArg(args, "to") orelse return error.MissingArgument;

    var graph = Scanner.scan(self.allocator, ".") catch {
        return try self.allocator.dupe(u8, "Failed to scan vault");
    };
    defer graph.deinit();

    const from_id = graph.resolve(from_str) orelse {
        return std.fmt.allocPrint(self.allocator, "Source note '{s}' not found", .{from_str});
    };
    const to_id = graph.resolve(to_str) orelse {
        return std.fmt.allocPrint(self.allocator, "Target note '{s}' not found", .{to_str});
    };

    if (from_id == to_id) {
        return std.fmt.allocPrint(self.allocator, "'{s}' and '{s}' are the same note", .{ from_str, to_str });
    }

    // BFS to find shortest path
    const n = graph.nodeCount();
    var visited = try self.allocator.alloc(bool, n);
    defer self.allocator.free(visited);
    @memset(visited, false);

    // Parent tracking for path reconstruction
    var parent = try self.allocator.alloc(i32, n);
    defer self.allocator.free(parent);
    @memset(parent, -1);

    const QItem = struct { id: u16 };
    var queue: std.ArrayList(QItem) = .{};
    defer queue.deinit(self.allocator);

    visited[from_id] = true;
    try queue.append(self.allocator, .{ .id = from_id });

    var found = false;
    while (queue.items.len > 0) {
        const item = queue.orderedRemove(0);
        if (item.id == to_id) {
            found = true;
            break;
        }

        const node = graph.nodes.items[item.id];
        // Traverse both directions
        for (node.out_links) |next| {
            if (!visited[next]) {
                visited[next] = true;
                parent[next] = @intCast(item.id);
                try queue.append(self.allocator, .{ .id = next });
            }
        }
        for (node.in_links) |next| {
            if (!visited[next]) {
                visited[next] = true;
                parent[next] = @intCast(item.id);
                try queue.append(self.allocator, .{ .id = next });
            }
        }
    }

    if (!found) {
        return std.fmt.allocPrint(self.allocator, "No path exists between '{s}' and '{s}'", .{ from_str, to_str });
    }

    // Reconstruct path
    var path: std.ArrayList(u16) = .{};
    defer path.deinit(self.allocator);
    var cur: u16 = to_id;
    while (cur != from_id) {
        try path.append(self.allocator, cur);
        cur = @intCast(parent[cur]);
    }
    try path.append(self.allocator, from_id);

    // Reverse and format
    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);
    try w.print("Path ({d} hops):\n", .{path.items.len - 1});
    var i: usize = path.items.len;
    while (i > 0) {
        i -= 1;
        const node = graph.nodes.items[path.items[i]];
        if (i < path.items.len - 1) try w.writeAll(" -> ");
        try w.print("{s}", .{node.name});
    }
    try w.writeByte('\n');

    return result.toOwnedSlice(self.allocator);
}

fn toolGetOrphans(self: *Self) ![]const u8 {
    var graph = Scanner.scan(self.allocator, ".") catch {
        return try self.allocator.dupe(u8, "Failed to scan vault");
    };
    defer graph.deinit();

    const orphans = graph.getOrphans() catch {
        return try self.allocator.dupe(u8, "Failed to compute orphans");
    };
    defer self.allocator.free(orphans);

    if (orphans.len == 0) {
        return std.fmt.allocPrint(self.allocator, "No orphan notes found. All {d} notes are connected.", .{graph.nodeCount()});
    }

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);
    try w.print("Orphan notes ({d}/{d} notes have no links):\n\n", .{ orphans.len, graph.nodeCount() });
    for (orphans) |oid| {
        const node = graph.nodes.items[oid];
        try w.print("  {s} ({s})\n", .{ node.name, node.path });
    }

    return result.toOwnedSlice(self.allocator);
}

fn toolGetHubNotes(self: *Self, args: ?std.json.Value) ![]const u8 {
    const limit_arg = getIntArg(args, "limit");
    const limit: usize = if (limit_arg) |l| (if (l > 0 and l <= 100) @intCast(l) else 10) else 10;

    var graph = Scanner.scan(self.allocator, ".") catch {
        return try self.allocator.dupe(u8, "Failed to scan vault");
    };
    defer graph.deinit();

    if (graph.nodeCount() == 0) {
        return try self.allocator.dupe(u8, "No notes found in vault");
    }

    // Build sortable array of (node_id, total_links)
    const Entry = struct { id: u16, total: usize };
    var entries = try self.allocator.alloc(Entry, graph.nodeCount());
    defer self.allocator.free(entries);

    for (graph.nodes.items, 0..) |node, i| {
        entries[i] = .{
            .id = @intCast(i),
            .total = node.out_links.len + node.in_links.len,
        };
    }

    // Sort by total links descending
    std.mem.sort(Entry, entries, {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            return a.total > b.total;
        }
    }.lessThan);

    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);
    const shown = @min(limit, entries.len);
    try w.print("Top {d} most connected notes:\n\n", .{shown});
    for (entries[0..shown], 0..) |entry, rank| {
        const node = graph.nodes.items[entry.id];
        try w.print("  {d}. {s} — {d} links (out:{d} in:{d}) — {s}\n", .{
            rank + 1, node.name, entry.total, node.out_links.len, node.in_links.len, node.path,
        });
    }

    return result.toOwnedSlice(self.allocator);
}

fn findWikiLinkEnd(content: []const u8, start: usize) ?usize {
    var i = start;
    while (i + 1 < content.len) : (i += 1) {
        if (content[i] == ']' and content[i + 1] == ']') return i;
        if (content[i] == '\n') return null;
    }
    return null;
}

// ── JSON-RPC Response Helpers ─────────────────────────────────────────

fn sendRawResult(self: *Self, id: ?std.json.Value, raw_json: []const u8) !void {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(self.allocator);
    const w = buf.writer(self.allocator);

    try w.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try writeJsonValue(w, id);
    try w.writeAll(",\"result\":");
    try w.writeAll(raw_json);
    try w.writeAll("}\n");

    try writeStdout(buf.items);
}

fn sendToolResult(self: *Self, id: ?std.json.Value, text: []const u8, is_error: bool) !void {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(self.allocator);
    const w = buf.writer(self.allocator);

    const escaped = try jsonStringify(self.allocator, text);
    defer self.allocator.free(escaped);

    try w.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try writeJsonValue(w, id);
    if (is_error) {
        try w.print(",\"result\":{{\"content\":[{{\"type\":\"text\",\"text\":{s}}}],\"isError\":true}}", .{escaped});
    } else {
        try w.print(",\"result\":{{\"content\":[{{\"type\":\"text\",\"text\":{s}}}]}}", .{escaped});
    }
    try w.writeAll("}\n");

    try writeStdout(buf.items);
}

fn sendToolError(self: *Self, id: ?std.json.Value, err: anyerror) !void {
    const msg = switch (err) {
        error.ToolNotFound => "Unknown tool",
        error.MissingArgument => "Missing required argument",
        error.InvalidArgument => "Invalid argument",
        error.HeadingNotFound => "Heading not found",
        else => "Internal error",
    };
    try self.sendToolResult(id, msg, true);
}

fn sendError(self: *Self, id: ?std.json.Value, code: i32, message: []const u8) !void {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(self.allocator);
    const w = buf.writer(self.allocator);

    const escaped = try jsonStringify(self.allocator, message);
    defer self.allocator.free(escaped);

    try w.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try writeJsonValue(w, id);
    try w.print(",\"error\":{{\"code\":{},\"message\":{s}}}", .{ code, escaped });
    try w.writeAll("}\n");

    try writeStdout(buf.items);
}

// ── I/O Helpers ───────────────────────────────────────────────────────

fn readLine(self: *Self) ![]const u8 {
    self.read_buf.clearRetainingCapacity();
    var single: [1]u8 = undefined;
    while (true) {
        const n = posix.read(posix.STDIN_FILENO, &single) catch |err| {
            if (self.read_buf.items.len > 0) {
                return try self.allocator.dupe(u8, self.read_buf.items);
            }
            return err;
        };
        if (n == 0) {
            if (self.read_buf.items.len > 0) {
                return try self.allocator.dupe(u8, self.read_buf.items);
            }
            return error.EndOfStream;
        }
        if (single[0] == '\n') {
            return try self.allocator.dupe(u8, self.read_buf.items);
        }
        try self.read_buf.append(self.allocator, single[0]);
    }
}

fn writeStdout(data: []const u8) !void {
    var written: usize = 0;
    while (written < data.len) {
        written += try posix.write(posix.STDOUT_FILENO, data[written..]);
    }
}

fn getBufferContent(self: *Self) ![]const u8 {
    var result: std.ArrayList(u8) = .{};
    const w = result.writer(self.allocator);

    const line_count = self.buffer.lineCount();
    var i: usize = 0;
    while (i < line_count) : (i += 1) {
        const line = self.buffer.getLine(i);
        try w.writeAll(line);
        if (i + 1 < line_count) try w.writeByte('\n');
    }

    return result.toOwnedSlice(self.allocator);
}

// ── Utility Functions ─────────────────────────────────────────────────

fn getStringArg(args: ?std.json.Value, key: []const u8) ?[]const u8 {
    const a = args orelse return null;
    const val = a.object.get(key) orelse return null;
    if (val != .string) return null;
    return val.string;
}

fn getIntArg(args: ?std.json.Value, key: []const u8) ?i64 {
    const a = args orelse return null;
    const val = a.object.get(key) orelse return null;
    if (val != .integer) return null;
    return val.integer;
}

fn getBoolArg(args: ?std.json.Value, key: []const u8) ?bool {
    const a = args orelse return null;
    const val = a.object.get(key) orelse return null;
    if (val != .bool) return null;
    return val.bool;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    if (needle.len == 0) return true;
    const end = haystack.len - needle.len + 1;
    var i: usize = 0;
    while (i < end) : (i += 1) {
        var match = true;
        for (0..needle.len) |j| {
            if (std.ascii.toLower(haystack[i + j]) != std.ascii.toLower(needle[j])) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

fn writeJsonValue(w: anytype, value: ?std.json.Value) !void {
    if (value) |v| {
        switch (v) {
            .integer => |n| try w.print("{}", .{n}),
            .null => try w.writeAll("null"),
            else => try w.writeAll("null"),
        }
    } else {
        try w.writeAll("null");
    }
}

pub fn jsonStringify(allocator: Allocator, s: []const u8) ![]const u8 {
    var buf: std.ArrayList(u8) = .{};
    const w = buf.writer(allocator);
    try w.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => try w.writeAll("\\\""),
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    try w.print("\\u{x:0>4}", .{c});
                } else {
                    try w.writeByte(c);
                }
            },
        }
    }
    try w.writeByte('"');
    return buf.toOwnedSlice(allocator);
}

pub fn log(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.allocPrint(std.heap.page_allocator, "[lazy-md] " ++ fmt ++ "\n", args) catch return;
    defer std.heap.page_allocator.free(msg);
    _ = posix.write(posix.STDERR_FILENO, msg) catch {};
}

// ── Tests ─────────────────────────────────────────────────────────────

test "json escape" {
    const allocator = std.testing.allocator;
    const result = try jsonStringify(allocator, "hello \"world\"\nnewline");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("\"hello \\\"world\\\"\\nnewline\"", result);
}

test "contains ignore case" {
    try std.testing.expect(containsIgnoreCase("Hello World", "hello"));
    try std.testing.expect(containsIgnoreCase("Hello World", "WORLD"));
    try std.testing.expect(!containsIgnoreCase("Hello", "xyz"));
    try std.testing.expect(containsIgnoreCase("abc", ""));
}

test "get string arg" {
    const allocator = std.testing.allocator;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, "{\"path\":\"test.md\",\"num\":42}", .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("test.md", getStringArg(parsed.value, "path").?);
    try std.testing.expect(getStringArg(parsed.value, "missing") == null);
    try std.testing.expect(getStringArg(parsed.value, "num") == null);
}

test "tool dispatch - list headings" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Title\nSome text\n## Subtitle\nMore text");

    var server = init(allocator, &buffer);
    defer server.deinit();

    const result = try server.toolListHeadings();
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "# Title") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "## Subtitle") != null);
}

test "tool dispatch - search content" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "Hello World\nfoo bar\nHello Again");

    var server = init(allocator, &buffer);
    defer server.deinit();

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, "{\"query\":\"hello\"}", .{});
    defer parsed.deinit();
    const result = try server.toolSearchContent(parsed.value);
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Hello World") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Hello Again") != null);
}

test "tool dispatch - get structure" {
    const allocator = std.testing.allocator;
    var buffer = try Buffer.init(allocator);
    defer buffer.deinit();
    try buffer.insertSlice(0, "# Doc\n## Section A\n## Section B");

    var server = init(allocator, &buffer);
    defer server.deinit();

    const result = try server.toolGetStructure();
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Lines:") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Doc") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Section A") != null);
}
