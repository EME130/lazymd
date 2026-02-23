const std = @import("std");
const AgentBackend = @import("AgentBackend.zig");
const Self = @This();

// ── WebSocket Backend ────────────────────────────────────────────────
// Implements AgentBackend for WebSocket transport.
// Bidirectional JSON messages over WebSocket connections.
// Used for both outgoing (editor→agent) and incoming (agent→editor).

// ── State ─────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
connected: bool = false,
endpoint: ?[]const u8 = null,
endpoint_owned: ?[]const u8 = null,
read_buf: std.ArrayList(u8) = .{},
write_buf: std.ArrayList(u8) = .{},
// WebSocket connection state
stream: ?std.net.Stream = null,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    if (self.stream) |s| s.close();
    if (self.endpoint_owned) |e| self.allocator.free(e);
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

fn connectImpl(ctx: *anyopaque, config: AgentBackend.AgentConfig) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const endpoint = config.endpoint orelse return error.MissingEndpoint;

    // Parse host:port from endpoint
    // Expected format: "ws://host:port" or "host:port"
    var host: []const u8 = endpoint;
    var port: u16 = 8080;

    // Strip ws:// prefix
    if (std.mem.startsWith(u8, host, "ws://")) {
        host = host[5..];
    } else if (std.mem.startsWith(u8, host, "wss://")) {
        host = host[6..];
    }

    // Extract port
    if (std.mem.lastIndexOfScalar(u8, host, ':')) |colon| {
        port = std.fmt.parseInt(u16, host[colon + 1 ..], 10) catch 8080;
        host = host[0..colon];
    }

    // TCP connect
    const stream = std.net.tcpConnectToHost(self.allocator, host, port) catch return error.ConnectionFailed;
    self.stream = stream;

    // WebSocket handshake
    try self.sendHandshake(host, port);
    try self.receiveHandshakeResponse();

    // Store endpoint
    if (self.endpoint_owned) |e| self.allocator.free(e);
    self.endpoint_owned = try self.allocator.dupe(u8, endpoint);
    self.endpoint = self.endpoint_owned;
    self.connected = true;
}

fn disconnectImpl(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (self.stream) |s| {
        // Send WebSocket close frame
        self.sendCloseFrame() catch {};
        s.close();
        self.stream = null;
    }
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
    try w.writeAll("}}");

    try self.sendWebSocketFrame(self.write_buf.items);
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
    try w.writeAll("}}");

    try self.sendWebSocketFrame(self.write_buf.items);
}

fn pollCommandImpl(ctx: *anyopaque) anyerror!?AgentBackend.AgentCommand {
    const self: *Self = @ptrCast(@alignCast(ctx));
    if (!self.connected or self.stream == null) return null;

    // Non-blocking read
    const payload = (self.receiveWebSocketFrame() catch return null) orelse return null;
    defer self.allocator.free(payload);

    return parseCommand(payload);
}

fn isConnectedImpl(ctx: *anyopaque) bool {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.connected;
}

fn infoImpl(_: *anyopaque) AgentBackend.BackendInfo {
    return .{
        .name = "websocket",
        .agent_name = null,
        .transport = .websocket,
    };
}

// ── WebSocket Protocol (RFC 6455) ────────────────────────────────────

fn sendHandshake(self: *Self, host: []const u8, port: u16) !void {
    const stream = self.stream orelse return error.NotConnected;
    self.write_buf.clearRetainingCapacity();
    const writer = self.write_buf.writer(self.allocator);
    try writer.print("GET / HTTP/1.1\r\nHost: {s}:{d}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n", .{ host, port });
    _ = try stream.write(self.write_buf.items);
}

fn receiveHandshakeResponse(self: *Self) !void {
    const stream = self.stream orelse return error.NotConnected;
    var buf: [1024]u8 = undefined;
    const n = try stream.read(&buf);
    if (n == 0) return error.ConnectionClosed;
    // Verify HTTP 101 response
    if (!std.mem.startsWith(u8, buf[0..n], "HTTP/1.1 101")) {
        return error.HandshakeFailed;
    }
}

