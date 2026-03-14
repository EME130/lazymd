package highlight

import "testing"

func TestFindLangExact(t *testing.T) {
	lang := FindLang("zig")
	if lang == nil {
		t.Fatal("expected to find zig")
	}
	if lang.Name != "zig" {
		t.Fatalf("expected name 'zig', got %q", lang.Name)
	}
}

func TestFindLangAlias(t *testing.T) {
	js := FindLang("js")
	if js == nil || js.Name != "javascript" {
		t.Fatal("expected 'js' to resolve to 'javascript'")
	}
	py := FindLang("py")
	if py == nil || py.Name != "python" {
		t.Fatal("expected 'py' to resolve to 'python'")
	}
	ts := FindLang("ts")
	if ts == nil || ts.Name != "typescript" {
		t.Fatal("expected 'ts' to resolve to 'typescript'")
	}
}

func TestFindLangCaseInsensitive(t *testing.T) {
	if FindLang("Zig") == nil {
		t.Error("expected to find Zig")
	}
	if FindLang("PYTHON") == nil {
		t.Error("expected to find PYTHON")
	}
	if FindLang("JavaScript") == nil {
		t.Error("expected to find JavaScript")
	}
}

func TestFindLangUnknown(t *testing.T) {
	if FindLang("brainfuck") != nil {
		t.Error("expected brainfuck not found")
	}
	if FindLang("") != nil {
		t.Error("expected empty string not found")
	}
}

func TestAllLanguagesHaveNames(t *testing.T) {
	for _, lang := range allLanguages {
		if lang.Name == "" {
			t.Error("found language with empty name")
		}
	}
}

func TestHighlightZigKeywords(t *testing.T) {
	state := &State{}
	h := NewBuiltin()
	spans := h.Tokenize("const x = 5;", "zig", state)

	if len(spans) == 0 {
		t.Fatal("expected spans")
	}
	if spans[0].Kind != Keyword {
		t.Fatalf("expected first span to be keyword, got %v", spans[0].Kind)
	}
	if "const x = 5;"[spans[0].Start:spans[0].End] != "const" {
		t.Fatalf("expected 'const', got %q", "const x = 5;"[spans[0].Start:spans[0].End])
	}
}

func TestHighlightZigString(t *testing.T) {
	state := &State{}
	h := NewBuiltin()
	line := `const s = "hello";`
	spans := h.Tokenize(line, "zig", state)

	foundString := false
	for _, span := range spans {
		if span.Kind == String {
			got := line[span.Start:span.End]
			if got != `"hello"` {
				t.Fatalf("expected '\"hello\"', got %q", got)
			}
			foundString = true
		}
	}
	if !foundString {
		t.Fatal("expected to find a string span")
	}
}

func TestHighlightLineComment(t *testing.T) {
	state := &State{}
	h := NewBuiltin()
	spans := h.Tokenize("// this is a comment", "zig", state)

	if len(spans) != 1 {
		t.Fatalf("expected 1 span, got %d", len(spans))
	}
	if spans[0].Kind != Comment {
		t.Fatalf("expected comment, got %v", spans[0].Kind)
	}
}

func TestHighlightBlockComment(t *testing.T) {
	state := &State{}
	h := NewBuiltin()
	spans := h.Tokenize("/* comment */ code", "javascript", state)

	if len(spans) < 2 {
		t.Fatalf("expected at least 2 spans, got %d", len(spans))
	}
	if spans[0].Kind != Comment {
		t.Fatalf("expected comment, got %v", spans[0].Kind)
	}
	if state.InBlockComment {
		t.Fatal("expected not in block comment")
	}
}

func TestHighlightMultilineBlockComment(t *testing.T) {
	state := &State{}
	h := NewBuiltin()

	spans := h.Tokenize("/* start", "javascript", state)
	if !state.InBlockComment {
		t.Fatal("expected in block comment after opening")
	}
	_ = spans

	spans = h.Tokenize("end */ const x = 1;", "javascript", state)
	if state.InBlockComment {
		t.Fatal("expected not in block comment after closing")
	}
	if len(spans) < 2 {
		t.Fatalf("expected at least 2 spans, got %d", len(spans))
	}
	if spans[0].Kind != Comment {
		t.Fatalf("expected first span to be comment, got %v", spans[0].Kind)
	}
}

func TestHighlightZigBuiltin(t *testing.T) {
	state := &State{}
	h := NewBuiltin()
	spans := h.Tokenize(`@import("std")`, "zig", state)

	if len(spans) == 0 {
		t.Fatal("expected spans")
	}
	if spans[0].Kind != Builtin {
		t.Fatalf("expected builtin, got %v", spans[0].Kind)
	}
}

func TestHighlightNumbers(t *testing.T) {
	state := &State{}
	h := NewBuiltin()
	spans := h.Tokenize("0xff 42 3.14", "zig", state)

	numCount := 0
	for _, span := range spans {
		if span.Kind == Number {
			numCount++
		}
	}
	if numCount != 3 {
		t.Fatalf("expected 3 numbers, got %d", numCount)
	}
}

func TestHighlightPython(t *testing.T) {
	state := &State{}
	h := NewBuiltin()
	line := "def hello(name: str):"
	spans := h.Tokenize(line, "python", state)

	if len(spans) == 0 {
		t.Fatal("expected spans")
	}
	if spans[0].Kind != Keyword {
		t.Fatalf("expected keyword, got %v", spans[0].Kind)
	}
	if line[spans[0].Start:spans[0].End] != "def" {
		t.Fatalf("expected 'def', got %q", line[spans[0].Start:spans[0].End])
	}
}

func TestHighlightEmptyLine(t *testing.T) {
	state := &State{}
	h := NewBuiltin()
	spans := h.Tokenize("", "zig", state)
	if len(spans) != 0 {
		t.Fatalf("expected 0 spans, got %d", len(spans))
	}
}

func TestSupportsLanguage(t *testing.T) {
	h := NewBuiltin()
	if !h.SupportsLanguage("zig") {
		t.Error("expected zig supported")
	}
	if !h.SupportsLanguage("python") {
		t.Error("expected python supported")
	}
	if h.SupportsLanguage("brainfuck") {
		t.Error("expected brainfuck not supported")
	}
}
