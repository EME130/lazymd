const std = @import("std");
const Terminal = @import("Terminal.zig");
const Input = @import("Input.zig");
const Buffer = @import("Buffer.zig");
const Editor = @import("Editor.zig");
const Renderer = @import("Renderer.zig");
const Layout = @import("ui/Layout.zig");
const Preview = @import("ui/Preview.zig");
const plugin = @import("plugin.zig");
const McpServer = @import("mcp/Server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var file_path: ?[]const u8 = null;
    var mcp_mode = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--mcp-server") or std.mem.eql(u8, arg, "--mcp")) {
            mcp_mode = true;
        } else {
            file_path = arg;
        }
    }

    // MCP server mode: JSON-RPC 2.0 over stdio
    if (mcp_mode) {
        var buffer = try Buffer.init(allocator);
        defer buffer.deinit();
        var server = McpServer.init(allocator, &buffer);
        defer server.deinit();

        if (file_path) |path| {
            server.buffer.loadFile(path) catch {};
            const owned = try allocator.dupe(u8, path);
            server.file_path_owned = owned;
            server.file_path = owned;
        }

        try server.run();
        return;
    }

    // Initialize terminal
    var term = try Terminal.init(allocator);
    defer term.deinit();

    // Initialize subsystems
    var input = Input.init(&term);
    var renderer = try Renderer.init(allocator, &term);
    defer renderer.deinit();
    var editor = try Editor.init(allocator);
    defer editor.deinit();
    var layout = Layout{};
    var preview = Preview.init(allocator);
    defer preview.deinit();
    var plugin_mgr = plugin.PluginManager.init(allocator);
    defer plugin_mgr.deinit();

    // Wire plugin system into editor
    editor.plugin_mgr = &plugin_mgr;

    // Open file if provided
    if (file_path) |path| {
        editor.openFile(path) catch {
            editor.status.set("New file", false);
            const owned = try allocator.dupe(u8, path);
            editor.file_path_owned = owned;
            editor.file_path = owned;
        };
    }

    // Scan working directory for file tree
    var file_entries: std.ArrayList(Layout.FileEntry) = .{};
    defer {
        for (file_entries.items) |entry| allocator.free(entry.name);
        file_entries.deinit(allocator);
    }
    try scanDirectory(allocator, ".", &file_entries);

    // Main loop
    while (!editor.should_quit) {
        // Check for resize
        if (term.updateSize()) {
            try renderer.resize();
            renderer.forceRedraw();
        }

        // Compute layout
        layout.compute(term.width, term.height);

        // Update editor viewport
        editor.view_x = layout.editor_rect.x;
        editor.view_y = layout.editor_rect.y;
        editor.view_width = layout.editor_rect.w;
        editor.view_height = layout.editor_rect.h;

        // Draw
        renderer.clear();
        layout.renderChrome(&renderer);
        layout.renderFileTree(&renderer, file_entries.items);
        try editor.render(&renderer);
        editor.renderStatusBar(&renderer, layout.status_rect.y);
        editor.renderCommandBar(&renderer, layout.cmd_rect.y);
        layout.renderPreview(&renderer, &editor, &preview);

        try renderer.flush();

        // Handle input
        const event = try input.poll();
        switch (event) {
            .key => |key| {
                // Global shortcuts
                if (key.code == .tab and !key.ctrl and editor.mode == .normal) {
                    layout.cyclePanel();
                    continue;
                }
                if (key.code == .char and editor.mode == .normal) {
                    switch (key.code.char) {
                        '1' => if (key.alt) {
                            layout.togglePanel(.file_tree);
                            layout.compute(term.width, term.height);
                            renderer.forceRedraw();
                            continue;
                        },
                        '2' => if (key.alt) {
                            layout.togglePanel(.preview);
                            layout.compute(term.width, term.height);
                            renderer.forceRedraw();
                            continue;
                        },
                        else => {},
                    }
                }
                // Route keys to preview panel when active
                if (layout.active_panel == .preview and editor.mode == .normal) {
                    preview.handlePreviewKey(key);
                    continue;
                }
                const old_mode = editor.mode;
                try editor.handleEvent(event);
                // Broadcast plugin events for mode changes
                if (editor.mode != old_mode) {
                    var mode_event = plugin.PluginEvent{ .type = .mode_changed, .editor = &editor };
                    plugin_mgr.broadcast(&mode_event);
                }
            },
            .mouse => |mouse| {
                handleMouse(&editor, &layout, mouse, &preview);
            },
            .resize => {
                try renderer.resize();
                renderer.forceRedraw();
            },
            .none => {},
        }
    }
}

