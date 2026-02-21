const std = @import("std");

pub const LangDef = struct {
    name: []const u8,
    aliases: []const []const u8,
    keywords: []const []const u8,
    types: []const []const u8,
    builtins: []const []const u8,
    line_comment: ?[]const u8,
    block_comment_start: ?[]const u8,
    block_comment_end: ?[]const u8,
    string_delimiters: []const u8, // single-char delimiters like '"', '\''
    annotation_prefix: ?u8,
    supports_triple_quote: bool,
};

pub fn findLang(name: []const u8) ?*const LangDef {
    for (&all_languages) |*lang| {
        if (std.ascii.eqlIgnoreCase(lang.name, name)) return lang;
        for (lang.aliases) |alias| {
            if (std.ascii.eqlIgnoreCase(alias, name)) return lang;
        }
    }
    return null;
}

// ── Language Definitions ──────────────────────────────────────────────

const all_languages = [_]LangDef{
    // Zig
    .{
        .name = "zig",
        .aliases = &.{},
        .keywords = &.{
            "const",       "var",       "fn",          "return", "if",
            "else",        "while",     "for",         "switch", "break",
            "continue",    "defer",     "errdefer",    "try",    "catch",
            "pub",         "test",      "struct",      "enum",   "union",
            "error",       "orelse",    "and",         "or",     "comptime",
            "inline",      "nosuspend", "threadlocal", "export", "extern",
            "unreachable", "undefined", "null",        "true",   "false",
            "async",       "await",     "suspend",     "resume", "volatile",
            "align",       "allowzero", "noalias",     "asm",    "usingnamespace",
        },
        .types = &.{
            "u8",     "u16",     "u32",      "u64",       "u128",     "usize",
            "i8",     "i16",     "i32",      "i64",       "i128",     "isize",
            "f16",    "f32",     "f64",      "f128",      "bool",     "void",
            "type",   "anytype", "anyerror", "anyopaque", "anyframe", "c_int",
            "c_uint", "c_long",  "c_ulong",  "c_char",
        },
        .builtins = &.{
            "@import",  "@as",        "@intCast",     "@floatCast",
            "@ptrCast", "@alignCast", "@enumFromInt", "@intFromEnum",
            "@bitCast", "@truncate",  "@embedFile",   "@src",
            "@This",    "@typeInfo",  "@TypeOf",      "@sizeOf",
            "@min",     "@max",       "@memcpy",      "@memset",
        },
        .line_comment = "//",
        .block_comment_start = null,
        .block_comment_end = null,
        .string_delimiters = "\"",
        .annotation_prefix = '@',
        .supports_triple_quote = false,
    },
    // Python
    .{
        .name = "python",
        .aliases = &.{ "py", "python3" },
        .keywords = &.{
            "def",  "class", "return", "if",       "elif",    "else",
            "for",  "while", "break",  "continue", "pass",    "import",
            "from", "as",    "try",    "except",   "finally", "raise",
            "with", "yield", "lambda", "and",      "or",      "not",
            "in",   "is",    "global", "nonlocal", "assert",  "del",
            "True", "False", "None",   "async",    "await",
        },
        .types = &.{
            "int",   "float", "str",   "bool", "list",   "dict",
            "tuple", "set",   "bytes", "type", "object",
        },
        .builtins = &.{
            "print",    "len",         "range",        "enumerate",
            "zip",      "map",         "filter",       "isinstance",
            "hasattr",  "getattr",     "setattr",      "super",
            "property", "classmethod", "staticmethod", "input",
            "open",     "sorted",      "reversed",     "any",
            "all",      "abs",         "min",          "max",
        },
        .line_comment = "#",
        .block_comment_start = null,
        .block_comment_end = null,
        .string_delimiters = "\"'",
        .annotation_prefix = '@',
        .supports_triple_quote = true,
    },
    // JavaScript
    .{
        .name = "javascript",
        .aliases = &.{ "js", "jsx" },
        .keywords = &.{
            "const",  "let",     "var",     "function", "return",
            "if",     "else",    "for",     "while",    "do",
            "switch", "case",    "break",   "continue", "default",
            "try",    "catch",   "finally", "throw",    "new",
            "class",  "extends", "import",  "export",   "from",
            "async",  "await",   "yield",   "typeof",   "instanceof",
            "in",     "of",      "delete",  "void",     "this",
            "super",  "true",    "false",   "null",     "undefined",
        },
        .types = &.{
            "Array",   "Object", "String", "Number", "Boolean",
            "Promise", "Map",    "Set",    "Symbol", "BigInt",
        },
        .builtins = &.{
            "console",    "Math",    "JSON",       "parseInt",
            "parseFloat", "isNaN",   "setTimeout", "setInterval",
            "fetch",      "require", "module",     "process",
        },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"'`",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // TypeScript
    .{
        .name = "typescript",
        .aliases = &.{ "ts", "tsx" },
        .keywords = &.{
            "const",      "let",      "var",        "function", "return",
            "if",         "else",     "for",        "while",    "do",
            "switch",     "case",     "break",      "continue", "default",
            "try",        "catch",    "finally",    "throw",    "new",
            "class",      "extends",  "implements", "import",   "export",
            "from",       "async",    "await",      "yield",    "typeof",
            "instanceof", "in",       "of",         "delete",   "void",
            "this",       "super",    "true",       "false",    "null",
            "undefined",  "type",     "interface",  "enum",     "namespace",
            "declare",    "abstract", "readonly",   "as",       "is",
            "keyof",      "infer",    "satisfies",
        },
        .types = &.{
            "string", "number",  "boolean",  "any",      "unknown",
            "never",  "void",    "object",   "Array",    "Promise",
            "Record", "Partial", "Required", "Readonly", "Pick",
            "Omit",   "Exclude", "Extract",  "Map",      "Set",
        },
        .builtins = &.{
            "console",    "Math",    "JSON",       "parseInt",
            "parseFloat", "isNaN",   "setTimeout", "setInterval",
            "fetch",      "require", "module",     "process",
        },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"'`",
        .annotation_prefix = '@',
        .supports_triple_quote = false,
    },
    // Rust
    .{
        .name = "rust",
        .aliases = &.{"rs"},
        .keywords = &.{
            "fn",    "let",   "mut",      "const",  "static",
            "if",    "else",  "match",    "for",    "while",
            "loop",  "break", "continue", "return", "struct",
            "enum",  "impl",  "trait",    "type",   "where",
            "pub",   "use",   "mod",      "crate",  "self",
            "super", "as",    "in",       "ref",    "move",
            "async", "await", "dyn",      "unsafe", "extern",
            "true",  "false",
        },
        .types = &.{
            "i8",      "i16", "i32",    "i64",    "i128", "isize",
            "u8",      "u16", "u32",    "u64",    "u128", "usize",
            "f32",     "f64", "bool",   "char",   "str",  "String",
            "Vec",     "Box", "Option", "Result", "Self", "HashMap",
            "HashSet",
        },
        .builtins = &.{
            "println!",  "print!",         "format!", "vec!",       "panic!",
            "todo!",     "unimplemented!", "assert!", "assert_eq!", "dbg!",
            "eprintln!", "eprint!",        "write!",  "writeln!",
        },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"",
        .annotation_prefix = '#',
        .supports_triple_quote = false,
    },
    // Go
    .{
        .name = "go",
        .aliases = &.{"golang"},
        .keywords = &.{
            "func",     "return",    "if",          "else",    "for",
            "range",    "switch",    "case",        "default", "break",
            "continue", "goto",      "fallthrough", "defer",   "go",
            "select",   "chan",      "var",         "const",   "type",
            "struct",   "interface", "map",         "package", "import",
            "true",     "false",     "nil",
        },
        .types = &.{
            "int",     "int8",    "int16",     "int32",      "int64",
            "uint",    "uint8",   "uint16",    "uint32",     "uint64",
            "float32", "float64", "complex64", "complex128", "string",
            "bool",    "byte",    "rune",      "error",      "uintptr",
            "any",
        },
        .builtins = &.{
            "make",   "len",     "cap",     "append", "copy",
            "delete", "new",     "close",   "panic",  "recover",
            "print",  "println", "complex", "real",   "imag",
        },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"'`",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // C
    .{
        .name = "c",
        .aliases = &.{"h"},
        .keywords = &.{
            "auto",     "break",    "case",    "char",   "const",
            "continue", "default",  "do",      "double", "else",
            "enum",     "extern",   "float",   "for",    "goto",
            "if",       "inline",   "int",     "long",   "register",
            "return",   "short",    "signed",  "sizeof", "static",
            "struct",   "switch",   "typedef", "union",  "unsigned",
            "void",     "volatile", "while",   "NULL",
        },
        .types = &.{
            "int",       "char",     "float",    "double",   "void",
            "long",      "short",    "unsigned", "signed",   "size_t",
            "uint8_t",   "uint16_t", "uint32_t", "uint64_t", "int8_t",
            "int16_t",   "int32_t",  "int64_t",  "bool",     "FILE",
            "ptrdiff_t",
        },
        .builtins = &.{
            "printf",  "scanf",  "malloc", "free",   "calloc",
            "realloc", "memcpy", "memset", "strlen", "strcmp",
            "fprintf", "fopen",  "fclose", "exit",   "abort",
        },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // C++
    .{
        .name = "cpp",
        .aliases = &.{ "c++", "cc", "cxx", "hpp" },
        .keywords = &.{
            "auto",      "break",    "case",      "class",     "const",
            "continue",  "default",  "delete",    "do",        "else",
            "enum",      "explicit", "extern",    "for",       "friend",
            "goto",      "if",       "inline",    "namespace", "new",
            "operator",  "private",  "protected", "public",    "return",
            "sizeof",    "static",   "struct",    "switch",    "template",
            "this",      "throw",    "try",       "catch",     "typedef",
            "typename",  "union",    "using",     "virtual",   "void",
            "volatile",  "while",    "nullptr",   "true",      "false",
            "constexpr", "noexcept", "override",  "final",
        },
        .types = &.{
            "int",        "char",       "float",    "double",   "bool",
            "void",       "long",       "short",    "unsigned", "signed",
            "string",     "vector",     "map",      "set",      "pair",
            "shared_ptr", "unique_ptr", "optional", "tuple",    "size_t",
        },
        .builtins = &.{
            "std",    "cout",  "cin",    "endl", "cerr",
            "printf", "scanf", "malloc", "free", "sizeof",
        },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // Bash
    .{
        .name = "bash",
        .aliases = &.{ "sh", "shell", "zsh" },
        .keywords = &.{
            "if",     "then",     "else",     "elif",    "fi",
            "for",    "while",    "do",       "done",    "case",
            "esac",   "in",       "function", "return",  "local",
            "export", "source",   "alias",    "unalias", "set",
            "unset",  "readonly", "declare",  "typeset", "true",
            "false",  "exit",
        },
        .types = &.{},
        .builtins = &.{
            "echo",  "cd",   "pwd",   "ls",    "rm",
            "cp",    "mv",   "mkdir", "cat",   "grep",
            "sed",   "awk",  "find",  "xargs", "chmod",
            "chown", "curl", "wget",  "tar",   "git",
            "sudo",  "apt",  "brew",  "npm",   "pip",
        },
        .line_comment = "#",
        .block_comment_start = null,
        .block_comment_end = null,
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // JSON
    .{
        .name = "json",
        .aliases = &.{"jsonc"},
        .keywords = &.{ "true", "false", "null" },
        .types = &.{},
        .builtins = &.{},
        .line_comment = null,
        .block_comment_start = null,
        .block_comment_end = null,
        .string_delimiters = "\"",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // YAML
    .{
        .name = "yaml",
        .aliases = &.{"yml"},
        .keywords = &.{ "true", "false", "null", "yes", "no", "on", "off" },
        .types = &.{},
        .builtins = &.{},
        .line_comment = "#",
        .block_comment_start = null,
        .block_comment_end = null,
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // HTML
    .{
        .name = "html",
        .aliases = &.{"htm"},
        .keywords = &.{
            "html",   "head",   "body",   "div",    "span",
            "p",      "a",      "img",    "ul",     "ol",
            "li",     "table",  "tr",     "td",     "th",
            "form",   "input",  "button", "script", "style",
            "link",   "meta",   "title",  "h1",     "h2",
            "h3",     "h4",     "h5",     "h6",     "section",
            "header", "footer", "nav",    "main",   "article",
        },
        .types = &.{},
        .builtins = &.{
            "class", "id",  "href",    "src",     "type", "name", "value",
            "style", "rel", "charset", "content", "alt",
        },
        .line_comment = null,
        .block_comment_start = "<!--",
        .block_comment_end = "-->",
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // CSS
    .{
        .name = "css",
        .aliases = &.{ "scss", "sass", "less" },
        .keywords = &.{
            "import",    "media",    "keyframes", "font-face",
            "charset",   "supports", "page",      "namespace",
            "important", "from",     "to",
        },
        .types = &.{
            "px",   "em", "rem", "vh",  "vw",   "vmin",
            "vmax", "ch", "ex",  "cm",  "mm",   "in",
            "pt",   "pc", "deg", "rad", "grad", "turn",
            "s",    "ms", "Hz",  "kHz", "dpi",  "dpcm",
        },
        .builtins = &.{
            "rgb",             "rgba",            "hsl",     "hsla",
            "calc",            "var",             "url",     "attr",
            "linear-gradient", "radial-gradient", "min",     "max",
            "clamp",           "env",             "counter",
        },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // SQL
    .{
        .name = "sql",
        .aliases = &.{ "mysql", "postgresql", "sqlite" },
        .keywords = &.{
            "SELECT", "FROM",    "WHERE",    "INSERT",  "INTO",
            "UPDATE", "DELETE",  "CREATE",   "DROP",    "ALTER",
            "TABLE",  "INDEX",   "VIEW",     "JOIN",    "LEFT",
            "RIGHT",  "INNER",   "OUTER",    "ON",      "AND",
            "OR",     "NOT",     "IN",       "LIKE",    "BETWEEN",
            "IS",     "NULL",    "AS",       "ORDER",   "BY",
            "GROUP",  "HAVING",  "LIMIT",    "OFFSET",  "UNION",
            "SET",    "VALUES",  "DISTINCT", "COUNT",   "SUM",
            "AVG",    "MAX",     "MIN",      "EXISTS",  "CASE",
            "WHEN",   "THEN",    "ELSE",     "END",     "TRUE",
            "FALSE",  "PRIMARY", "KEY",      "FOREIGN", "REFERENCES",
            "BEGIN",  "COMMIT",  "ROLLBACK", "GRANT",   "REVOKE",
        },
        .types = &.{
            "INT",     "INTEGER", "BIGINT",    "SMALLINT",
            "FLOAT",   "DOUBLE",  "DECIMAL",   "NUMERIC",
            "VARCHAR", "CHAR",    "TEXT",      "BLOB",
            "DATE",    "TIME",    "TIMESTAMP", "BOOLEAN",
            "SERIAL",  "UUID",
        },
        .builtins = &.{},
        .line_comment = "--",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // Lua
    .{
        .name = "lua",
        .aliases = &.{},
        .keywords = &.{
            "and",   "break",  "do",     "else",     "elseif",
            "end",   "false",  "for",    "function", "goto",
            "if",    "in",     "local",  "nil",      "not",
            "or",    "repeat", "return", "then",     "true",
            "until", "while",
        },
        .types = &.{},
        .builtins = &.{
            "print",        "type",         "tostring", "tonumber",
            "pairs",        "ipairs",       "next",     "select",
            "error",        "pcall",        "xpcall",   "require",
            "setmetatable", "getmetatable", "rawget",   "rawset",
            "table",        "string",       "math",     "io",
            "os",           "coroutine",
        },
        .line_comment = "--",
        .block_comment_start = "--[[",
        .block_comment_end = "]]",
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // Ruby
    .{
        .name = "ruby",
        .aliases = &.{"rb"},
        .keywords = &.{
            "def",         "end",         "class",   "module",       "if",
            "elsif",       "else",        "unless",  "while",        "until",
            "for",         "do",          "begin",   "rescue",       "ensure",
            "raise",       "return",      "yield",   "block_given?", "self",
            "super",       "true",        "false",   "nil",          "and",
            "or",          "not",         "in",      "then",         "when",
            "case",        "require",     "include", "extend",       "attr_accessor",
            "attr_reader", "attr_writer", "puts",    "lambda",       "proc",
        },
        .types = &.{
            "String", "Integer", "Float",   "Array", "Hash",
            "Symbol", "Proc",    "Method",  "Class", "Module",
            "Regexp", "Range",   "Numeric", "IO",    "File",
        },
        .builtins = &.{
            "puts",    "print",   "p",      "gets",    "chomp",
            "each",    "map",     "select", "reject",  "reduce",
            "flatten", "compact", "sort",   "reverse", "freeze",
        },
        .line_comment = "#",
        .block_comment_start = "=begin",
        .block_comment_end = "=end",
        .string_delimiters = "\"'",
        .annotation_prefix = null,
        .supports_triple_quote = false,
    },
    // Java
    .{
        .name = "java",
        .aliases = &.{},
        .keywords = &.{
            "abstract",   "assert",       "boolean",   "break",      "byte",
            "case",       "catch",        "char",      "class",      "const",
            "continue",   "default",      "do",        "double",     "else",
            "enum",       "extends",      "final",     "finally",    "float",
            "for",        "goto",         "if",        "implements", "import",
            "instanceof", "int",          "interface", "long",       "native",
            "new",        "package",      "private",   "protected",  "public",
            "return",     "short",        "static",    "strictfp",   "super",
            "switch",     "synchronized", "this",      "throw",      "throws",
            "transient",  "try",          "void",      "volatile",   "while",
            "true",       "false",        "null",      "var",        "record",
            "sealed",     "permits",      "yield",
        },
        .types = &.{
            "String",  "Integer",   "Long",   "Double",     "Float",
            "Boolean", "Character", "Byte",   "Short",      "Object",
            "List",    "Map",       "Set",    "ArrayList",  "HashMap",
            "HashSet", "Optional",  "Stream", "Collection", "Iterator",
        },
        .builtins = &.{
            "System",  "Math",   "Arrays",  "Collections",
            "Objects", "Thread", "Runtime", "Class",
        },
        .line_comment = "//",
        .block_comment_start = "/*",
        .block_comment_end = "*/",
        .string_delimiters = "\"'",
        .annotation_prefix = '@',
        .supports_triple_quote = false,
    },
};

// ── Tests ─────────────────────────────────────────────────────────────

test "findLang exact match" {
    const zig = findLang("zig");
    try std.testing.expect(zig != null);
    try std.testing.expectEqualStrings("zig", zig.?.name);
}

test "findLang alias match" {
    const js = findLang("js");
    try std.testing.expect(js != null);
    try std.testing.expectEqualStrings("javascript", js.?.name);

    const py = findLang("py");
    try std.testing.expect(py != null);
    try std.testing.expectEqualStrings("python", py.?.name);

    const ts = findLang("ts");
    try std.testing.expect(ts != null);
    try std.testing.expectEqualStrings("typescript", ts.?.name);
}

test "findLang case insensitive" {
    try std.testing.expect(findLang("Zig") != null);
    try std.testing.expect(findLang("PYTHON") != null);
    try std.testing.expect(findLang("JavaScript") != null);
}

test "findLang unknown" {
    try std.testing.expect(findLang("brainfuck") == null);
    try std.testing.expect(findLang("") == null);
}

test "all languages have names" {
    for (&all_languages) |*lang| {
        try std.testing.expect(lang.name.len > 0);
    }
}
