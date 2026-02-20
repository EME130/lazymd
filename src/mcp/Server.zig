const std = @import("std");
const Buffer = @import("../Buffer.zig");
const Allocator = std.mem.Allocator;
const posix = std.posix;

const Self = @This();

const PROTOCOL_VERSION = "2024-11-05";

// ── State ─────────────────────────────────────────────────────────────

allocator: Allocator,
buffer: *Buffer,
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