fn handleMouse(editor: *Editor, layout: *Layout, mouse: Input.Mouse, preview_panel: *Preview) void {
    const er = layout.editor_rect;

    switch (mouse.button) {
        .left => {
            // Click in editor area: position cursor
            if (mouse.x >= er.x and mouse.x < er.x + er.w and
                mouse.y >= er.y and mouse.y < er.y + er.h)
            {
                const gutter_w: u16 = 4;
                if (mouse.x >= er.x + gutter_w) {
                    const click_col = @as(usize, mouse.x - er.x - gutter_w) + editor.scroll_col;
                    const click_row = @as(usize, mouse.y - er.y) + editor.scroll_row;
                    if (click_row < editor.buffer.lineCount()) {
                        editor.cursor_row = click_row;
                        const line_len = editor.buffer.getLineLen(click_row);
                        editor.cursor_col = @min(click_col, if (line_len > 0 and editor.mode == .normal) line_len - 1 else line_len);
                        editor.desired_col = editor.cursor_col;
                    }
                }
                layout.active_panel = .editor;
            }
            // Click in file tree
            else if (layout.show_file_tree and mouse.x >= layout.tree_rect.x and mouse.x < layout.tree_rect.x + layout.tree_rect.w and
                mouse.y >= layout.tree_rect.y and mouse.y < layout.tree_rect.y + layout.tree_rect.h)
            {
                layout.active_panel = .file_tree;
            }
            // Click in preview
            else if (layout.show_preview and mouse.x >= layout.preview_rect.x and mouse.x < layout.preview_rect.x + layout.preview_rect.w and
                mouse.y >= layout.preview_rect.y and mouse.y < layout.preview_rect.y + layout.preview_rect.h)
            {
                layout.active_panel = .preview;
                // Delegate to preview for fold toggle on indicator column
                preview_panel.handleClick(mouse.x, mouse.y, layout.preview_rect);
            }
        },
        .scroll_up => {
            for (0..3) |_| {
                if (editor.scroll_row > 0) editor.scroll_row -= 1;
                if (editor.cursor_row > 0) editor.cursor_row -= 1;
            }
        },
        .scroll_down => {
            for (0..3) |_| {
                if (editor.cursor_row + 1 < editor.buffer.lineCount()) {
                    editor.cursor_row += 1;
                }
            }
        },
        else => {},
    }
}

