const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Project Manager plugin — show vault info and manage project structure.
/// Commands: :project, :project.stats, :project.new
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "project-manager", .version = "0.1.0", .author = "lazy-md contributors", .description = "Switch between project vaults" };
}
pub fn pluginInit(self: *Self, editor: *Editor) void {
    _ = self;
    _ = editor;
}
pub fn pluginDeinit(self: *Self) void {
    _ = self;
}
pub fn onEvent(self: *Self, event: *plugin.PluginEvent) void {
    _ = self;
    _ = event;
}
pub fn getCommands(self: *Self) []const plugin.CommandDef {
    _ = self;
    return &[_]plugin.CommandDef{
        .{ .name = "project", .description = "Show vault stats", .handler = &showProject },
        .{ .name = "project.stats", .description = "Detailed vault statistics", .handler = &showStats },
        .{ .name = "project.new", .description = "Initialize new vault", .handler = &newProject },
    };
}

fn showProject(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Get CWD name
    var cwd_buf: [256]u8 = undefined;
    const cwd = std.fs.cwd().realpath(".", &cwd_buf) catch {
        editor.status.set("Vault: current directory", false);
        return;
    };

    // Get vault name from last path component
    const vault_name = blk: {
        if (std.mem.lastIndexOfScalar(u8, cwd, '/')) |slash| break :blk cwd[slash + 1 ..];
        break :blk cwd;
    };

    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Vault: {s} ({s})", .{ vault_name, cwd }) catch "Current vault";
    editor.status.set(msg, false);
}

fn showStats(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan vault", true);
        return;
    };
    defer dir.close();

    var md_count: usize = 0;
    var rndm_count: usize = 0;
    var dir_count: usize = 0;
    var total_size: u64 = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.name[0] == '.') continue;
        if (entry.kind == .directory) {
            dir_count += 1;
        } else if (entry.kind == .file) {
            if (std.mem.endsWith(u8, entry.name, ".md")) {
                md_count += 1;
                const stat = dir.statFile(entry.name) catch continue;
                total_size += stat.size;
            } else if (std.mem.endsWith(u8, entry.name, ".rndm")) {
                rndm_count += 1;
                const stat = dir.statFile(entry.name) catch continue;
                total_size += stat.size;
            }
        }
    }

    const size_kb = total_size / 1024;
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Vault: {d} .md, {d} .rndm, {d} folders, {d}KB total", .{ md_count, rndm_count, dir_count, size_kb }) catch "Stats";
    editor.status.set(msg, false);
}

fn newProject(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const name = event.command_args orelse {
        editor.status.set("Usage: :project.new <name>", true);
        return;
    };

    // Create project directory with standard structure
    std.fs.cwd().makeDir(name) catch |err| switch (err) {
        error.PathAlreadyExists => {
            editor.status.set("Project directory already exists", true);
            return;
        },
        else => {
            editor.status.set("Cannot create project directory", true);
            return;
        },
    };

    // Create subdirectories
    const subdirs = [_][]const u8{ "daily", "templates", "attachments" };
    for (&subdirs) |sub| {
        var path_buf: [128]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ name, sub }) catch continue;
        std.fs.cwd().makeDir(path) catch {};
    }

    // Create README
    var path_buf: [128]u8 = undefined;
    const readme = std.fmt.bufPrint(&path_buf, "{s}/README.md", .{name}) catch {
        editor.status.set("Path error", true);
        return;
    };
    const file = std.fs.cwd().createFile(readme, .{ .exclusive = true }) catch {
        editor.status.set("Created project but failed to create README", false);
        return;
    };
    var tpl_buf: [256]u8 = undefined;
    const tpl = std.fmt.bufPrint(&tpl_buf,
        \\# {s}
        \\
        \\A lazy-md vault.
        \\
        \\## Structure
        \\
        \\- `daily/` — Daily notes
        \\- `templates/` — Note templates
        \\- `attachments/` — Files and images
        \\
    , .{name}) catch "";
    file.writeAll(tpl) catch {};
    file.close();

    var msg_buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Project created: {s}/", .{name}) catch "Created";
    editor.status.set(msg, false);
}

test "project_manager plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("project-manager", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
