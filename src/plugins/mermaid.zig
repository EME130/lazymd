const std = @import("std");
const plugin = @import("../plugin.zig");
const Editor = @import("../Editor.zig");
const Self = @This();

/// Mermaid plugin — insert mermaid diagram templates.
/// Templates for flowcharts, sequences, gantt, class diagrams.
/// Commands: :mermaid, :mermaid.flow, :mermaid.seq, :mermaid.gantt
pub fn pluginInfo(self: *Self) plugin.PluginInfo {
    _ = self;
    return .{ .name = "mermaid", .version = "0.1.0", .author = "lazy-md contributors", .description = "Mermaid diagram support" };
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
        .{ .name = "mermaid", .description = "Insert mermaid flowchart", .handler = &insertFlow },
        .{ .name = "mermaid.flow", .description = "Insert flowchart template", .handler = &insertFlow },
        .{ .name = "mermaid.seq", .description = "Insert sequence diagram", .handler = &insertSeq },
        .{ .name = "mermaid.gantt", .description = "Insert gantt chart", .handler = &insertGantt },
    };
}

fn insertTemplate(editor: *Editor, template: []const u8) void {
    const offset = editor.buffer.posToOffset(editor.cursor_row, editor.cursor_col);
    editor.buffer.insertSlice(offset, template) catch {
        editor.status.set("Failed to insert diagram", true);
        return;
    };
    editor.status.set("Mermaid diagram inserted", false);
}

fn insertFlow(event: *plugin.PluginEvent) void {
    insertTemplate(event.editor,
        \\```mermaid
        \\graph TD
        \\    A[Start] --> B{Decision}
        \\    B -->|Yes| C[Action]
        \\    B -->|No| D[End]
        \\```
        \\
    );
}

fn insertSeq(event: *plugin.PluginEvent) void {
    insertTemplate(event.editor,
        \\```mermaid
        \\sequenceDiagram
        \\    Alice->>Bob: Hello
        \\    Bob-->>Alice: Hi there
        \\    Alice->>Bob: How are you?
        \\    Bob-->>Alice: Great!
        \\```
        \\
    );
}

fn insertGantt(event: *plugin.PluginEvent) void {
    insertTemplate(event.editor,
        \\```mermaid
        \\gantt
        \\    title Project Timeline
        \\    dateFormat YYYY-MM-DD
        \\    section Phase 1
        \\    Task 1 :a1, 2024-01-01, 30d
        \\    Task 2 :after a1, 20d
        \\    section Phase 2
        \\    Task 3 :2024-02-20, 15d
        \\```
        \\
    );
}

test "mermaid plugin" {
    var p = Self{};
    try std.testing.expectEqualStrings("mermaid", p.pluginInfo().name);
    const cmds = p.getCommands();
    try std.testing.expectEqual(@as(usize, 4), cmds.len);
}
