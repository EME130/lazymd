package highlight

import "strings"

// LangDef defines a programming language for syntax highlighting.
type LangDef struct {
	Name              string
	Aliases           []string
	Keywords          []string
	Types             []string
	Builtins          []string
	LineComment       string // empty if none
	BlockCommentStart string // empty if none
	BlockCommentEnd   string // empty if none
	StringDelimiters  string // single-char delimiters like `"'`
	AnnotationPrefix  byte   // 0 if none
	SupportsTripleQt  bool
}

// FindLang finds a language definition by name or alias (case-insensitive).
func FindLang(name string) *LangDef {
	for i := range allLanguages {
		if strings.EqualFold(allLanguages[i].Name, name) {
			return &allLanguages[i]
		}
		for _, alias := range allLanguages[i].Aliases {
			if strings.EqualFold(alias, name) {
				return &allLanguages[i]
			}
		}
	}
	return nil
}

var allLanguages = []LangDef{
	{
		Name:    "zig",
		Aliases: nil,
		Keywords: []string{
			"const", "var", "fn", "return", "if",
			"else", "while", "for", "switch", "break",
			"continue", "defer", "errdefer", "try", "catch",
			"pub", "test", "struct", "enum", "union",
			"error", "orelse", "and", "or", "comptime",
			"inline", "nosuspend", "threadlocal", "export", "extern",
			"unreachable", "undefined", "null", "true", "false",
			"async", "await", "suspend", "resume", "volatile",
			"align", "allowzero", "noalias", "asm", "usingnamespace",
		},
		Types: []string{
			"u8", "u16", "u32", "u64", "u128", "usize",
			"i8", "i16", "i32", "i64", "i128", "isize",
			"f16", "f32", "f64", "f128", "bool", "void",
			"type", "anytype", "anyerror", "anyopaque", "anyframe", "c_int",
			"c_uint", "c_long", "c_ulong", "c_char",
		},
		Builtins: []string{
			"@import", "@as", "@intCast", "@floatCast",
			"@ptrCast", "@alignCast", "@enumFromInt", "@intFromEnum",
			"@bitCast", "@truncate", "@embedFile", "@src",
			"@This", "@typeInfo", "@TypeOf", "@sizeOf",
			"@min", "@max", "@memcpy", "@memset",
		},
		LineComment:      "//",
		StringDelimiters: "\"",
		AnnotationPrefix: '@',
	},
	{
		Name:    "python",
		Aliases: []string{"py", "python3"},
		Keywords: []string{
			"def", "class", "return", "if", "elif", "else",
			"for", "while", "break", "continue", "pass", "import",
			"from", "as", "try", "except", "finally", "raise",
			"with", "yield", "lambda", "and", "or", "not",
			"in", "is", "global", "nonlocal", "assert", "del",
			"True", "False", "None", "async", "await",
		},
		Types: []string{
			"int", "float", "str", "bool", "list", "dict",
			"tuple", "set", "bytes", "type", "object",
		},
		Builtins: []string{
			"print", "len", "range", "enumerate",
			"zip", "map", "filter", "isinstance",
			"hasattr", "getattr", "setattr", "super",
			"property", "classmethod", "staticmethod", "input",
			"open", "sorted", "reversed", "any",
			"all", "abs", "min", "max",
		},
		LineComment:       "#",
		StringDelimiters:  "\"'",
		AnnotationPrefix:  '@',
		SupportsTripleQt:  true,
	},
	{
		Name:    "javascript",
		Aliases: []string{"js", "jsx"},
		Keywords: []string{
			"const", "let", "var", "function", "return",
			"if", "else", "for", "while", "do",
			"switch", "case", "break", "continue", "default",
			"try", "catch", "finally", "throw", "new",
			"class", "extends", "import", "export", "from",
			"async", "await", "yield", "typeof", "instanceof",
			"in", "of", "delete", "void", "this",
			"super", "true", "false", "null", "undefined",
		},
		Types: []string{
			"Array", "Object", "String", "Number", "Boolean",
			"Promise", "Map", "Set", "Symbol", "BigInt",
		},
		Builtins: []string{
			"console", "Math", "JSON", "parseInt",
			"parseFloat", "isNaN", "setTimeout", "setInterval",
			"fetch", "require", "module", "process",
		},
		LineComment:       "//",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"'`",
	},
	{
		Name:    "typescript",
		Aliases: []string{"ts", "tsx"},
		Keywords: []string{
			"const", "let", "var", "function", "return",
			"if", "else", "for", "while", "do",
			"switch", "case", "break", "continue", "default",
			"try", "catch", "finally", "throw", "new",
			"class", "extends", "implements", "import", "export",
			"from", "async", "await", "yield", "typeof",
			"instanceof", "in", "of", "delete", "void",
			"this", "super", "true", "false", "null",
			"undefined", "type", "interface", "enum", "namespace",
			"declare", "abstract", "readonly", "as", "is",
			"keyof", "infer", "satisfies",
		},
		Types: []string{
			"string", "number", "boolean", "any", "unknown",
			"never", "void", "object", "Array", "Promise",
			"Record", "Partial", "Required", "Readonly", "Pick",
			"Omit", "Exclude", "Extract", "Map", "Set",
		},
		Builtins: []string{
			"console", "Math", "JSON", "parseInt",
			"parseFloat", "isNaN", "setTimeout", "setInterval",
			"fetch", "require", "module", "process",
		},
		LineComment:       "//",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"'`",
		AnnotationPrefix:  '@',
	},
	{
		Name:    "rust",
		Aliases: []string{"rs"},
		Keywords: []string{
			"fn", "let", "mut", "const", "static",
			"if", "else", "match", "for", "while",
			"loop", "break", "continue", "return", "struct",
			"enum", "impl", "trait", "type", "where",
			"pub", "use", "mod", "crate", "self",
			"super", "as", "in", "ref", "move",
			"async", "await", "dyn", "unsafe", "extern",
			"true", "false",
		},
		Types: []string{
			"i8", "i16", "i32", "i64", "i128", "isize",
			"u8", "u16", "u32", "u64", "u128", "usize",
			"f32", "f64", "bool", "char", "str", "String",
			"Vec", "Box", "Option", "Result", "Self", "HashMap",
			"HashSet",
		},
		Builtins: []string{
			"println!", "print!", "format!", "vec!", "panic!",
			"todo!", "unimplemented!", "assert!", "assert_eq!", "dbg!",
			"eprintln!", "eprint!", "write!", "writeln!",
		},
		LineComment:       "//",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"",
		AnnotationPrefix:  '#',
	},
	{
		Name:    "go",
		Aliases: []string{"golang"},
		Keywords: []string{
			"func", "return", "if", "else", "for",
			"range", "switch", "case", "default", "break",
			"continue", "goto", "fallthrough", "defer", "go",
			"select", "chan", "var", "const", "type",
			"struct", "interface", "map", "package", "import",
			"true", "false", "nil",
		},
		Types: []string{
			"int", "int8", "int16", "int32", "int64",
			"uint", "uint8", "uint16", "uint32", "uint64",
			"float32", "float64", "complex64", "complex128", "string",
			"bool", "byte", "rune", "error", "uintptr",
			"any",
		},
		Builtins: []string{
			"make", "len", "cap", "append", "copy",
			"delete", "new", "close", "panic", "recover",
			"print", "println", "complex", "real", "imag",
		},
		LineComment:       "//",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"'`",
	},
	{
		Name:    "c",
		Aliases: []string{"h"},
		Keywords: []string{
			"auto", "break", "case", "char", "const",
			"continue", "default", "do", "double", "else",
			"enum", "extern", "float", "for", "goto",
			"if", "inline", "int", "long", "register",
			"return", "short", "signed", "sizeof", "static",
			"struct", "switch", "typedef", "union", "unsigned",
			"void", "volatile", "while", "NULL",
		},
		Types: []string{
			"int", "char", "float", "double", "void",
			"long", "short", "unsigned", "signed", "size_t",
			"uint8_t", "uint16_t", "uint32_t", "uint64_t", "int8_t",
			"int16_t", "int32_t", "int64_t", "bool", "FILE",
			"ptrdiff_t",
		},
		Builtins: []string{
			"printf", "scanf", "malloc", "free", "calloc",
			"realloc", "memcpy", "memset", "strlen", "strcmp",
			"fprintf", "fopen", "fclose", "exit", "abort",
		},
		LineComment:       "//",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"'",
	},
	{
		Name:    "cpp",
		Aliases: []string{"c++", "cc", "cxx", "hpp"},
		Keywords: []string{
			"auto", "break", "case", "class", "const",
			"continue", "default", "delete", "do", "else",
			"enum", "explicit", "extern", "for", "friend",
			"goto", "if", "inline", "namespace", "new",
			"operator", "private", "protected", "public", "return",
			"sizeof", "static", "struct", "switch", "template",
			"this", "throw", "try", "catch", "typedef",
			"typename", "union", "using", "virtual", "void",
			"volatile", "while", "nullptr", "true", "false",
			"constexpr", "noexcept", "override", "final",
		},
		Types: []string{
			"int", "char", "float", "double", "bool",
			"void", "long", "short", "unsigned", "signed",
			"string", "vector", "map", "set", "pair",
			"shared_ptr", "unique_ptr", "optional", "tuple", "size_t",
		},
		Builtins: []string{
			"std", "cout", "cin", "endl", "cerr",
			"printf", "scanf", "malloc", "free", "sizeof",
		},
		LineComment:       "//",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"'",
	},
	{
		Name:    "bash",
		Aliases: []string{"sh", "shell", "zsh"},
		Keywords: []string{
			"if", "then", "else", "elif", "fi",
			"for", "while", "do", "done", "case",
			"esac", "in", "function", "return", "local",
			"export", "source", "alias", "unalias", "set",
			"unset", "readonly", "declare", "typeset", "true",
			"false", "exit",
		},
		Types:    nil,
		Builtins: []string{
			"echo", "cd", "pwd", "ls", "rm",
			"cp", "mv", "mkdir", "cat", "grep",
			"sed", "awk", "find", "xargs", "chmod",
			"chown", "curl", "wget", "tar", "git",
			"sudo", "apt", "brew", "npm", "pip",
		},
		LineComment:      "#",
		StringDelimiters: "\"'",
	},
	{
		Name:    "json",
		Aliases: []string{"jsonc"},
		Keywords: []string{"true", "false", "null"},
		StringDelimiters: "\"",
	},
	{
		Name:    "yaml",
		Aliases: []string{"yml"},
		Keywords: []string{"true", "false", "null", "yes", "no", "on", "off"},
		LineComment:      "#",
		StringDelimiters: "\"'",
	},
	{
		Name:    "html",
		Aliases: []string{"htm"},
		Keywords: []string{
			"html", "head", "body", "div", "span",
			"p", "a", "img", "ul", "ol",
			"li", "table", "tr", "td", "th",
			"form", "input", "button", "script", "style",
			"link", "meta", "title", "h1", "h2",
			"h3", "h4", "h5", "h6", "section",
			"header", "footer", "nav", "main", "article",
		},
		Builtins: []string{
			"class", "id", "href", "src", "type", "name", "value",
			"style", "rel", "charset", "content", "alt",
		},
		BlockCommentStart: "<!--",
		BlockCommentEnd:   "-->",
		StringDelimiters:  "\"'",
	},
	{
		Name:    "css",
		Aliases: []string{"scss", "sass", "less"},
		Keywords: []string{
			"import", "media", "keyframes", "font-face",
			"charset", "supports", "page", "namespace",
			"important", "from", "to",
		},
		Types: []string{
			"px", "em", "rem", "vh", "vw", "vmin",
			"vmax", "ch", "ex", "cm", "mm", "in",
			"pt", "pc", "deg", "rad", "grad", "turn",
			"s", "ms", "Hz", "kHz", "dpi", "dpcm",
		},
		Builtins: []string{
			"rgb", "rgba", "hsl", "hsla",
			"calc", "var", "url", "attr",
			"linear-gradient", "radial-gradient", "min", "max",
			"clamp", "env", "counter",
		},
		LineComment:       "//",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"'",
	},
	{
		Name:    "sql",
		Aliases: []string{"mysql", "postgresql", "sqlite"},
		Keywords: []string{
			"SELECT", "FROM", "WHERE", "INSERT", "INTO",
			"UPDATE", "DELETE", "CREATE", "DROP", "ALTER",
			"TABLE", "INDEX", "VIEW", "JOIN", "LEFT",
			"RIGHT", "INNER", "OUTER", "ON", "AND",
			"OR", "NOT", "IN", "LIKE", "BETWEEN",
			"IS", "NULL", "AS", "ORDER", "BY",
			"GROUP", "HAVING", "LIMIT", "OFFSET", "UNION",
			"SET", "VALUES", "DISTINCT", "COUNT", "SUM",
			"AVG", "MAX", "MIN", "EXISTS", "CASE",
			"WHEN", "THEN", "ELSE", "END", "TRUE",
			"FALSE", "PRIMARY", "KEY", "FOREIGN", "REFERENCES",
			"BEGIN", "COMMIT", "ROLLBACK", "GRANT", "REVOKE",
		},
		Types: []string{
			"INT", "INTEGER", "BIGINT", "SMALLINT",
			"FLOAT", "DOUBLE", "DECIMAL", "NUMERIC",
			"VARCHAR", "CHAR", "TEXT", "BLOB",
			"DATE", "TIME", "TIMESTAMP", "BOOLEAN",
			"SERIAL", "UUID",
		},
		LineComment:       "--",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"'",
	},
	{
		Name:    "lua",
		Aliases: nil,
		Keywords: []string{
			"and", "break", "do", "else", "elseif",
			"end", "false", "for", "function", "goto",
			"if", "in", "local", "nil", "not",
			"or", "repeat", "return", "then", "true",
			"until", "while",
		},
		Builtins: []string{
			"print", "type", "tostring", "tonumber",
			"pairs", "ipairs", "next", "select",
			"error", "pcall", "xpcall", "require",
			"setmetatable", "getmetatable", "rawget", "rawset",
			"table", "string", "math", "io",
			"os", "coroutine",
		},
		LineComment:       "--",
		BlockCommentStart: "--[[",
		BlockCommentEnd:   "]]",
		StringDelimiters:  "\"'",
	},
	{
		Name:    "ruby",
		Aliases: []string{"rb"},
		Keywords: []string{
			"def", "end", "class", "module", "if",
			"elsif", "else", "unless", "while", "until",
			"for", "do", "begin", "rescue", "ensure",
			"raise", "return", "yield", "block_given?", "self",
			"super", "true", "false", "nil", "and",
			"or", "not", "in", "then", "when",
			"case", "require", "include", "extend", "attr_accessor",
			"attr_reader", "attr_writer", "puts", "lambda", "proc",
		},
		Types: []string{
			"String", "Integer", "Float", "Array", "Hash",
			"Symbol", "Proc", "Method", "Class", "Module",
			"Regexp", "Range", "Numeric", "IO", "File",
		},
		Builtins: []string{
			"puts", "print", "p", "gets", "chomp",
			"each", "map", "select", "reject", "reduce",
			"flatten", "compact", "sort", "reverse", "freeze",
		},
		LineComment:       "#",
		BlockCommentStart: "=begin",
		BlockCommentEnd:   "=end",
		StringDelimiters:  "\"'",
	},
	{
		Name:    "java",
		Aliases: nil,
		Keywords: []string{
			"abstract", "assert", "boolean", "break", "byte",
			"case", "catch", "char", "class", "const",
			"continue", "default", "do", "double", "else",
			"enum", "extends", "final", "finally", "float",
			"for", "goto", "if", "implements", "import",
			"instanceof", "int", "interface", "long", "native",
			"new", "package", "private", "protected", "public",
			"return", "short", "static", "strictfp", "super",
			"switch", "synchronized", "this", "throw", "throws",
			"transient", "try", "void", "volatile", "while",
			"true", "false", "null", "var", "record",
			"sealed", "permits", "yield",
		},
		Types: []string{
			"String", "Integer", "Long", "Double", "Float",
			"Boolean", "Character", "Byte", "Short", "Object",
			"List", "Map", "Set", "ArrayList", "HashMap",
			"HashSet", "Optional", "Stream", "Collection", "Iterator",
		},
		Builtins: []string{
			"System", "Math", "Arrays", "Collections",
			"Objects", "Thread", "Runtime", "Class",
		},
		LineComment:       "//",
		BlockCommentStart: "/*",
		BlockCommentEnd:   "*/",
		StringDelimiters:  "\"'",
		AnnotationPrefix:  '@',
	},
}
