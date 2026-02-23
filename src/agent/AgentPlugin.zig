const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Buffer = @import("../Buffer.zig");
const AgentBackend = @import("AgentBackend.zig");
const Self = @This();

// ── State ─────────────────────────────────────────────────────────────

allocator: std.mem.Allocator,
backend: ?AgentBackend = null,
editor: ?*Editor = null,
connected: bool = false,

// ── Init / Deinit ─────────────────────────────────────────────────────

pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    if (self.backend) |b| {
        if (b.isConnected()) b.disconnect();
    }
    self.backend = null;
}

// ── Backend Management ───────────────────────────────────────────────

pub fn setBackend(self: *Self, backend: AgentBackend) void {
    if (self.backend) |b| {
        if (b.isConnected()) b.disconnect();
    }
    self.backend = backend;
}

pub fn connectBackend(self: *Self, config: AgentBackend.AgentConfig) !void {
    if (self.backend) |b| {
        try b.connect(config);
        self.connected = true;
    }
}

pub fn disconnectBackend(self: *Self) void {
    if (self.backend) |b| {
        b.disconnect();
    }
    self.connected = false;
}

// ── Tick (called each frame) ─────────────────────────────────────────

pub fn tick(self: *Self) void {
    const backend = self.backend orelse return;
    if (!backend.isConnected()) return;
    const ed = self.editor orelse return;

    // Poll for commands from the agent
    const cmd = backend.pollCommand() catch return orelse return;
    self.executeCommand(ed, cmd);
}

fn executeCommand(self: *Self, ed: *Editor, cmd: AgentBackend.AgentCommand) void {
    switch (cmd.type) {
        .insert_text => {
            if (cmd.text) |text| {
                // Insert at cursor position (flat offset into buffer)
                const pos = ed.buffer.posToOffset(ed.cursor_row, ed.cursor_col);
                ed.buffer.insertSlice(pos, text) catch {};
            }
        },
        .delete_range => {
            // TODO: Convert line range to flat offset range
        },
        .replace_section => {
            // TODO: Use Navigator to find section bounds and replace
        },
        .open_file => {
            if (cmd.path) |path| {
                ed.openFile(path) catch {};
            }
        },
        .save_file => {
            // TODO: Trigger save via editor command dispatch
        },
        .run_command => {
            // TODO: Execute editor command via plugin system
        },
        .request_context => {
            self.sendCurrentContext() catch {};
        },
    }
}

fn sendCurrentContext(self: *Self) !void {
    const backend = self.backend orelse return;
    const ed = self.editor orelse return;
    try backend.sendContext(.{
        .file_path = ed.file_path,
        .cursor_row = ed.cursor_row,
        .cursor_col = ed.cursor_col,
        .mode = switch (ed.mode) {
            .normal => "normal",
            .insert => "insert",
            .command => "command",
        },
    });
}

// ── Plugin Interface ─────────────────────────────────────────────────

pub fn asPlugin(self: *Self) plugin.Plugin {
    return .{ .ptr = @ptrCast(self), .vtable = &vtable };
}

const vtable = plugin.Plugin.VTable{
    .info = infoImpl,
    .init = initImpl,
    .deinit = deinitImpl,
    .on_event = onEventImpl,
    .commands = commandsImpl,
    .render_panel = null,
};

fn infoImpl(_: *anyopaque) plugin.PluginInfo {
    return .{
        .name = "agent",
        .version = "0.1.0",
        .author = "lazy-md",
        .description = "Bidirectional AI agent communication",
    };
}

fn initImpl(ctx: *anyopaque, ed: *Editor) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.editor = ed;
}

fn deinitImpl(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.deinit();
}

fn onEventImpl(ctx: *anyopaque, event: *plugin.PluginEvent) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const backend = self.backend orelse return;
    if (!backend.isConnected()) return;

    const agent_event: ?AgentBackend.AgentEvent = switch (event.type) {
        .file_open => .{ .type = .file_opened, .file_path = event.editor.file_path },
        .file_save => .{ .type = .file_saved, .file_path = event.editor.file_path },
        .buffer_changed => .{ .type = .content_changed },
        .mode_changed => .{ .type = .mode_changed, .mode = switch (event.editor.mode) {
            .normal => "normal",
            .insert => "insert",
            .command => "command",
        } },
        .cursor_moved => .{ .type = .cursor_moved, .cursor_row = event.editor.cursor_row, .cursor_col = event.editor.cursor_col },
        else => null,
    };

    if (agent_event) |ae| {
        backend.sendEvent(ae) catch {};
    }
}

fn commandsImpl(_: *anyopaque) []const plugin.CommandDef {
    return &command_defs;
}

const command_defs = [_]plugin.CommandDef{
    .{ .name = "agent.connect", .description = "Connect to AI agent", .handler = cmdConnect },
    .{ .name = "agent.disconnect", .description = "Disconnect from AI agent", .handler = cmdDisconnect },
    .{ .name = "agent.ask", .description = "Send prompt to AI agent", .handler = cmdAsk },
    .{ .name = "agent.context", .description = "Send current context to AI agent", .handler = cmdContext },
};

fn cmdConnect(_: *plugin.PluginEvent) void {
    // TODO: Parse args for transport/endpoint
}

fn cmdDisconnect(_: *plugin.PluginEvent) void {
    // TODO: Disconnect
}

fn cmdAsk(_: *plugin.PluginEvent) void {
    // TODO: Send prompt
}

fn cmdContext(_: *plugin.PluginEvent) void {
    // TODO: Send context
}

// ── Tests ─────────────────────────────────────────────────────────────

test "AgentPlugin init/deinit" {
    var ap = Self.init(std.testing.allocator);
    defer ap.deinit();

    try std.testing.expect(ap.backend == null);
    try std.testing.expect(!ap.connected);
}

test "AgentPlugin as plugin" {
    var ap = Self.init(std.testing.allocator);
    defer ap.deinit();

    const p = ap.asPlugin();
    const info = p.info();
    try std.testing.expectEqualStrings("agent", info.name);
}

test "AgentPlugin tick with no backend" {
    var ap = Self.init(std.testing.allocator);
    defer ap.deinit();

    // Should not crash with no backend
    ap.tick();
}
