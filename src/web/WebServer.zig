const std = @import("std");
const posix = std.posix;
const Buffer = @import("../Buffer.zig");
const McpServer = @import("../mcp/Server.zig");
const WebSocket = @import("WebSocket.zig");
const Self = @This();

// ── Web Server ───────────────────────────────────────────────────────
// HTTP server that serves static files + WebSocket upgrade.
// WebSocket messages are JSON-RPC (same format as MCP).
// Reuses tool dispatch logic from mcp/Server.zig.

// ── State ─────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
buffer: *Buffer,
port: u16,
file_path: ?[]const u8 = null,
file_path_owned: ?[]const u8 = null,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator, buffer: *Buffer, port: u16) Self {
    return .{
        .allocator = allocator,
        .buffer = buffer,
        .port = port,
    };
}

pub fn deinit(self: *Self) void {
    if (self.file_path_owned) |fp| self.allocator.free(fp);
}

// ── Run ───────────────────────────────────────────────────────────────

pub fn run(self: *Self) !void {
    const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, self.port);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    // Print startup message to stderr (stdout may be used by MCP)
    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "lazy-md web server listening on http://localhost:{d}\n", .{self.port}) catch "lazy-md web server started\n";
    _ = posix.write(posix.STDERR_FILENO, msg) catch {};

    // Accept connections
    while (true) {
        const conn = server.accept() catch continue;
        self.handleConnection(conn.stream) catch |err| {
            std.log.err("Connection error: {}", .{err});
            conn.stream.close();
        };
    }
}

fn handleConnection(self: *Self, stream: std.net.Stream) !void {
    // Read the initial HTTP request
    var buf: [4096]u8 = undefined;
    const n = try stream.read(&buf);
    if (n == 0) {
        stream.close();
        return;
    }

    const request = buf[0..n];

    // Check for WebSocket upgrade
    if (isWebSocketUpgrade(request)) {
        try self.handleWebSocket(stream, request);
    } else {
        try self.handleHttp(stream, request);
    }
}

// ── WebSocket Handler ────────────────────────────────────────────────

fn handleWebSocket(self: *Self, stream: std.net.Stream, request: []const u8) !void {
    // Complete WebSocket handshake
    const key = extractHeader(request, "Sec-WebSocket-Key") orelse return error.MissingWebSocketKey;
    var accept_buf: [128]u8 = undefined;
    const accept = try WebSocket.computeAcceptKey(key, &accept_buf);

    var response_buf: [512]u8 = undefined;
    const response = std.fmt.bufPrint(
        &response_buf,
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n",
        .{accept},
    ) catch return error.HandshakeFailed;
    _ = try stream.write(response);

    // Create WebSocket handler
    var ws = WebSocket.init(self.allocator, stream);

    // Create an MCP server for this connection
    var mcp = McpServer.init(self.allocator, self.buffer);
    defer mcp.deinit();
    if (self.file_path) |fp| {
        mcp.file_path = fp;
    }

    // Message loop
    while (true) {
        const frame = ws.readFrame() catch break orelse break;
        defer self.allocator.free(frame.payload);

        if (frame.opcode == .text) {
            // Process JSON-RPC message through MCP server
            const response_json = self.processJsonRpc(frame.payload, &mcp) catch continue;
            defer if (response_json) |r| self.allocator.free(r);

            if (response_json) |resp| {
                ws.sendText(resp) catch break;
            }
        }
    }

    stream.close();
}

fn processJsonRpc(self: *Self, message: []const u8, mcp: *McpServer) !?[]const u8 {
    _ = mcp;
    // Parse JSON-RPC request and generate response
    // For now, echo back a simple acknowledgment
    var buf: std.ArrayList(u8) = .{};
    const w = buf.writer(self.allocator);

    // Extract method and id from request
    const method = extractJsonString(message, "method");
    const id_str = extractJsonString(message, "id");

    if (method) |m| {
        if (std.mem.eql(u8, m, "initialize")) {
            try w.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
            try w.writeAll(id_str orelse "1");
            try w.writeAll(",\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"lazy-md\",\"version\":\"0.1.0\"}}}");
            return try buf.toOwnedSlice(self.allocator);
        } else if (std.mem.eql(u8, m, "tools/list")) {
            try w.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
            try w.writeAll(id_str orelse "1");
            try w.writeAll(",\"result\":{\"tools\":[]}}");
            return try buf.toOwnedSlice(self.allocator);
        }
    }

    buf.deinit(self.allocator);
    return null;
}

