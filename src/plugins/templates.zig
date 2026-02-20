const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Templates plugin — insert predefined markdown templates.
/// Commands: :tpl.meeting, :tpl.daily, :tpl.readme, :tpl.blog
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "templates", .version = "0.1.0", .author = "lazy-md contributors", .description = "Markdown document templates" };
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
        .{ .name = "tpl.meeting", .description = "Insert meeting notes template", .handler = &insertMeeting },
        .{ .name = "tpl.daily", .description = "Insert daily note template", .handler = &insertDaily },
        .{ .name = "tpl.readme", .description = "Insert README template", .handler = &insertReadme },
        .{ .name = "tpl.blog", .description = "Insert blog post template", .handler = &insertBlog },
    };
}

fn insertTemplate(editor: *Editor, template: []const u8) void {
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, template) catch {
        editor.status.set("Failed to insert template", true);
        return;
    };
    editor.status.set("Template inserted", false);
}

fn insertMeeting(event: *plugin.PluginEvent) void {
    insertTemplate(event.editor,
        \\# Meeting Notes
        \\
        \\**Date:**
        \\**Attendees:**
        \\**Topic:**
        \\
        \\## Agenda
        \\
        \\- [ ] Item 1
        \\- [ ] Item 2
        \\- [ ] Item 3
        \\
        \\## Notes
        \\
        \\
        \\
        \\## Action Items
        \\
        \\- [ ]
        \\
    );
}

fn insertDaily(event: *plugin.PluginEvent) void {
    insertTemplate(event.editor,
        \\# Daily Note
        \\
        \\## Tasks
        \\
        \\- [ ]
        \\
        \\## Notes
        \\
        \\
        \\
        \\## Journal
        \\
        \\
        \\
    );
}

fn insertReadme(event: *plugin.PluginEvent) void {
    insertTemplate(event.editor,
        \\# Project Name
        \\
        \\Short description of the project.
        \\
        \\## Installation
        \\
        \\```bash
        \\# install instructions
        \\```
        \\
        \\## Usage
        \\
        \\```bash
        \\# usage example
        \\```
        \\
        \\## Features
        \\
        \\- Feature 1
        \\- Feature 2
        \\
        \\## License
        \\
        \\MIT
        \\
    );
}

fn insertBlog(event: *plugin.PluginEvent) void {
    insertTemplate(event.editor,
        \\---
        \\title: "Blog Post Title"
        \\date:
        \\tags: []
        \\draft: true
        \\---
        \\
        \\# Blog Post Title
        \\
        \\## Introduction
        \\
        \\
        \\
        \\## Main Content
        \\
        \\
        \\
        \\## Conclusion
        \\
        \\
        \\
    );
}

test "templates plugin info" {
    var p = Self{};
    try std.testing.expectEqualStrings("templates", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 4), cmds.len);
}
