const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Random Note plugin — open a random note for serendipitous discovery.
/// Scans current directory for .md/.rndm files and opens one at random.
/// Commands: :random
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "random-note", .version = "0.1.0", .author = "lazy-md contributors", .description = "Open a random note" };
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
        .{ .name = "random", .description = "Open random note", .handler = &openRandom },
    };
}

fn openRandom(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    // Collect markdown files
    var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch {
        editor.status.set("Cannot scan directory", true);
        return;
    };
    defer dir.close();

    // We'll use a simple reservoir sampling approach with count
    var count: usize = 0;
    var chosen: [256]u8 = undefined;
    var chosen_len: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        const is_md = std.mem.endsWith(u8, entry.name, ".md") or
            std.mem.endsWith(u8, entry.name, ".rndm");
        if (!is_md) continue;
        // Skip currently open file
        if (editor.file_path) |fp| {
            if (std.mem.eql(u8, std.fs.path.basename(fp), entry.name)) continue;
        }

        count += 1;
        // Reservoir sampling: replace with probability 1/count
        // Use timestamp as pseudo-random seed
        const ts: u64 = @intCast(std.time.timestamp());
        const hash = ts *% 6364136223846793005 +% count *% 1442695040888963407;
        if (hash % count == 0 and entry.name.len <= chosen.len) {
            @memcpy(chosen[0..entry.name.len], entry.name);
            chosen_len = entry.name.len;
        }
    }

    if (count == 0) {
        editor.status.set("No markdown files found", false);
        return;
    }

    if (chosen_len > 0) {
        editor.openFile(chosen[0..chosen_len]) catch {
            editor.status.set("Failed to open random note", true);
            return;
        };
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "Random note: {s} (1 of {d})", .{ chosen[0..chosen_len], count }) catch "Opened";
        editor.status.set(msg, false);
    }
}

test "random_note plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("random-note", p.pluginInfo().name);
}
