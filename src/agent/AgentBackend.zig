const std = @import("std");
const Allocator = std.mem.Allocator;

const Self = @This();

// ── Config & Types ───────────────────────────────────────────────────

pub const Transport = enum {
    stdio,
    websocket,
    http,
};

pub const AgentConfig = struct {
    model: ?[]const u8 = null,
    api_key: ?[]const u8 = null,
    endpoint: ?[]const u8 = null,
    transport: Transport = .stdio,
};

pub const EditorContext = struct {
    file_path: ?[]const u8 = null,
    content: ?[]const u8 = null,
    cursor_row: usize = 0,
    cursor_col: usize = 0,
    mode: []const u8 = "normal",
    structure: ?[]const u8 = null,
};

pub const AgentEventType = enum {
    file_opened,
    file_saved,
    content_changed,
    mode_changed,
    cursor_moved,
};

pub const AgentEvent = struct {
    type: AgentEventType,
    file_path: ?[]const u8 = null,
    content: ?[]const u8 = null,
    cursor_row: ?usize = null,
    cursor_col: ?usize = null,
    mode: ?[]const u8 = null,
};

pub const AgentCommandType = enum {
    insert_text,
    delete_range,
    replace_section,
    open_file,
    save_file,
    run_command,
    request_context,
};

pub const AgentCommand = struct {
    type: AgentCommandType,
    // insert_text
    text: ?[]const u8 = null,
    line: ?usize = null,
    col: ?usize = null,
    // delete_range
    start_line: ?usize = null,
    end_line: ?usize = null,
    // replace_section
    heading: ?[]const u8 = null,
    // open_file / run_command
    path: ?[]const u8 = null,
    command: ?[]const u8 = null,
};

pub const BackendInfo = struct {
    name: []const u8,
    agent_name: ?[]const u8 = null,
    transport: Transport,
};

// ── VTable ───────────────────────────────────────────────────────────

pub const VTable = struct {
    /// Connect to the agent backend with the given config.
    connect: *const fn (ctx: *anyopaque, config: AgentConfig) anyerror!void,

    /// Disconnect from the agent backend.
    disconnect: *const fn (ctx: *anyopaque) void,

    /// Send current editor context to the agent.
    sendContext: *const fn (ctx: *anyopaque, context: EditorContext) anyerror!void,

    /// Send an editor event notification to the agent.
    sendEvent: *const fn (ctx: *anyopaque, event: AgentEvent) anyerror!void,

    /// Poll for the next command from the agent. Returns null if no command pending.
    pollCommand: *const fn (ctx: *anyopaque) anyerror!?AgentCommand,

    /// Check if currently connected to an agent.
    isConnected: *const fn (ctx: *anyopaque) bool,

    /// Get info about this backend.
    info: *const fn (ctx: *anyopaque) BackendInfo,
};

// ── Fields ───────────────────────────────────────────────────────────

ptr: *anyopaque,
vtable: *const VTable,

// ── Dispatch Methods ─────────────────────────────────────────────────

pub fn connect(self: Self, config: AgentConfig) !void {
    return self.vtable.connect(self.ptr, config);
}

pub fn disconnect(self: Self) void {
    self.vtable.disconnect(self.ptr);
}

pub fn sendContext(self: Self, context: EditorContext) !void {
    return self.vtable.sendContext(self.ptr, context);
}

pub fn sendEvent(self: Self, event: AgentEvent) !void {
    return self.vtable.sendEvent(self.ptr, event);
}

pub fn pollCommand(self: Self) !?AgentCommand {
    return self.vtable.pollCommand(self.ptr);
}

pub fn isConnected(self: Self) bool {
    return self.vtable.isConnected(self.ptr);
}

pub fn info(self: Self) BackendInfo {
    return self.vtable.info(self.ptr);
}

// ── Tests ─────────────────────────────────────────────────────────────

test "AgentBackend vtable compiles" {
    const vtable = VTable{
        .connect = undefined,
        .disconnect = undefined,
        .sendContext = undefined,
        .sendEvent = undefined,
        .pollCommand = undefined,
        .isConnected = undefined,
        .info = undefined,
    };
    _ = vtable;
}

test "AgentConfig defaults" {
    const config = AgentConfig{};
    try std.testing.expectEqual(Transport.stdio, config.transport);
    try std.testing.expect(config.model == null);
}

test "AgentCommand types" {
    const cmd = AgentCommand{ .type = .insert_text, .text = "hello", .line = 5 };
    try std.testing.expectEqual(AgentCommandType.insert_text, cmd.type);
    try std.testing.expectEqualStrings("hello", cmd.text.?);
}
