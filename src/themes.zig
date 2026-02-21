const std = @import("std");
const Terminal = @import("Terminal.zig");
const Color = Terminal.Color;
const Highlighter = @import("highlight/Highlighter.zig");

// ── Theme System ──────────────────────────────────────────────────────
// Configurable color themes for lazy-md.
// Each theme defines colors for UI chrome, editor, syntax, and preview.

pub const ThemeColors = struct {
    // UI chrome
    title_fg: Color = .bright_white,
    title_bg: Color = .blue,
    status_fg: Color = .bright_white,
    status_bg: Color = .{ .fixed = 236 },
    border: Color = .bright_black,
    border_active: Color = .bright_cyan,
    gutter: Color = .bright_black,
    gutter_active: Color = .bright_white,

    // Syntax colors
    h1: Color = .bright_cyan,
    h2: Color = .bright_green,
    h3: Color = .bright_yellow,
    h4: Color = .bright_blue,
    h5: Color = .bright_magenta,
    h6: Color = .cyan,
    bold: Color = .bright_white,
    italic: Color = .white,
    code: Color = .yellow,
    code_bg: Color = .{ .fixed = 236 },
    code_block_bg: Color = .{ .fixed = 235 },
    link: Color = .bright_blue,
    link_url: Color = .blue,
    list_marker: Color = .bright_magenta,
    blockquote: Color = .bright_black,
    hr: Color = .bright_black,
    strikethrough: Color = .bright_black,
    checkbox: Color = .bright_yellow,
    checkbox_done: Color = .bright_green,

    // Code highlighting colors
    syn_keyword: Color = .bright_magenta,
    syn_type: Color = .bright_cyan,
    syn_string: Color = .bright_green,
    syn_number: Color = .bright_yellow,
    syn_comment: Color = .bright_black,
    syn_builtin: Color = .bright_blue,
    syn_operator: Color = .bright_white,
    syn_punctuation: Color = .white,
    syn_annotation: Color = .bright_yellow,
    syn_normal: Color = .white,

    // Mode colors
    mode_normal_bg: Color = .blue,
    mode_insert_bg: Color = .green,
    mode_command_bg: Color = .magenta,

    // General
    text: Color = .default,
    text_muted: Color = .bright_black,
    err_color: Color = .bright_red,
    success: Color = .bright_green,

    pub fn syntaxColor(tc: *const ThemeColors, kind: Highlighter.TokenKind) Color {
        return switch (kind) {
            .keyword => tc.syn_keyword,
            .type_name => tc.syn_type,
            .string => tc.syn_string,
            .number => tc.syn_number,
            .comment => tc.syn_comment,
            .builtin => tc.syn_builtin,
            .operator => tc.syn_operator,
            .punctuation => tc.syn_punctuation,
            .annotation => tc.syn_annotation,
            .normal => tc.syn_normal,
        };
    }
};

pub const ThemeDef = struct {
    name: []const u8,
    description: []const u8,
    colors: ThemeColors,
};

// ── Built-in Themes ───────────────────────────────────────────────────

