const std = @import("std");
const posix = std.posix;
const Self = @This();

// ── WebSocket Frame Handler (RFC 6455) ───────────────────────────────
// Handles text frames (JSON messages), ping/pong, close.

pub const Opcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
};

pub const Frame = struct {
    fin: bool,
    opcode: Opcode,
    payload: []const u8,
};

// ── State ─────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
stream: std.net.Stream,
read_buf: [65536]u8 = undefined,
closed: bool = false,

// ── Init ──────────────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator, stream: std.net.Stream) Self {
    return .{
        .allocator = allocator,
        .stream = stream,
    };
}

// ── Handshake ─────────────────────────────────────────────────────────

pub fn acceptHandshake(self: *Self) !void {
    // Read HTTP upgrade request
    const n = try self.stream.read(&self.read_buf);
    if (n == 0) return error.ConnectionClosed;

    const request = self.read_buf[0..n];

    // Extract Sec-WebSocket-Key
    const key = extractHeader(request, "Sec-WebSocket-Key") orelse return error.MissingWebSocketKey;

    // Compute accept value
    var accept_buf: [128]u8 = undefined;
    const accept = computeAcceptKey(key, &accept_buf) catch return error.HandshakeFailed;

    // Send 101 Switching Protocols response
    var response_buf: [512]u8 = undefined;
    const response = std.fmt.bufPrint(
        &response_buf,
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {s}\r\n\r\n",
        .{accept},
    ) catch return error.HandshakeFailed;

    _ = try self.stream.write(response);
}

// ── Read Frame ────────────────────────────────────────────────────────

pub fn readFrame(self: *Self) !?Frame {
    if (self.closed) return null;

    // Read header (2 bytes minimum)
    var header: [2]u8 = undefined;
    const hn = self.stream.read(&header) catch return null;
    if (hn < 2) return null;

    const fin = (header[0] & 0x80) != 0;
    const opcode_raw: u4 = @intCast(header[0] & 0x0F);
    const opcode: Opcode = @enumFromInt(opcode_raw);
    const is_masked = (header[1] & 0x80) != 0;
    var payload_len: u64 = header[1] & 0x7F;

    // Extended payload length
    if (payload_len == 126) {
        var ext: [2]u8 = undefined;
        const en = self.stream.read(&ext) catch return null;
        if (en < 2) return null;
        payload_len = (@as(u64, ext[0]) << 8) | ext[1];
    } else if (payload_len == 127) {
        var ext: [8]u8 = undefined;
        const en = self.stream.read(&ext) catch return null;
        if (en < 8) return null;
        payload_len = 0;
        inline for (0..8) |i| {
            payload_len = (payload_len << 8) | ext[i];
        }
    }

    // Masking key
    var mask: [4]u8 = .{ 0, 0, 0, 0 };
    if (is_masked) {
        const mn = self.stream.read(&mask) catch return null;
        if (mn < 4) return null;
    }

    // Payload
    if (payload_len > 1024 * 1024) return error.PayloadTooLarge;
    const len: usize = @intCast(payload_len);
    const payload = try self.allocator.alloc(u8, len);

    var total: usize = 0;
    while (total < len) {
        const rn = self.stream.read(payload[total..]) catch {
            self.allocator.free(payload);
            return null;
        };
        if (rn == 0) {
            self.allocator.free(payload);
            return null;
        }
        total += rn;
    }

    // Unmask
    if (is_masked) {
        for (payload, 0..) |*b, i| {
            b.* ^= mask[i % 4];
        }
    }

    // Handle control frames
    switch (opcode) {
        .close => {
            self.closed = true;
            // Send close response
            self.sendCloseFrame() catch {};
            self.allocator.free(payload);
            return null;
        },
        .ping => {
            // Respond with pong
            self.sendFrame(.pong, payload) catch {};
            self.allocator.free(payload);
            return self.readFrame();
        },
        .pong => {
            self.allocator.free(payload);
            return self.readFrame();
        },
        else => {},
    }

    return .{
        .fin = fin,
        .opcode = opcode,
        .payload = payload,
    };
}

// ── Write Frame ───────────────────────────────────────────────────────

pub fn sendText(self: *Self, payload: []const u8) !void {
    try self.sendFrame(.text, payload);
}

pub fn sendFrame(self: *Self, opcode: Opcode, payload: []const u8) !void {
    if (self.closed) return error.ConnectionClosed;

    // Header: FIN + opcode
    var header: [10]u8 = undefined;
    header[0] = 0x80 | @as(u8, @intFromEnum(opcode)); // FIN + opcode
    var header_len: usize = 2;

    // Server doesn't mask (per RFC 6455)
    if (payload.len < 126) {
        header[1] = @intCast(payload.len);
    } else if (payload.len < 65536) {
        header[1] = 126;
        header[2] = @intCast(payload.len >> 8);
        header[3] = @intCast(payload.len & 0xFF);
        header_len = 4;
    } else {
        header[1] = 127;
        const len64: u64 = @intCast(payload.len);
        inline for (0..8) |i| {
            header[2 + i] = @intCast((len64 >> @intCast(56 - i * 8)) & 0xFF);
        }
        header_len = 10;
    }

    _ = try self.stream.write(header[0..header_len]);
    if (payload.len > 0) {
        _ = try self.stream.write(payload);
    }
}

fn sendCloseFrame(self: *Self) !void {
    try self.sendFrame(.close, &[_]u8{});
}

// ── Helpers ───────────────────────────────────────────────────────────

fn extractHeader(request: []const u8, name: []const u8) ?[]const u8 {
    var lines = std.mem.splitSequence(u8, request, "\r\n");
    while (lines.next()) |line| {
        if (std.ascii.startsWithIgnoreCase(line, name)) {
            if (line.len > name.len + 2 and line[name.len] == ':') {
                const value = std.mem.trimLeft(u8, line[name.len + 1 ..], " ");
                return value;
            }
        }
    }
    return null;
}

pub fn computeAcceptKey(key: []const u8, out: []u8) ![]const u8 {
    const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update(key);
    hasher.update(magic);
    var digest: [20]u8 = undefined;
    hasher.final(&digest);

    // Base64 encode
    return std.base64.standard.Encoder.encode(out, &digest);
}

// ── Tests ─────────────────────────────────────────────────────────────

test "extractHeader" {
    const request = "GET / HTTP/1.1\r\nHost: localhost\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n";
    const key = extractHeader(request, "Sec-WebSocket-Key");
    try std.testing.expect(key != null);
    try std.testing.expectEqualStrings("dGhlIHNhbXBsZSBub25jZQ==", key.?);
}

test "computeAcceptKey" {
    var buf: [128]u8 = undefined;
    const accept = try computeAcceptKey("dGhlIHNhbXBsZSBub25jZQ==", &buf);
    try std.testing.expectEqualStrings("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", accept);
}
