const std = @import("std");
const Editor = @import("Editor.zig");
const Renderer = @import("Renderer.zig");
const Terminal = @import("Terminal.zig");

// ── Plugin System ─────────────────────────────────────────────────────
// lazy-md's extensible plugin architecture.
//
// Plugins implement the Plugin interface (vtable) to hook into editor
// events, register commands, and extend the UI.
//
// See docs/PLUGIN_GUIDE.md for the full development guide.

pub const PluginInfo = struct {
    name: []const u8,
    version: []const u8,
    author: []const u8,
    description: []const u8,
};

pub const EventType = enum {
    file_open,
    file_save,
    file_close,
    buffer_changed,
    mode_changed,
    cursor_moved,
    command,
    render,
};

pub const PluginEvent = struct {
    type: EventType,
    editor: *Editor,
    // Command-specific data
    command_name: ?[]const u8 = null,
    command_args: ?[]const u8 = null,
};

pub const CommandDef = struct {
    name: []const u8,
    description: []const u8,
    handler: *const fn (*PluginEvent) void,
};

pub const RenderContext = struct {
    renderer: *Renderer,
    x: u16,
    y: u16,
    w: u16,
    h: u16,
};

// ── Plugin Interface ──────────────────────────────────────────────────

pub const Plugin = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        info: *const fn (*anyopaque) PluginInfo,
        init: *const fn (*anyopaque, *Editor) void,
        deinit: *const fn (*anyopaque) void,
        on_event: *const fn (*anyopaque, *PluginEvent) void,
        commands: *const fn (*anyopaque) []const CommandDef,
        render_panel: ?*const fn (*anyopaque, *RenderContext) void,
    };

    pub fn info(self: Plugin) PluginInfo {
        return self.vtable.info(self.ptr);
    }

    pub fn pluginInit(self: Plugin, editor: *Editor) void {
        self.vtable.init(self.ptr, editor);
    }

    pub fn pluginDeinit(self: Plugin) void {
        self.vtable.deinit(self.ptr);
    }

    pub fn onEvent(self: Plugin, event: *PluginEvent) void {
        self.vtable.on_event(self.ptr, event);
    }

    pub fn commands(self: Plugin) []const CommandDef {
        return self.vtable.commands(self.ptr);
    }

    pub fn renderPanel(self: Plugin, ctx: *RenderContext) void {
        if (self.vtable.render_panel) |render_fn| {
            render_fn(self.ptr, ctx);
        }
    }
};

// ── Plugin Manager ────────────────────────────────────────────────────

pub const PluginManager = struct {
    allocator: std.mem.Allocator,
    plugins: std.ArrayList(Plugin),
    command_map: std.StringHashMap(CommandEntry),

    const CommandEntry = struct {
        plugin: Plugin,
        handler: *const fn (*PluginEvent) void,
    };

    pub fn init(allocator: std.mem.Allocator) PluginManager {
        return .{
            .allocator = allocator,
            .plugins = .{},
            .command_map = std.StringHashMap(CommandEntry).init(allocator),
        };
    }

    pub fn deinit(self: *PluginManager) void {
        for (self.plugins.items) |p| {
            p.pluginDeinit();
        }
        self.plugins.deinit(self.allocator);
        self.command_map.deinit();
    }

    pub fn register(self: *PluginManager, plugin: Plugin, editor: *Editor) !void {
        try self.plugins.append(self.allocator, plugin);
        plugin.pluginInit(editor);

        // Register plugin commands
        for (plugin.commands()) |cmd| {
            try self.command_map.put(cmd.name, .{
                .plugin = plugin,
                .handler = cmd.handler,
            });
        }
    }

    pub fn broadcast(self: *PluginManager, event: *PluginEvent) void {
        for (self.plugins.items) |p| {
            p.onEvent(event);
        }
    }

    pub fn executeCommand(self: *PluginManager, name: []const u8, event: *PluginEvent) bool {
        if (self.command_map.get(name)) |entry| {
            event.command_name = name;
            entry.handler(event);
            return true;
        }
        return false;
    }

    pub fn pluginCount(self: *const PluginManager) usize {
        return self.plugins.items.len;
    }

    pub fn getPluginInfo(self: *const PluginManager) []const Plugin {
        return self.plugins.items;
    }
};

// ── Helper: Create Plugin from concrete type ──────────────────────────

pub fn makePlugin(comptime T: type, instance: *T) Plugin {
    const gen = struct {
        fn info(ptr: *anyopaque) PluginInfo {
            const self: *T = @ptrCast(@alignCast(ptr));
            return self.pluginInfo();
        }
        fn pluginInit(ptr: *anyopaque, editor: *Editor) void {
            const self: *T = @ptrCast(@alignCast(ptr));
            self.pluginInit(editor);
        }
        fn pluginDeinit(ptr: *anyopaque) void {
            const self: *T = @ptrCast(@alignCast(ptr));
            self.pluginDeinit();
        }
        fn onEvent(ptr: *anyopaque, event: *PluginEvent) void {
            const self: *T = @ptrCast(@alignCast(ptr));
            self.onEvent(event);
        }
        fn getCommands(ptr: *anyopaque) []const CommandDef {
            const self: *T = @ptrCast(@alignCast(ptr));
            return self.getCommands();
        }
    };

    return .{
        .ptr = instance,
        .vtable = &.{
            .info = gen.info,
            .init = gen.pluginInit,
            .deinit = gen.pluginDeinit,
            .on_event = gen.onEvent,
            .commands = gen.getCommands,
            .render_panel = null,
        },
    };
}

// ── Tests ─────────────────────────────────────────────────────────────

test "plugin manager init/deinit" {
    var pm = PluginManager.init(std.testing.allocator);
    defer pm.deinit();

    try std.testing.expectEqual(@as(usize, 0), pm.pluginCount());
}

test "command map" {
    var pm = PluginManager.init(std.testing.allocator);
    defer pm.deinit();

    try std.testing.expect(!pm.command_map.contains("nonexistent"));
}