pub const builtin_themes = [_]ThemeDef{
    // 0: Default
    .{
        .name = "default",
        .description = "Default lazy-md theme",
        .colors = .{},
    },
    // 1: Dracula
    .{
        .name = "dracula",
        .description = "Dracula dark theme",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 68, .g = 71, .b = 90 } },
            .h1 = .{ .rgb = .{ .r = 139, .g = 233, .b = 253 } },
            .h2 = .{ .rgb = .{ .r = 80, .g = 250, .b = 123 } },
            .h3 = .{ .rgb = .{ .r = 241, .g = 250, .b = 140 } },
            .h4 = .{ .rgb = .{ .r = 189, .g = 147, .b = 249 } },
            .h5 = .{ .rgb = .{ .r = 255, .g = 121, .b = 198 } },
            .h6 = .{ .rgb = .{ .r = 255, .g = 184, .b = 108 } },
            .bold = .{ .rgb = .{ .r = 248, .g = 248, .b = 242 } },
            .italic = .{ .rgb = .{ .r = 248, .g = 248, .b = 242 } },
            .code = .{ .rgb = .{ .r = 80, .g = 250, .b = 123 } },
            .link = .{ .rgb = .{ .r = 139, .g = 233, .b = 253 } },
            .list_marker = .{ .rgb = .{ .r = 255, .g = 121, .b = 198 } },
            .syn_keyword = .{ .rgb = .{ .r = 255, .g = 121, .b = 198 } }, // pink
            .syn_type = .{ .rgb = .{ .r = 139, .g = 233, .b = 253 } }, // cyan
            .syn_string = .{ .rgb = .{ .r = 241, .g = 250, .b = 140 } }, // yellow
            .syn_number = .{ .rgb = .{ .r = 189, .g = 147, .b = 249 } }, // purple
            .syn_comment = .{ .rgb = .{ .r = 98, .g = 114, .b = 164 } }, // comment gray
            .syn_builtin = .{ .rgb = .{ .r = 80, .g = 250, .b = 123 } }, // green
            .syn_operator = .{ .rgb = .{ .r = 255, .g = 121, .b = 198 } }, // pink
            .syn_punctuation = .{ .rgb = .{ .r = 248, .g = 248, .b = 242 } }, // fg
            .syn_annotation = .{ .rgb = .{ .r = 80, .g = 250, .b = 123 } }, // green
            .syn_normal = .{ .rgb = .{ .r = 248, .g = 248, .b = 242 } }, // fg
            .mode_normal_bg = .{ .rgb = .{ .r = 189, .g = 147, .b = 249 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 80, .g = 250, .b = 123 } },
            .mode_command_bg = .{ .rgb = .{ .r = 255, .g = 121, .b = 198 } },
        },
    },
    // 2: Gruvbox
    .{
        .name = "gruvbox",
        .description = "Gruvbox retro groove",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 60, .g = 56, .b = 54 } },
            .h1 = .{ .rgb = .{ .r = 131, .g = 165, .b = 152 } },
            .h2 = .{ .rgb = .{ .r = 184, .g = 187, .b = 38 } },
            .h3 = .{ .rgb = .{ .r = 250, .g = 189, .b = 47 } },
            .h4 = .{ .rgb = .{ .r = 131, .g = 165, .b = 152 } },
            .h5 = .{ .rgb = .{ .r = 211, .g = 134, .b = 155 } },
            .h6 = .{ .rgb = .{ .r = 254, .g = 128, .b = 25 } },
            .bold = .{ .rgb = .{ .r = 235, .g = 219, .b = 178 } },
            .code = .{ .rgb = .{ .r = 184, .g = 187, .b = 38 } },
            .link = .{ .rgb = .{ .r = 131, .g = 165, .b = 152 } },
            .list_marker = .{ .rgb = .{ .r = 254, .g = 128, .b = 25 } },
            .syn_keyword = .{ .rgb = .{ .r = 251, .g = 73, .b = 52 } }, // red
            .syn_type = .{ .rgb = .{ .r = 250, .g = 189, .b = 47 } }, // yellow
            .syn_string = .{ .rgb = .{ .r = 184, .g = 187, .b = 38 } }, // green
            .syn_number = .{ .rgb = .{ .r = 211, .g = 134, .b = 155 } }, // purple
            .syn_comment = .{ .rgb = .{ .r = 146, .g = 131, .b = 116 } }, // gray
            .syn_builtin = .{ .rgb = .{ .r = 254, .g = 128, .b = 25 } }, // orange
            .syn_operator = .{ .rgb = .{ .r = 235, .g = 219, .b = 178 } }, // fg
            .syn_punctuation = .{ .rgb = .{ .r = 189, .g = 174, .b = 147 } }, // fg2
            .syn_annotation = .{ .rgb = .{ .r = 131, .g = 165, .b = 152 } }, // aqua
            .syn_normal = .{ .rgb = .{ .r = 235, .g = 219, .b = 178 } }, // fg
            .mode_normal_bg = .{ .rgb = .{ .r = 69, .g = 133, .b = 136 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 152, .g = 151, .b = 26 } },
            .mode_command_bg = .{ .rgb = .{ .r = 177, .g = 98, .b = 134 } },
        },
    },
    // 3: Nord
    .{
        .name = "nord",
        .description = "Arctic, north-bluish clean",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 59, .g = 66, .b = 82 } },
            .h1 = .{ .rgb = .{ .r = 136, .g = 192, .b = 208 } },
            .h2 = .{ .rgb = .{ .r = 163, .g = 190, .b = 140 } },
            .h3 = .{ .rgb = .{ .r = 235, .g = 203, .b = 139 } },
            .h4 = .{ .rgb = .{ .r = 129, .g = 161, .b = 193 } },
            .h5 = .{ .rgb = .{ .r = 180, .g = 142, .b = 173 } },
            .h6 = .{ .rgb = .{ .r = 208, .g = 135, .b = 112 } },
            .bold = .{ .rgb = .{ .r = 236, .g = 239, .b = 244 } },
            .code = .{ .rgb = .{ .r = 163, .g = 190, .b = 140 } },
            .link = .{ .rgb = .{ .r = 136, .g = 192, .b = 208 } },
            .list_marker = .{ .rgb = .{ .r = 208, .g = 135, .b = 112 } },
            .syn_keyword = .{ .rgb = .{ .r = 129, .g = 161, .b = 193 } }, // nord9
            .syn_type = .{ .rgb = .{ .r = 136, .g = 192, .b = 208 } }, // nord8
            .syn_string = .{ .rgb = .{ .r = 163, .g = 190, .b = 140 } }, // nord14
            .syn_number = .{ .rgb = .{ .r = 180, .g = 142, .b = 173 } }, // nord15
            .syn_comment = .{ .rgb = .{ .r = 76, .g = 86, .b = 106 } }, // nord3
            .syn_builtin = .{ .rgb = .{ .r = 235, .g = 203, .b = 139 } }, // nord13
            .syn_operator = .{ .rgb = .{ .r = 236, .g = 239, .b = 244 } }, // nord6
            .syn_punctuation = .{ .rgb = .{ .r = 216, .g = 222, .b = 233 } }, // nord5
            .syn_annotation = .{ .rgb = .{ .r = 208, .g = 135, .b = 112 } }, // nord12
            .syn_normal = .{ .rgb = .{ .r = 216, .g = 222, .b = 233 } }, // nord5
            .mode_normal_bg = .{ .rgb = .{ .r = 94, .g = 129, .b = 172 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 163, .g = 190, .b = 140 } },
            .mode_command_bg = .{ .rgb = .{ .r = 180, .g = 142, .b = 173 } },
        },
    },
    // 4: Solarized Dark
    .{
        .name = "solarized",
        .description = "Solarized dark precision colors",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 0, .g = 43, .b = 54 } },
            .h1 = .{ .rgb = .{ .r = 38, .g = 139, .b = 210 } },
            .h2 = .{ .rgb = .{ .r = 133, .g = 153, .b = 0 } },
            .h3 = .{ .rgb = .{ .r = 181, .g = 137, .b = 0 } },
            .h4 = .{ .rgb = .{ .r = 42, .g = 161, .b = 152 } },
            .h5 = .{ .rgb = .{ .r = 211, .g = 54, .b = 130 } },
            .h6 = .{ .rgb = .{ .r = 203, .g = 75, .b = 22 } },
            .bold = .{ .rgb = .{ .r = 238, .g = 232, .b = 213 } },
            .code = .{ .rgb = .{ .r = 133, .g = 153, .b = 0 } },
            .link = .{ .rgb = .{ .r = 38, .g = 139, .b = 210 } },
            .list_marker = .{ .rgb = .{ .r = 108, .g = 113, .b = 196 } },
            .syn_keyword = .{ .rgb = .{ .r = 133, .g = 153, .b = 0 } }, // green
            .syn_type = .{ .rgb = .{ .r = 181, .g = 137, .b = 0 } }, // yellow
            .syn_string = .{ .rgb = .{ .r = 42, .g = 161, .b = 152 } }, // cyan
            .syn_number = .{ .rgb = .{ .r = 211, .g = 54, .b = 130 } }, // magenta
            .syn_comment = .{ .rgb = .{ .r = 88, .g = 110, .b = 117 } }, // base01
            .syn_builtin = .{ .rgb = .{ .r = 38, .g = 139, .b = 210 } }, // blue
            .syn_operator = .{ .rgb = .{ .r = 131, .g = 148, .b = 150 } }, // base0
            .syn_punctuation = .{ .rgb = .{ .r = 131, .g = 148, .b = 150 } }, // base0
            .syn_annotation = .{ .rgb = .{ .r = 203, .g = 75, .b = 22 } }, // orange
            .syn_normal = .{ .rgb = .{ .r = 131, .g = 148, .b = 150 } }, // base0
            .mode_normal_bg = .{ .rgb = .{ .r = 38, .g = 139, .b = 210 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 133, .g = 153, .b = 0 } },
            .mode_command_bg = .{ .rgb = .{ .r = 211, .g = 54, .b = 130 } },
        },
    },
    // 5: Monokai
    .{
        .name = "monokai",
        .description = "Monokai classic dark",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 39, .g = 40, .b = 34 } },
            .h1 = .{ .rgb = .{ .r = 102, .g = 217, .b = 239 } },
            .h2 = .{ .rgb = .{ .r = 166, .g = 226, .b = 46 } },
            .h3 = .{ .rgb = .{ .r = 230, .g = 219, .b = 116 } },
            .h4 = .{ .rgb = .{ .r = 102, .g = 217, .b = 239 } },
            .h5 = .{ .rgb = .{ .r = 249, .g = 38, .b = 114 } },
            .h6 = .{ .rgb = .{ .r = 253, .g = 151, .b = 31 } },
            .bold = .{ .rgb = .{ .r = 248, .g = 248, .b = 242 } },
            .code = .{ .rgb = .{ .r = 166, .g = 226, .b = 46 } },
            .link = .{ .rgb = .{ .r = 102, .g = 217, .b = 239 } },
            .list_marker = .{ .rgb = .{ .r = 249, .g = 38, .b = 114 } },
            .syn_keyword = .{ .rgb = .{ .r = 249, .g = 38, .b = 114 } }, // red
            .syn_type = .{ .rgb = .{ .r = 102, .g = 217, .b = 239 } }, // blue
            .syn_string = .{ .rgb = .{ .r = 230, .g = 219, .b = 116 } }, // yellow
            .syn_number = .{ .rgb = .{ .r = 174, .g = 129, .b = 255 } }, // purple
            .syn_comment = .{ .rgb = .{ .r = 117, .g = 113, .b = 94 } }, // gray
            .syn_builtin = .{ .rgb = .{ .r = 166, .g = 226, .b = 46 } }, // green
            .syn_operator = .{ .rgb = .{ .r = 249, .g = 38, .b = 114 } }, // red
            .syn_punctuation = .{ .rgb = .{ .r = 248, .g = 248, .b = 242 } }, // fg
            .syn_annotation = .{ .rgb = .{ .r = 166, .g = 226, .b = 46 } }, // green
            .syn_normal = .{ .rgb = .{ .r = 248, .g = 248, .b = 242 } }, // fg
            .mode_normal_bg = .{ .rgb = .{ .r = 102, .g = 217, .b = 239 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 166, .g = 226, .b = 46 } },
            .mode_command_bg = .{ .rgb = .{ .r = 249, .g = 38, .b = 114 } },
        },
    },
    // 6: Catppuccin Mocha
    .{
        .name = "catppuccin",
        .description = "Catppuccin mocha soothing pastels",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 30, .g = 30, .b = 46 } },
            .h1 = .{ .rgb = .{ .r = 137, .g = 180, .b = 250 } },
            .h2 = .{ .rgb = .{ .r = 166, .g = 227, .b = 161 } },
            .h3 = .{ .rgb = .{ .r = 249, .g = 226, .b = 175 } },
            .h4 = .{ .rgb = .{ .r = 116, .g = 199, .b = 236 } },
            .h5 = .{ .rgb = .{ .r = 245, .g = 194, .b = 231 } },
            .h6 = .{ .rgb = .{ .r = 250, .g = 179, .b = 135 } },
            .bold = .{ .rgb = .{ .r = 205, .g = 214, .b = 244 } },
            .code = .{ .rgb = .{ .r = 166, .g = 227, .b = 161 } },
            .link = .{ .rgb = .{ .r = 137, .g = 180, .b = 250 } },
            .list_marker = .{ .rgb = .{ .r = 245, .g = 194, .b = 231 } },
            .syn_keyword = .{ .rgb = .{ .r = 203, .g = 166, .b = 247 } }, // mauve
            .syn_type = .{ .rgb = .{ .r = 249, .g = 226, .b = 175 } }, // yellow
            .syn_string = .{ .rgb = .{ .r = 166, .g = 227, .b = 161 } }, // green
            .syn_number = .{ .rgb = .{ .r = 250, .g = 179, .b = 135 } }, // peach
            .syn_comment = .{ .rgb = .{ .r = 108, .g = 112, .b = 134 } }, // overlay0
            .syn_builtin = .{ .rgb = .{ .r = 137, .g = 180, .b = 250 } }, // blue
            .syn_operator = .{ .rgb = .{ .r = 116, .g = 199, .b = 236 } }, // sapphire
            .syn_punctuation = .{ .rgb = .{ .r = 186, .g = 194, .b = 222 } }, // subtext0
            .syn_annotation = .{ .rgb = .{ .r = 245, .g = 194, .b = 231 } }, // pink
            .syn_normal = .{ .rgb = .{ .r = 205, .g = 214, .b = 244 } }, // text
            .mode_normal_bg = .{ .rgb = .{ .r = 137, .g = 180, .b = 250 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 166, .g = 227, .b = 161 } },
            .mode_command_bg = .{ .rgb = .{ .r = 203, .g = 166, .b = 247 } },
        },
    },
    // 7: Tokyo Night
    .{
        .name = "tokyo-night",
        .description = "Tokyo Night vibrant dark",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 26, .g = 27, .b = 38 } },
            .h1 = .{ .rgb = .{ .r = 125, .g = 207, .b = 255 } },
            .h2 = .{ .rgb = .{ .r = 158, .g = 206, .b = 106 } },
            .h3 = .{ .rgb = .{ .r = 224, .g = 175, .b = 104 } },
            .h4 = .{ .rgb = .{ .r = 122, .g = 162, .b = 247 } },
            .h5 = .{ .rgb = .{ .r = 187, .g = 154, .b = 247 } },
            .h6 = .{ .rgb = .{ .r = 255, .g = 158, .b = 100 } },
            .bold = .{ .rgb = .{ .r = 192, .g = 202, .b = 245 } },
            .code = .{ .rgb = .{ .r = 158, .g = 206, .b = 106 } },
            .link = .{ .rgb = .{ .r = 125, .g = 207, .b = 255 } },
            .list_marker = .{ .rgb = .{ .r = 255, .g = 158, .b = 100 } },
            .syn_keyword = .{ .rgb = .{ .r = 187, .g = 154, .b = 247 } }, // purple
            .syn_type = .{ .rgb = .{ .r = 125, .g = 207, .b = 255 } }, // blue
            .syn_string = .{ .rgb = .{ .r = 158, .g = 206, .b = 106 } }, // green
            .syn_number = .{ .rgb = .{ .r = 255, .g = 158, .b = 100 } }, // orange
            .syn_comment = .{ .rgb = .{ .r = 86, .g = 95, .b = 137 } }, // comment
            .syn_builtin = .{ .rgb = .{ .r = 122, .g = 162, .b = 247 } }, // blue2
            .syn_operator = .{ .rgb = .{ .r = 137, .g = 221, .b = 255 } }, // cyan
            .syn_punctuation = .{ .rgb = .{ .r = 169, .g = 177, .b = 214 } }, // fg_dark
            .syn_annotation = .{ .rgb = .{ .r = 224, .g = 175, .b = 104 } }, // yellow
            .syn_normal = .{ .rgb = .{ .r = 192, .g = 202, .b = 245 } }, // fg
            .mode_normal_bg = .{ .rgb = .{ .r = 122, .g = 162, .b = 247 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 158, .g = 206, .b = 106 } },
            .mode_command_bg = .{ .rgb = .{ .r = 187, .g = 154, .b = 247 } },
        },
    },
    // 8: One Dark
    .{
        .name = "one-dark",
        .description = "Atom One Dark",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 40, .g = 44, .b = 52 } },
            .h1 = .{ .rgb = .{ .r = 97, .g = 175, .b = 239 } },
            .h2 = .{ .rgb = .{ .r = 152, .g = 195, .b = 121 } },
            .h3 = .{ .rgb = .{ .r = 229, .g = 192, .b = 123 } },
            .h4 = .{ .rgb = .{ .r = 97, .g = 175, .b = 239 } },
            .h5 = .{ .rgb = .{ .r = 198, .g = 120, .b = 221 } },
            .h6 = .{ .rgb = .{ .r = 209, .g = 154, .b = 102 } },
            .bold = .{ .rgb = .{ .r = 171, .g = 178, .b = 191 } },
            .code = .{ .rgb = .{ .r = 152, .g = 195, .b = 121 } },
            .link = .{ .rgb = .{ .r = 97, .g = 175, .b = 239 } },
            .list_marker = .{ .rgb = .{ .r = 198, .g = 120, .b = 221 } },
            .syn_keyword = .{ .rgb = .{ .r = 198, .g = 120, .b = 221 } }, // purple
            .syn_type = .{ .rgb = .{ .r = 229, .g = 192, .b = 123 } }, // yellow
            .syn_string = .{ .rgb = .{ .r = 152, .g = 195, .b = 121 } }, // green
            .syn_number = .{ .rgb = .{ .r = 209, .g = 154, .b = 102 } }, // orange
            .syn_comment = .{ .rgb = .{ .r = 92, .g = 99, .b = 112 } }, // comment
            .syn_builtin = .{ .rgb = .{ .r = 97, .g = 175, .b = 239 } }, // blue
            .syn_operator = .{ .rgb = .{ .r = 86, .g = 182, .b = 194 } }, // cyan
            .syn_punctuation = .{ .rgb = .{ .r = 171, .g = 178, .b = 191 } }, // fg
            .syn_annotation = .{ .rgb = .{ .r = 229, .g = 192, .b = 123 } }, // yellow
            .syn_normal = .{ .rgb = .{ .r = 171, .g = 178, .b = 191 } }, // fg
            .mode_normal_bg = .{ .rgb = .{ .r = 97, .g = 175, .b = 239 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 152, .g = 195, .b = 121 } },
            .mode_command_bg = .{ .rgb = .{ .r = 198, .g = 120, .b = 221 } },
        },
    },
    // 9: Rose Pine
    .{
        .name = "rose-pine",
        .description = "Rose Pine all natural",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 25, .g = 23, .b = 36 } },
            .h1 = .{ .rgb = .{ .r = 156, .g = 207, .b = 216 } },
            .h2 = .{ .rgb = .{ .r = 49, .g = 116, .b = 143 } },
            .h3 = .{ .rgb = .{ .r = 246, .g = 193, .b = 119 } },
            .h4 = .{ .rgb = .{ .r = 156, .g = 207, .b = 216 } },
            .h5 = .{ .rgb = .{ .r = 196, .g = 167, .b = 231 } },
            .h6 = .{ .rgb = .{ .r = 235, .g = 188, .b = 186 } },
            .bold = .{ .rgb = .{ .r = 224, .g = 222, .b = 244 } },
            .code = .{ .rgb = .{ .r = 246, .g = 193, .b = 119 } },
            .link = .{ .rgb = .{ .r = 156, .g = 207, .b = 216 } },
            .list_marker = .{ .rgb = .{ .r = 235, .g = 111, .b = 146 } },
            .syn_keyword = .{ .rgb = .{ .r = 49, .g = 116, .b = 143 } }, // pine
            .syn_type = .{ .rgb = .{ .r = 246, .g = 193, .b = 119 } }, // gold
            .syn_string = .{ .rgb = .{ .r = 156, .g = 207, .b = 216 } }, // foam
            .syn_number = .{ .rgb = .{ .r = 196, .g = 167, .b = 231 } }, // iris
            .syn_comment = .{ .rgb = .{ .r = 110, .g = 106, .b = 134 } }, // muted
            .syn_builtin = .{ .rgb = .{ .r = 235, .g = 111, .b = 146 } }, // love
            .syn_operator = .{ .rgb = .{ .r = 224, .g = 222, .b = 244 } }, // text
            .syn_punctuation = .{ .rgb = .{ .r = 144, .g = 140, .b = 170 } }, // subtle
            .syn_annotation = .{ .rgb = .{ .r = 246, .g = 193, .b = 119 } }, // gold
            .syn_normal = .{ .rgb = .{ .r = 224, .g = 222, .b = 244 } }, // text
            .mode_normal_bg = .{ .rgb = .{ .r = 156, .g = 207, .b = 216 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 49, .g = 116, .b = 143 } },
            .mode_command_bg = .{ .rgb = .{ .r = 196, .g = 167, .b = 231 } },
        },
    },
    // 10: Kanagawa
    .{
        .name = "kanagawa",
        .description = "Kanagawa wave inspired by Hokusai",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 22, .g = 22, .b = 29 } },
            .h1 = .{ .rgb = .{ .r = 127, .g = 180, .b = 202 } },
            .h2 = .{ .rgb = .{ .r = 152, .g = 187, .b = 108 } },
            .h3 = .{ .rgb = .{ .r = 226, .g = 164, .b = 120 } },
            .h4 = .{ .rgb = .{ .r = 127, .g = 180, .b = 202 } },
            .h5 = .{ .rgb = .{ .r = 149, .g = 127, .b = 184 } },
            .h6 = .{ .rgb = .{ .r = 255, .g = 94, .b = 99 } },
            .bold = .{ .rgb = .{ .r = 220, .g = 215, .b = 186 } },
            .code = .{ .rgb = .{ .r = 152, .g = 187, .b = 108 } },
            .link = .{ .rgb = .{ .r = 127, .g = 180, .b = 202 } },
            .list_marker = .{ .rgb = .{ .r = 228, .g = 104, .b = 118 } },
            .syn_keyword = .{ .rgb = .{ .r = 149, .g = 127, .b = 184 } }, // oniViolet
            .syn_type = .{ .rgb = .{ .r = 127, .g = 180, .b = 202 } }, // waveBlue2
            .syn_string = .{ .rgb = .{ .r = 152, .g = 187, .b = 108 } }, // springGreen
            .syn_number = .{ .rgb = .{ .r = 255, .g = 94, .b = 99 } }, // peachRed
            .syn_comment = .{ .rgb = .{ .r = 114, .g = 113, .b = 105 } }, // fujiGray
            .syn_builtin = .{ .rgb = .{ .r = 226, .g = 164, .b = 120 } }, // surimiOrange
            .syn_operator = .{ .rgb = .{ .r = 220, .g = 215, .b = 186 } }, // fujiWhite
            .syn_punctuation = .{ .rgb = .{ .r = 155, .g = 152, .b = 133 } }, // oldWhite
            .syn_annotation = .{ .rgb = .{ .r = 228, .g = 104, .b = 118 } }, // waveRed
            .syn_normal = .{ .rgb = .{ .r = 220, .g = 215, .b = 186 } }, // fujiWhite
            .mode_normal_bg = .{ .rgb = .{ .r = 127, .g = 180, .b = 202 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 152, .g = 187, .b = 108 } },
            .mode_command_bg = .{ .rgb = .{ .r = 149, .g = 127, .b = 184 } },
        },
    },
    // 11: Everforest
    .{
        .name = "everforest",
        .description = "Everforest comfortable green",
        .colors = .{
            .title_bg = .{ .rgb = .{ .r = 39, .g = 50, .b = 43 } },
            .h1 = .{ .rgb = .{ .r = 131, .g = 192, .b = 146 } },
            .h2 = .{ .rgb = .{ .r = 167, .g = 192, .b = 128 } },
            .h3 = .{ .rgb = .{ .r = 219, .g = 188, .b = 127 } },
            .h4 = .{ .rgb = .{ .r = 127, .g = 187, .b = 179 } },
            .h5 = .{ .rgb = .{ .r = 214, .g = 153, .b = 182 } },
            .h6 = .{ .rgb = .{ .r = 230, .g = 126, .b = 128 } },
            .bold = .{ .rgb = .{ .r = 211, .g = 198, .b = 170 } },
            .code = .{ .rgb = .{ .r = 167, .g = 192, .b = 128 } },
            .link = .{ .rgb = .{ .r = 131, .g = 192, .b = 146 } },
            .list_marker = .{ .rgb = .{ .r = 230, .g = 126, .b = 128 } },
            .syn_keyword = .{ .rgb = .{ .r = 230, .g = 126, .b = 128 } }, // red
            .syn_type = .{ .rgb = .{ .r = 219, .g = 188, .b = 127 } }, // yellow
            .syn_string = .{ .rgb = .{ .r = 167, .g = 192, .b = 128 } }, // green
            .syn_number = .{ .rgb = .{ .r = 214, .g = 153, .b = 182 } }, // purple
            .syn_comment = .{ .rgb = .{ .r = 133, .g = 146, .b = 137 } }, // gray
            .syn_builtin = .{ .rgb = .{ .r = 131, .g = 192, .b = 146 } }, // aqua
            .syn_operator = .{ .rgb = .{ .r = 211, .g = 198, .b = 170 } }, // fg
            .syn_punctuation = .{ .rgb = .{ .r = 157, .g = 169, .b = 160 } }, // gray1
            .syn_annotation = .{ .rgb = .{ .r = 127, .g = 187, .b = 179 } }, // blue
            .syn_normal = .{ .rgb = .{ .r = 211, .g = 198, .b = 170 } }, // fg
            .mode_normal_bg = .{ .rgb = .{ .r = 131, .g = 192, .b = 146 } },
            .mode_insert_bg = .{ .rgb = .{ .r = 167, .g = 192, .b = 128 } },
            .mode_command_bg = .{ .rgb = .{ .r = 214, .g = 153, .b = 182 } },
        },
    },
};

