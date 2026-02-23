const std = @import("std");
const posix = std.posix;
const AgentBackend = @import("AgentBackend.zig");
const Self = @This();

// ── MCP Backend ──────────────────────────────────────────────────────
// Implements AgentBackend for MCP stdio transport.
// Editor→Agent: sends JSON-RPC notifications over stdout.
// Agent→Editor: reads JSON-RPC requests from stdin.

// ── State ─────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
connected: bool = false,
read_buf: std.ArrayList(u8) = .{},
write_buf: std.ArrayList(u8) = .{},
next_id: u64 = 1,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    self.read_buf.deinit(self.allocator);
    self.write_buf.deinit(self.allocator);
}

// ── AgentBackend Interface ───────────────────────────────────────────

pub fn agentBackend(self: *Self) AgentBackend {
    return .{ .ptr = @ptrCast(self), .vtable = &vtable };
}

const vtable = AgentBackend.VTable{
    .connect = connectImpl,
    .disconnect = disconnectImpl,
    .sendContext = sendContextImpl,
    .sendEvent = sendEventImpl,
    .pollCommand = pollCommandImpl,
    .isConnected = isConnectedImpl,
    .info = infoImpl,
};

fn connectImpl(ctx: *anyopaque, _: AgentBackend.AgentConfig) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.connected = true;
}

fn disconnectImpl(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.connected = false;
}

fn sendContextImpl(ctx: *anyopaque, context: AgentBackend.EditorContext) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (!self.connected) return;

    self.write_buf.clearRetainingCapacity();
    const w = self.write_buf.writer(self.allocator);
    try w.writeAll("{\"jsonrpc\":\"2.0\",\"method\":\"editor/context\",\"params\":{");
    try w.print("\"cursor_row\":{d},\"cursor_col\":{d}", .{ context.cursor_row, context.cursor_col });
    if (context.file_path) |fp| {
        try w.print(",\"file_path\":\"{s}\"", .{fp});
    }
    try w.print(",\"mode\":\"{s}\"", .{context.mode});
    try w.writeAll("}}\n");
    _ = try posix.write(posix.STDOUT_FILENO, self.write_buf.items);
}

fn sendEventImpl(ctx: *anyopaque, event: AgentBackend.AgentEvent) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (!self.connected) return;

    const method: []const u8 = switch (event.type) {
        .file_opened => "editor/fileOpened",
        .file_saved => "editor/fileSaved",
        .content_changed => "editor/contentChanged",
        .mode_changed => "editor/modeChanged",
        .cursor_moved => "editor/cursorMoved",
    };

    self.write_buf.clearRetainingCapacity();
    const w = self.write_buf.writer(self.allocator);
    try w.print("{{\"jsonrpc\":\"2.0\",\"method\":\"{s}\",\"params\":{{", .{method});
    var first = true;
    if (event.file_path) |fp| {
        try w.print("\"file_path\":\"{s}\"", .{fp});
        first = false;
    }
    if (event.mode) |mode| {
        if (!first) try w.writeAll(",");
        try w.print("\"mode\":\"{s}\"", .{mode});
    }
    try w.writeAll("}}\n");
    _ = try posix.write(posix.STDOUT_FILENO, self.write_buf.items);
}

fn pollCommandImpl(ctx: *anyopaque) anyerror!?AgentBackend.AgentCommand {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (!self.connected) return null;

    // Non-blocking read from stdin
    var buf: [4096]u8 = undefined;
    const n = posix.read(posix.STDIN_FILENO, &buf) catch |err| switch (err) {
        error.WouldBlock => return null,
        else => return err,
    };
    if (n == 0) return null;

    // Append to read buffer, look for complete JSON-RPC message
    try self.read_buf.appendSlice(self.allocator, buf[0..n]);

    // Find newline-delimited message
    const newline_pos = std.mem.indexOfScalar(u8, self.read_buf.items, '\n') orelse return null;
    const message = self.read_buf.items[0..newline_pos];

    // Parse JSON-RPC and extract command
    const cmd = parseCommand(message);

    // Remove consumed bytes
    const remaining = self.read_buf.items.len - newline_pos - 1;
    if (remaining > 0) {
        std.mem.copyForwards(u8, self.read_buf.items[0..remaining], self.read_buf.items[newline_pos + 1 ..]);
    }
    self.read_buf.shrinkRetainingCapacity(remaining);

    return cmd;
}

fn isConnectedImpl(ctx: *anyopaque) bool {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.connected;
}

fn infoImpl(_: *anyopaque) AgentBackend.BackendInfo {
    return .{
        .name = "mcp",
        .agent_name = null,
        .transport = .stdio,
    };
}

// ── JSON Parsing ─────────────────────────────────────────────────────

fn parseCommand(message: []const u8) ?AgentBackend.AgentCommand {
    // Simple JSON parsing for agent commands
    // Look for "method" field to determine command type
    const method = extractJsonString(message, "method") orelse return null;

    if (std.mem.eql(u8, method, "editor/insertText")) {
        return .{
            .type = .insert_text,
            .text = extractJsonString(message, "text"),
        };
    } else if (std.mem.eql(u8, method, "editor/openFile")) {
        return .{
            .type = .open_file,
            .path = extractJsonString(message, "path"),
        };
    } else if (std.mem.eql(u8, method, "editor/saveFile")) {
        return .{ .type = .save_file };
    } else if (std.mem.eql(u8, method, "editor/requestContext")) {
        return .{ .type = .request_context };
    }
    return null;
}

fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Simple string extraction: find "key":"value"
    var search_buf: [128]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;
    const start = std.mem.indexOf(u8, json, search) orelse {
        // Try with space after colon: "key": "value"
        const search2 = std.fmt.bufPrint(&search_buf, "\"{s}\": \"", .{key}) catch return null;
        const start2 = std.mem.indexOf(u8, json, search2) orelse return null;
        const val_start = start2 + search2.len;
        const val_end = std.mem.indexOfScalarPos(u8, json, val_start, '"') orelse return null;
        return json[val_start..val_end];
    };
    const val_start = start + search.len;
    const val_end = std.mem.indexOfScalarPos(u8, json, val_start, '"') orelse return null;
    return json[val_start..val_end];
}

// ── Tests ─────────────────────────────────────────────────────────────

test "McpBackend init/deinit" {
    var backend = Self.init(std.testing.allocator);
    defer backend.deinit();
    try std.testing.expect(!backend.connected);
}

test "extractJsonString" {
    const json =
        \\{"jsonrpc":"2.0","method":"editor/insertText","params":{"text":"hello"}}
    ;
    const method = extractJsonString(json, "method");
    try std.testing.expect(method != null);
    try std.testing.expectEqualStrings("editor/insertText", method.?);

    const text = extractJsonString(json, "text");
    try std.testing.expect(text != null);
    try std.testing.expectEqualStrings("hello", text.?);
}

test "parseCommand insert" {
    const json =
        \\{"jsonrpc":"2.0","method":"editor/insertText","params":{"text":"world"}}
    ;
    const cmd = parseCommand(json);
    try std.testing.expect(cmd != null);
    try std.testing.expectEqual(AgentBackend.AgentCommandType.insert_text, cmd.?.type);
    try std.testing.expectEqualStrings("world", cmd.?.text.?);
}

test "parseCommand unknown" {
    const json =
        \\{"jsonrpc":"2.0","method":"unknown/method"}
    ;
    const cmd = parseCommand(json);
    try std.testing.expect(cmd == null);
}