fn scanDirectory(allocator: std.mem.Allocator, path: []const u8, entries: *std.ArrayList(Layout.FileEntry)) !void {
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.name[0] == '.') continue; // skip hidden
        const name = try allocator.dupe(u8, entry.name);
        const is_md = std.mem.endsWith(u8, entry.name, ".md") or
            std.mem.endsWith(u8, entry.name, ".rndm");
        try entries.append(allocator, .{
            .name = name,
            .is_dir = entry.kind == .directory,
            .is_md = is_md,
        });
    }

    // Sort: dirs first, then alphabetical
    std.mem.sort(Layout.FileEntry, entries.items, {}, struct {
        fn lessThan(_: void, a: Layout.FileEntry, b: Layout.FileEntry) bool {
            if (a.is_dir != b.is_dir) return a.is_dir;
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lessThan);
}

// Pull in all tests from submodules
test {
    _ = @import("Terminal.zig");
    _ = @import("Input.zig");
    _ = @import("Buffer.zig");
    _ = @import("Editor.zig");
    _ = @import("Renderer.zig");
    _ = @import("markdown/syntax.zig");
    _ = @import("ui/Layout.zig");
    _ = @import("ui/Preview.zig");
    _ = @import("plugin.zig");
    _ = @import("themes.zig");
    // Plugins (61 total)
    _ = @import("plugins/taskwarrior.zig");
    _ = @import("plugins/word_count.zig");
    _ = @import("plugins/outline.zig");
    _ = @import("plugins/templates.zig");
    _ = @import("plugins/daily_notes.zig");
    _ = @import("plugins/search.zig");
    _ = @import("plugins/bookmarks.zig");
    _ = @import("plugins/command_palette.zig");
    _ = @import("plugins/zen_mode.zig");
    _ = @import("plugins/typewriter.zig");
    _ = @import("plugins/reading_time.zig");
    _ = @import("plugins/backlinks.zig");
    _ = @import("plugins/quick_switcher.zig");
    _ = @import("plugins/recent_files.zig");
    _ = @import("plugins/zettelkasten.zig");
    _ = @import("plugins/note_refactor.zig");
    _ = @import("plugins/folder_notes.zig");
    _ = @import("plugins/tag_manager.zig");
    _ = @import("plugins/file_recovery.zig");
    _ = @import("plugins/periodic_notes.zig");
    _ = @import("plugins/pomodoro.zig");
    _ = @import("plugins/kanban.zig");
    _ = @import("plugins/habit_tracker.zig");
    _ = @import("plugins/day_planner.zig");
    _ = @import("plugins/meeting_notes.zig");
    _ = @import("plugins/journal.zig");
    _ = @import("plugins/checklist.zig");
    _ = @import("plugins/project_manager.zig");
    _ = @import("plugins/calendar.zig");
    _ = @import("plugins/linter.zig");
    _ = @import("plugins/spell_check.zig");
    _ = @import("plugins/auto_complete.zig");
    _ = @import("plugins/snippet_manager.zig");
    _ = @import("plugins/text_expander.zig");
    _ = @import("plugins/table_editor.zig");
    _ = @import("plugins/footnotes.zig");
    _ = @import("plugins/citations.zig");
    _ = @import("plugins/admonitions.zig");
    _ = @import("plugins/emoji.zig");
    _ = @import("plugins/git_sync.zig");
    _ = @import("plugins/export_html.zig");
    _ = @import("plugins/dictionary.zig");
    _ = @import("plugins/thesaurus.zig");
    _ = @import("plugins/web_clipper.zig");
    _ = @import("plugins/todoist.zig");
    _ = @import("plugins/slack.zig");
    _ = @import("plugins/mcp_connector.zig");
    _ = @import("plugins/focus_mode.zig");
    _ = @import("plugins/graph_view.zig");
    _ = @import("plugins/mind_map.zig");
    _ = @import("plugins/flashcards.zig");
    _ = @import("plugins/dataview.zig");
    _ = @import("plugins/frontmatter.zig");
    _ = @import("plugins/mermaid.zig");
    _ = @import("plugins/version_history.zig");
    _ = @import("plugins/random_note.zig");
    _ = @import("plugins/publish.zig");
    _ = @import("plugins/paste_image.zig");
    _ = @import("plugins/auto_link.zig");
    _ = @import("plugins/math.zig");
    _ = @import("plugins/slides.zig");
    _ = @import("plugins/theme_chooser.zig");
    _ = @import("plugins/unlinked_mentions.zig");
    _ = @import("plugins/note_rename.zig");
    _ = @import("plugins/vault_stats.zig");
    _ = @import("plugins/nested_tags.zig");
    _ = @import("mcp/Server.zig");
    _ = @import("nav/Navigator.zig");
    _ = @import("nav/BuiltinNavigator.zig");
}