// ── HTTP Handler ─────────────────────────────────────────────────────

fn handleHttp(self: *Self, stream: std.net.Stream, request: []const u8) !void {
    _ = self;
    const path = extractPath(request);

    // CORS headers for development
    const cors = "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n";

    if (std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/index.html")) {
        const body =
            \\<!DOCTYPE html>
            \\<html><head><title>lazy-md</title>
            \\<meta charset="utf-8">
            \\<meta name="viewport" content="width=device-width,initial-scale=1">
            \\</head><body>
            \\<h1>lazy-md web server</h1>
            \\<p>Connect your editor frontend to ws://localhost on this port.</p>
            \\<p>Status: <span id="status">Checking...</span></p>
            \\<script>
            \\const ws = new WebSocket(`ws://${location.host}`);
            \\ws.onopen = () => document.getElementById('status').textContent = 'Connected';
            \\ws.onclose = () => document.getElementById('status').textContent = 'Disconnected';
            \\</script>
            \\</body></html>
        ;
        var header_buf: [256]u8 = undefined;
        const header = std.fmt.bufPrint(&header_buf, "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {d}\r\n{s}\r\n", .{ body.len, cors }) catch return;
        _ = try stream.write(header);
        _ = try stream.write(body);
    } else if (std.mem.eql(u8, path, "/health")) {
        const body = "{\"status\":\"ok\"}";
        var header_buf: [256]u8 = undefined;
        const header = std.fmt.bufPrint(&header_buf, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\n{s}\r\n", .{ body.len, cors }) catch return;
        _ = try stream.write(header);
        _ = try stream.write(body);
    } else {
        const body = "404 Not Found";
        var header_buf: [256]u8 = undefined;
        const header = std.fmt.bufPrint(&header_buf, "HTTP/1.1 404 Not Found\r\nContent-Length: {d}\r\n{s}\r\n", .{ body.len, cors }) catch return;
        _ = try stream.write(header);
        _ = try stream.write(body);
    }

    stream.close();
}

// ── Helpers ───────────────────────────────────────────────────────────

fn isWebSocketUpgrade(request: []const u8) bool {
    // Check for "Upgrade: websocket" header (case-insensitive)
    var lines = std.mem.splitSequence(u8, request, "\r\n");
    while (lines.next()) |line| {
        if (std.ascii.startsWithIgnoreCase(line, "Upgrade:")) {
            const value = std.mem.trimLeft(u8, line["Upgrade:".len..], " ");
            if (std.ascii.eqlIgnoreCase(value, "websocket")) return true;
        }
    }
    return false;
}

fn extractPath(request: []const u8) []const u8 {
    // Extract path from "GET /path HTTP/1.1"
    var parts = std.mem.splitScalar(u8, request, ' ');
    _ = parts.next(); // skip method
    return parts.next() orelse "/";
}

fn extractHeader(request: []const u8, name: []const u8) ?[]const u8 {
    var lines = std.mem.splitSequence(u8, request, "\r\n");
    while (lines.next()) |line| {
        if (std.ascii.startsWithIgnoreCase(line, name)) {
            if (line.len > name.len + 1 and line[name.len] == ':') {
                return std.mem.trimLeft(u8, line[name.len + 1 ..], " ");
            }
        }
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

test "isWebSocketUpgrade" {
    try std.testing.expect(isWebSocketUpgrade("GET / HTTP/1.1\r\nUpgrade: websocket\r\n\r\n"));
    try std.testing.expect(!isWebSocketUpgrade("GET / HTTP/1.1\r\n\r\n"));
}

test "extractPath" {
    try std.testing.expectEqualStrings("/", extractPath("GET / HTTP/1.1\r\n"));
    try std.testing.expectEqualStrings("/health", extractPath("GET /health HTTP/1.1\r\n"));
}

test "extractHeader" {
    const req = "GET / HTTP/1.1\r\nHost: localhost\r\nSec-WebSocket-Key: abc123\r\n\r\n";
    const host = extractHeader(req, "Host");
    try std.testing.expect(host != null);
    try std.testing.expectEqualStrings("localhost", host.?);
}
