const std = @import("std");
const Allocator = std.mem.Allocator;

const Self = @This();

// ── Shared Types ─────────────────────────────────────────────────────

pub const TokenKind = enum {
    keyword,
    type_name,
    builtin,
    string,
    number,
    comment,
    operator,
    punctuation,
    annotation,
    normal,
};

pub const Span = struct {
    start: usize,
    end: usize,
    kind: TokenKind,
};

pub const State = struct {
    in_block_comment: bool = false,
    in_multiline_string: bool = false,
};

// ── VTable ───────────────────────────────────────────────────────────

pub const VTable = struct {
    /// Highlight a single line of source code for the given language.
    highlightLine: *const fn (ctx: *anyopaque, allocator: Allocator, line: []const u8, lang_name: []const u8, state: *State, spans: *std.ArrayList(Span)) anyerror!void,

    /// Check if the given language name is supported by this highlighter.
    supportsLanguage: *const fn (ctx: *anyopaque, lang_name: []const u8) bool,
};

// ── Fields ───────────────────────────────────────────────────────────

ptr: *anyopaque,
vtable: *const VTable,

// ── Dispatch Methods ─────────────────────────────────────────────────

pub fn highlightLine(self: Self, allocator: Allocator, line: []const u8, lang_name: []const u8, state: *State, spans: *std.ArrayList(Span)) !void {
    return self.vtable.highlightLine(self.ptr, allocator, line, lang_name, state, spans);
}

pub fn supportsLanguage(self: Self, lang_name: []const u8) bool {
    return self.vtable.supportsLanguage(self.ptr, lang_name);
}
