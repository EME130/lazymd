const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// File Recovery plugin — save snapshots for crash recovery.
/// Saves current buffer to .lazy-md/snapshots/ directory.
/// Commands: :recover, :recover.list, :recover.save
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "file-recovery", .version = "0.1.0", .author = "lazy-md contributors", .description = "Auto-save snapshots and crash recovery" };
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
        .{ .name = "recover", .description = "Recover last snapshot", .handler = &recover },
        .{ .name = "recover.list", .description = "List recovery snapshots", .handler = &listSnapshots },
        .{ .name = "recover.save", .description = "Save manual snapshot", .handler = &saveSnapshot },
    };
}

fn ensureDir() bool {
    std.fs.cwd().makeDir(".lazy-md") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return false,
    };
    std.fs.cwd().makeDir(".lazy-md/snapshots") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return false,
    };
    return true;
}

fn saveSnapshot(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    if (!ensureDir()) {
        editor.status.set("Cannot create .lazy-md/snapshots/ directory", true);
        return;
    }

    // Generate snapshot filename from timestamp
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();

    // Get current filename stem
    const file_stem = blk: {
        if (editor.file_path) |fp| {
            if (std.mem.lastIndexOfScalar(u8, fp, '/')) |slash| break :blk fp[slash + 1 ..];
            break :blk fp;
        }
        break :blk "untitled";
    };

    var path_buf: [192]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, ".lazy-md/snapshots/{s}.{d:0>4}{d:0>2}{d:0>2}-{d:0>2}{d:0>2}{d:0>2}", .{
        file_stem,
        yd.year,
        @as(u9, @intFromEnum(md.month)) + 1,
        md.day_index + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    }) catch {
        editor.status.set("Path too long", true);
        return;
    };

    // Write buffer content to snapshot
    const file = std.fs.cwd().createFile(path, .{}) catch {
        editor.status.set("Failed to create snapshot", true);
        return;
    };
    defer file.close();

    for (0..editor.buffer.lineCount()) |row| {
        const line = editor.buffer.getLine(row);
        file.writeAll(line) catch break;
        file.writeAll("\n") catch break;
    }

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Snapshot saved: {s}", .{path}) catch "Saved";
    editor.status.set(msg, false);
}

fn listSnapshots(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var dir = std.fs.cwd().openDir(".lazy-md/snapshots", .{ .iterate = true }) catch {
        editor.status.set("No snapshots directory. Use :recover.save first", false);
        return;
    };
    defer dir.close();

    var count: usize = 0;
    var last_name: [64]u8 = undefined;
    var last_len: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file) {
            count += 1;
            const max = @min(entry.name.len, last_name.len);
            @memcpy(last_name[0..max], entry.name[0..max]);
            last_len = max;
        }
    }

    var buf: [128]u8 = undefined;
    if (count == 0) {
        editor.status.set("No snapshots found. Use :recover.save to create one", false);
    } else {
        const msg = std.fmt.bufPrint(&buf, "Snapshots: {d} found. Latest: {s}", .{ count, last_name[0..last_len] }) catch "Snapshots found";
        editor.status.set(msg, false);
    }
}

fn recover(event: *plugin.PluginEvent) void {
    const editor = event.editor;

    var dir = std.fs.cwd().openDir(".lazy-md/snapshots", .{ .iterate = true }) catch {
        editor.status.set("No snapshots to recover from", false);
        return;
    };
    defer dir.close();

    // Find newest snapshot matching current file
    const file_stem = blk: {
        if (editor.file_path) |fp| {
            if (std.mem.lastIndexOfScalar(u8, fp, '/')) |slash| break :blk fp[slash + 1 ..];
            break :blk fp;
        }
        break :blk "untitled";
    };

    var best_name: [128]u8 = undefined;
    var best_len: usize = 0;
    var found = false;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.startsWith(u8, entry.name, file_stem)) {
            const max = @min(entry.name.len, best_name.len);
            @memcpy(best_name[0..max], entry.name[0..max]);
            best_len = max;
            found = true;
        }
    }

    if (!found) {
        editor.status.set("No snapshot found for current file", false);
        return;
    }

    var path_buf: [192]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, ".lazy-md/snapshots/{s}", .{best_name[0..best_len]}) catch {
        editor.status.set("Path error", true);
        return;
    };

    // Load snapshot content into buffer
    const file = std.fs.cwd().openFile(path, .{}) catch {
        editor.status.set("Failed to open snapshot", true);
        return;
    };
    defer file.close();

    var read_buf: [8192]u8 = undefined;
    const n = file.readAll(&read_buf) catch {
        editor.status.set("Failed to read snapshot", true);
        return;
    };

    // Clear and replace buffer content
    const buf_len = editor.buffer.length();
    if (buf_len > 0) {
        editor.buffer.deleteRange(0, buf_len) catch {};
    }
    editor.buffer.insertSlice(0, read_buf[0..n]) catch {
        editor.status.set("Failed to restore snapshot", true);
        return;
    };
    editor.cursor_row = 0;
    editor.cursor_col = 0;

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Recovered from: {s}", .{best_name[0..best_len]}) catch "Recovered";
    editor.status.set(msg, false);
}

test "file_recovery plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("file-recovery", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 3), cmds.len);
}
