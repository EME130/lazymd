const std = @import("std");
const Terminal = @import("Terminal.zig");
const Input = @import("Input.zig");
const Buffer = @import("Buffer.zig");
const Editor = @import("Editor.zig");
const Renderer = @import("Renderer.zig");
const Layout = @import("ui/Layout.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var file_path: ?[]const u8 = null;
    if (args.len > 1) {
        file_path = args[1];
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
        layout.renderPreview(&renderer, &editor);

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
                try editor.handleEvent(event);
            },
            .resize => {
                try renderer.resize();
                renderer.forceRedraw();
            },
            .none => {},
        }
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
}
