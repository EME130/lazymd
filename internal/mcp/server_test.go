package mcp

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	mcplib "github.com/mark3labs/mcp-go/mcp"

	"github.com/EME130/lazymd/internal/buffer"
)

func newTestServer(content string) *LazyMDServer {
	buf := buffer.New()
	buf.InsertString(0, content)
	srv := New(buf)
	srv.filePath = "test.md"
	return srv
}

func makeReq(args map[string]any) mcplib.CallToolRequest {
	req := mcplib.CallToolRequest{}
	req.Params.Arguments = args
	return req
}

type toolFunc func(context.Context, mcplib.CallToolRequest) (*mcplib.CallToolResult, error)

func call(t *testing.T, fn toolFunc, args map[string]any) string {
	t.Helper()
	result, err := fn(context.Background(), makeReq(args))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(result.Content) == 0 {
		return ""
	}
	text, ok := result.Content[0].(mcplib.TextContent)
	if !ok {
		t.Fatalf("expected TextContent, got %T", result.Content[0])
	}
	return text.Text
}

func TestReadDocument(t *testing.T) {
	srv := newTestServer("Hello, world!\n")
	result := call(t, srv.toolReadDocument, nil)
	if result != "Hello, world!\n" {
		t.Errorf("expected 'Hello, world!\\n', got %q", result)
	}
}

func TestListHeadings(t *testing.T) {
	srv := newTestServer("# Title\n\nSome text\n\n## Section A\n\nContent\n\n## Section B\n")
	result := call(t, srv.toolListHeadings, nil)

	for _, want := range []string{"Title", "Section A", "Section B"} {
		if !strings.Contains(result, want) {
			t.Errorf("expected %q in result: %s", want, result)
		}
	}
}

func TestEditSection(t *testing.T) {
	srv := newTestServer("## Intro\n\nOld content\n\n## Next\n")
	call(t, srv.toolEditSection, map[string]any{
		"heading": "Intro",
		"content": "\nNew content here\n",
	})

	doc := call(t, srv.toolReadDocument, nil)
	if !strings.Contains(doc, "New content here") {
		t.Errorf("expected new content: %s", doc)
	}
	if strings.Contains(doc, "Old content") {
		t.Errorf("old content should be replaced: %s", doc)
	}
	if !strings.Contains(doc, "## Next") {
		t.Errorf("next section preserved: %s", doc)
	}
}

func TestInsertText(t *testing.T) {
	srv := newTestServer("Line 1\nLine 2\n")
	call(t, srv.toolInsertText, map[string]any{
		"text": "Inserted\n",
		"line": float64(2),
	})

	doc := call(t, srv.toolReadDocument, nil)
	if !strings.Contains(doc, "Inserted\nLine 2") {
		t.Errorf("expected inserted text before line 2: %s", doc)
	}
}

func TestDeleteLines(t *testing.T) {
	srv := newTestServer("Line 1\nLine 2\nLine 3\n")
	call(t, srv.toolDeleteLines, map[string]any{
		"start_line": float64(2),
		"end_line":   float64(2),
	})

	doc := call(t, srv.toolReadDocument, nil)
	if strings.Contains(doc, "Line 2") {
		t.Errorf("Line 2 should be deleted: %s", doc)
	}
}

func TestSearchContent(t *testing.T) {
	srv := newTestServer("Apple pie\nBanana split\nApple sauce\n")
	result := call(t, srv.toolSearchContent, map[string]any{
		"query": "apple",
	})

	if !strings.Contains(result, "Apple pie") || !strings.Contains(result, "Apple sauce") {
		t.Errorf("expected apple matches: %s", result)
	}
	if strings.Contains(result, "Banana") {
		t.Errorf("Banana should not match: %s", result)
	}
}

func TestGetStructure(t *testing.T) {
	srv := newTestServer("# Doc\n\n## Part 1\n\n## Part 2\n")
	result := call(t, srv.toolGetStructure, nil)

	for _, want := range []string{"Doc", "Part 1", "Part 2"} {
		if !strings.Contains(result, want) {
			t.Errorf("expected %q in structure: %s", want, result)
		}
	}
}

func TestReadSection(t *testing.T) {
	srv := newTestServer("# Doc\n\n## Plan\n\nStep details here\n\n## Other\n")
	result := call(t, srv.toolReadSection, map[string]any{
		"heading_path": "Plan",
	})

	if !strings.Contains(result, "Step details here") {
		t.Errorf("expected section content: %s", result)
	}
}

func TestListTasks(t *testing.T) {
	srv := newTestServer("# Tasks\n\n- [ ] Do thing\n- [x] Done thing\n- [ ] Another\n")
	result := call(t, srv.toolListTasks, map[string]any{
		"status": "pending",
	})

	if !strings.Contains(result, "Do thing") {
		t.Errorf("expected pending task: %s", result)
	}
	if strings.Contains(result, "Done thing") {
		t.Errorf("done task should be filtered: %s", result)
	}
}

func TestUpdateTask(t *testing.T) {
	srv := newTestServer("# Tasks\n\n- [ ] Pending task\n")
	call(t, srv.toolUpdateTask, map[string]any{
		"line": float64(3),
		"done": true,
	})

	doc := call(t, srv.toolReadDocument, nil)
	if !strings.Contains(doc, "- [x] Pending task") {
		t.Errorf("task should be marked done: %s", doc)
	}
}

func TestGetBreadcrumb(t *testing.T) {
	srv := newTestServer("# Doc\n\n## Section\n\nContent\n")
	result := call(t, srv.toolGetBreadcrumb, map[string]any{
		"line": float64(5),
	})

	if !strings.Contains(result, "Doc") || !strings.Contains(result, "Section") {
		t.Errorf("expected breadcrumb with Doc > Section: %s", result)
	}
}

func TestListLinks(t *testing.T) {
	srv := newTestServer("Check [[note-a]] and [[note-b|alias]]\n")
	result := call(t, srv.toolListLinks, nil)

	if !strings.Contains(result, "note-a") || !strings.Contains(result, "note-b") {
		t.Errorf("expected wiki links: %s", result)
	}
}

func TestOpenAndWriteFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.md")
	os.WriteFile(path, []byte("# Hello\n"), 0644)

	buf := buffer.New()
	srv := New(buf)

	call(t, srv.toolOpenFile, map[string]any{"path": path})

	doc := call(t, srv.toolReadDocument, nil)
	if !strings.Contains(doc, "# Hello") {
		t.Errorf("expected file content: %s", doc)
	}

	// Modify and save
	call(t, srv.toolInsertText, map[string]any{"text": "\nWorld\n"})
	call(t, srv.toolWriteDocument, map[string]any{})

	saved, _ := os.ReadFile(path)
	if !strings.Contains(string(saved), "World") {
		t.Errorf("expected saved content to contain World: %s", string(saved))
	}
}

func TestMoveSection(t *testing.T) {
	srv := newTestServer("# Doc\n\n## A\n\nContent A\n\n## B\n\nContent B\n\n## C\n\nContent C\n")
	call(t, srv.toolMoveSection, map[string]any{
		"heading": "A",
		"after":   "B",
	})

	doc := call(t, srv.toolReadDocument, nil)
	bIdx := strings.Index(doc, "## B")
	aIdx := strings.Index(doc, "## A")
	if bIdx < 0 || aIdx < 0 || aIdx < bIdx {
		t.Errorf("expected A after B: %s", doc)
	}
}