fn sendWebSocketFrame(self: *Self, payload: []const u8) !void {
    const stream = self.stream orelse return error.NotConnected;

    // Text frame with mask
    var header: [14]u8 = undefined;
    header[0] = 0x81; // FIN + text opcode
    var header_len: usize = 2;

    if (payload.len < 126) {
        header[1] = @as(u8, @intCast(payload.len)) | 0x80; // mask bit
    } else if (payload.len < 65536) {
        header[1] = 126 | 0x80;
        header[2] = @intCast(payload.len >> 8);
        header[3] = @intCast(payload.len & 0xFF);
        header_len = 4;
    } else {
        header[1] = 127 | 0x80;
        const len64: u64 = @intCast(payload.len);
        inline for (0..8) |i| {
            header[2 + i] = @intCast((len64 >> @intCast(56 - i * 8)) & 0xFF);
        }
        header_len = 10;
    }

    // Masking key (use simple key for now)
    const mask = [4]u8{ 0x37, 0xfa, 0x21, 0x3d };
    header[header_len] = mask[0];
    header[header_len + 1] = mask[1];
    header[header_len + 2] = mask[2];
    header[header_len + 3] = mask[3];
    header_len += 4;

    _ = try stream.write(header[0..header_len]);

    // Masked payload
    self.write_buf.clearRetainingCapacity();
    try self.write_buf.ensureTotalCapacity(self.allocator, payload.len);
    for (payload, 0..) |b, i| {
        try self.write_buf.append(self.allocator, b ^ mask[i % 4]);
    }
    _ = try stream.write(self.write_buf.items);
}

fn receiveWebSocketFrame(self: *Self) !?[]const u8 {
    const stream = self.stream orelse return null;

    var header: [2]u8 = undefined;
    const hn = stream.read(&header) catch return null;
    if (hn < 2) return null;

    const is_masked = (header[1] & 0x80) != 0;
    var payload_len: u64 = header[1] & 0x7F;

    if (payload_len == 126) {
        var ext: [2]u8 = undefined;
        const ext_n = stream.read(&ext) catch return null;
        if (ext_n < 2) return null;
        payload_len = (@as(u64, ext[0]) << 8) | ext[1];
    } else if (payload_len == 127) {
        var ext: [8]u8 = undefined;
        const ext_n8 = stream.read(&ext) catch return null;
        if (ext_n8 < 8) return null;
        payload_len = 0;
        inline for (0..8) |i| {
            payload_len = (payload_len << 8) | ext[i];
        }
    }

    var mask: [4]u8 = .{ 0, 0, 0, 0 };
    if (is_masked) {
        const mask_n = stream.read(&mask) catch return null;
        if (mask_n < 4) return null;
    }

    if (payload_len > 1024 * 1024) return error.PayloadTooLarge; // 1MB limit
    const len: usize = @intCast(payload_len);
    const payload = try self.allocator.alloc(u8, len);
    errdefer self.allocator.free(payload);

    var total: usize = 0;
    while (total < len) {
        const n = stream.read(payload[total..]) catch {
            self.allocator.free(payload);
            return null;
        };
        if (n == 0) {
            self.allocator.free(payload);
            return null;
        }
        total += n;
    }

    if (is_masked) {
        for (payload, 0..) |*b, i| {
            b.* ^= mask[i % 4];
        }
    }

    return payload;
}

fn sendCloseFrame(self: *Self) !void {
    const stream = self.stream orelse return;
    const close_frame = [_]u8{
        0x88, // FIN + close opcode
        0x80, // masked, 0 length
        0x00, 0x00, 0x00, 0x00, // mask
    };
    _ = try stream.write(&close_frame);
}

fn parseCommand(message: []const u8) ?AgentBackend.AgentCommand {
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
    var search_buf: [128]u8 = undefined;
    const search = std.fmt.bufPrint(&search_buf, "\"{s}\":\"", .{key}) catch return null;
    const start = std.mem.indexOf(u8, json, search) orelse {
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

test "WebSocketBackend init/deinit" {
    var backend = Self.init(std.testing.allocator);
    defer backend.deinit();
    try std.testing.expect(!backend.connected);
}

test "WebSocketBackend info" {
    var backend = Self.init(std.testing.allocator);
    defer backend.deinit();
    const ab = backend.agentBackend();
    const bi = ab.info();
    try std.testing.expectEqualStrings("websocket", bi.name);
    try std.testing.expectEqual(AgentBackend.Transport.websocket, bi.transport);
}
