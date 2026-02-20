const std = @import("std");
const Allocator = std.mem.Allocator;

const Self = @This();

// ── Result Types ─────────────────────────────────────────────────────

pub const SectionContent = struct {
    heading_line: usize, // 0-indexed
    level: usize,
    title: []const u8,
    content: []const u8, // caller must free
    start_line: usize, // 0-indexed, first content line after heading
    end_line: usize, // 0-indexed, exclusive (next section or EOF)
};

pub const TaskItem = struct {
    line: usize, // 0-indexed
    done: bool,
    text: []const u8,
    breadcrumb: []const u8, // caller must free
};

pub const HeadingInfo = struct {
    line: usize, // 0-indexed
    level: usize,
    title: []const u8,
};

// ── VTable ───────────────────────────────────────────────────────────

pub const VTable = struct {
    /// Read a section by slash-separated heading path (e.g. "Plan/Step 1/Subtask A").
    /// Returns section content including heading + body until next same-or-higher-level heading.
    readSection: *const fn (ctx: *anyopaque, allocator: Allocator, heading_path: []const u8) anyerror!SectionContent,

    /// List all task checkboxes (- [ ] / - [x]). Optionally scoped to a section and filtered by status.
    /// status: 0=all, 1=pending, 2=done
    listTasks: *const fn (ctx: *anyopaque, allocator: Allocator, section: ?[]const u8, status: u8) anyerror![]TaskItem,

    /// Toggle a task checkbox at a given line (0-indexed).
    updateTask: *const fn (ctx: *anyopaque, allocator: Allocator, line: usize, done: bool) anyerror![]const u8,

    /// Get the heading hierarchy breadcrumb for a given line (0-indexed).
    getBreadcrumb: *const fn (ctx: *anyopaque, allocator: Allocator, line: usize) anyerror![]const u8,

    /// Move a section (identified by heading text) after another section (identified by heading text).
    /// If `before` is true, move before the target instead of after.
    moveSection: *const fn (ctx: *anyopaque, allocator: Allocator, heading: []const u8, target: []const u8, before: bool) anyerror![]const u8,

    /// Read lines from a section with line numbers. Supports optional offset/limit within the section.
    readSectionRange: *const fn (ctx: *anyopaque, allocator: Allocator, heading_path: []const u8, start_offset: ?usize, end_offset: ?usize) anyerror![]const u8,
};

// ── Fields ───────────────────────────────────────────────────────────

ptr: *anyopaque,
vtable: *const VTable,

// ── Dispatch Methods ─────────────────────────────────────────────────

pub fn readSection(self: Self, allocator: Allocator, heading_path: []const u8) !SectionContent {
    return self.vtable.readSection(self.ptr, allocator, heading_path);
}

pub fn listTasks(self: Self, allocator: Allocator, section: ?[]const u8, status: u8) ![]TaskItem {
    return self.vtable.listTasks(self.ptr, allocator, section, status);
}

pub fn updateTask(self: Self, allocator: Allocator, line: usize, done: bool) ![]const u8 {
    return self.vtable.updateTask(self.ptr, allocator, line, done);
}

pub fn getBreadcrumb(self: Self, allocator: Allocator, line: usize) ![]const u8 {
    return self.vtable.getBreadcrumb(self.ptr, allocator, line);
}

pub fn moveSection(self: Self, allocator: Allocator, heading: []const u8, target: []const u8, before: bool) ![]const u8 {
    return self.vtable.moveSection(self.ptr, allocator, heading, target, before);
}

pub fn readSectionRange(self: Self, allocator: Allocator, heading_path: []const u8, start_offset: ?usize, end_offset: ?usize) ![]const u8 {
    return self.vtable.readSectionRange(self.ptr, allocator, heading_path, start_offset, end_offset);
}
