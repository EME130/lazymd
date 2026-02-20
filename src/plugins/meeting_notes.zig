const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Meeting Notes plugin — create structured meeting note files.
/// Creates meetings/ directory with timestamped files.
/// Commands: :meeting, :meeting.new
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "meeting-notes", .version = "0.1.0", .author = "lazy-md contributors", .description = "Structured meeting notes" };
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
        .{ .name = "meeting", .description = "List meeting notes", .handler = &listMeetings },
        .{ .name = "meeting.new", .description = "Create new meeting note", .handler = &newMeeting },
    };
}

fn listMeetings(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    var count: usize = 0;

    var dir = std.fs.cwd().openDir("meetings", .{ .iterate = true }) catch {
        editor.status.set("No meetings/ directory. Use :meeting.new to start", false);
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".md")) {
            count += 1;
        }
    }

    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Meetings: {d} notes in meetings/", .{count}) catch "Meetings found";
    editor.status.set(msg, false);
}

fn newMeeting(event: *plugin.PluginEvent) void {
    const editor = event.editor;
    const title = event.command_args orelse "meeting";

    // Create directory
    std.fs.cwd().makeDir("meetings") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => {
            editor.status.set("Cannot create meetings/ directory", true);
            return;
        },
    };

    // Generate filename with date
    const epoch = std.time.timestamp();
    const es = std.time.epoch.EpochSeconds{ .secs = @intCast(@as(u64, @intCast(epoch))) };
    const yd = es.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();

    var path_buf: [128]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "meetings/{d:0>4}-{d:0>2}-{d:0>2}-{s}.md", .{
        yd.year,
        @intFromEnum(md.month) + 1,
        md.day_index + 1,
        title,
    }) catch {
        editor.status.set("Filename too long", true);
        return;
    };

    var tpl_buf: [512]u8 = undefined;
    const template = std.fmt.bufPrint(&tpl_buf,
        \\---
        \\title: "{s}"
        \\date: {d:0>4}-{d:0>2}-{d:0>2}
        \\attendees: []
        \\---
        \\
        \\# {s}
        \\
        \\## Attendees
        \\
        \\-
        \\
        \\## Agenda
        \\
        \\- [ ]
        \\
        \\## Notes
        \\
        \\
        \\
        \\## Action Items
        \\
        \\- [ ]
        \\
    , .{
        title,
        yd.year,
        @intFromEnum(md.month) + 1,
        md.day_index + 1,
        title,
    }) catch {
        editor.status.set("Template error", true);
        return;
    };

    const file = std.fs.cwd().createFile(path, .{ .exclusive = true }) catch {
        editor.status.set("Meeting file already exists", true);
        return;
    };
    file.writeAll(template) catch {};
    file.close();

    editor.openFile(path) catch {
        editor.status.set("Failed to open meeting note", true);
        return;
    };

    var msg_buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&msg_buf, "Meeting note: {s}", .{path}) catch "Created";
    editor.status.set(msg, false);
}

test "meeting_notes plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("meeting-notes", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 2), cmds.len);
}