pub const theme_count: usize = builtin_themes.len;

// ── Current Theme State ───────────────────────────────────────────────

pub var current_theme_index: usize = 0;

pub fn currentTheme() *const ThemeDef {
    return &builtin_themes[current_theme_index];
}

pub fn currentColors() *const ThemeColors {
    return &builtin_themes[current_theme_index].colors;
}

pub fn setTheme(index: usize) void {
    if (index < theme_count) {
        current_theme_index = index;
    }
}

pub fn findThemeByName(name: []const u8) ?usize {
    for (builtin_themes, 0..) |theme, i| {
        if (std.mem.eql(u8, theme.name, name)) return i;
    }
    return null;
}

pub fn cycleTheme() void {
    current_theme_index = (current_theme_index + 1) % theme_count;
}

// ── Tests ─────────────────────────────────────────────────────────────

test "theme lookup" {
    try std.testing.expect(findThemeByName("dracula") != null);
    try std.testing.expect(findThemeByName("nonexistent") == null);
    try std.testing.expectEqual(@as(usize, 0), findThemeByName("default").?);
}

test "theme cycle" {
    current_theme_index = 0;
    cycleTheme();
    try std.testing.expectEqual(@as(usize, 1), current_theme_index);
    current_theme_index = theme_count - 1;
    cycleTheme();
    try std.testing.expectEqual(@as(usize, 0), current_theme_index);
    current_theme_index = 0; // reset
}

test "theme count" {
    try std.testing.expect(theme_count >= 12);
}

test "syntaxColor returns correct colors" {
    const tc = &builtin_themes[0].colors; // default
    try std.testing.expect(tc.syntaxColor(.keyword) == .bright_magenta);
    try std.testing.expect(tc.syntaxColor(.string) == .bright_green);
    try std.testing.expect(tc.syntaxColor(.comment) == .bright_black);
}
