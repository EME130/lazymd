package ui

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/EME130/lazymd/internal/brain"
	"github.com/EME130/lazymd/internal/buffer"
)

func TestFileTreeScan(t *testing.T) {
	// Create a temp directory with some files
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "notes.md"), []byte("# Notes"), 0644)
	os.WriteFile(filepath.Join(dir, "todo.rndm"), []byte("# Todo"), 0644)
	os.WriteFile(filepath.Join(dir, "ignore.txt"), []byte("nope"), 0644)
	os.Mkdir(filepath.Join(dir, "subdir"), 0755)
	os.WriteFile(filepath.Join(dir, "subdir", "nested.md"), []byte("# Nested"), 0644)

	ft := NewFileTree(dir)
	if len(ft.Entries) < 3 {
		t.Errorf("expected at least 3 entries (dir + 2 md files), got %d", len(ft.Entries))
	}

	// Should not include .txt files
	for _, e := range ft.Entries {
		if filepath.Ext(e.Name) == ".txt" {
			t.Errorf("unexpected .txt file: %s", e.Name)
		}
	}

	// Dirs should come first
	if len(ft.Entries) > 0 && !ft.Entries[0].IsDir {
		t.Error("expected first entry to be a directory")
	}
}

func TestFileTreeNavigation(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.md"), []byte("a"), 0644)
	os.WriteFile(filepath.Join(dir, "b.md"), []byte("b"), 0644)

	ft := NewFileTree(dir)
	if ft.Cursor != 0 {
		t.Error("expected cursor at 0")
	}

	ft.MoveDown()
	if ft.Cursor != 1 {
		t.Errorf("expected cursor at 1, got %d", ft.Cursor)
	}

	ft.MoveUp()
	if ft.Cursor != 0 {
		t.Errorf("expected cursor at 0, got %d", ft.Cursor)
	}

	// MoveUp at 0 stays at 0
	ft.MoveUp()
	if ft.Cursor != 0 {
		t.Errorf("expected cursor to stay at 0, got %d", ft.Cursor)
	}
}

func TestFileTreeHiddenFiles(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, ".hidden.md"), []byte("hidden"), 0644)
	os.WriteFile(filepath.Join(dir, "visible.md"), []byte("visible"), 0644)

	ft := NewFileTree(dir)
	for _, e := range ft.Entries {
		if e.Name == ".hidden.md" {
			t.Error("hidden files should be excluded")
		}
	}
}

func TestPreviewInvalidate(t *testing.T) {
	p := NewPreview()
	if !p.dirty {
		t.Error("expected preview to start dirty")
	}

	buf := buffer.New()
	buf.InsertString(0, "# Hello\n\nWorld\n")

	// RenderNow should clear dirty flag
	p.RenderNow(buf, Rect{W: 40, H: 10})
	if p.dirty {
		t.Error("expected preview to be clean after render")
	}

	p.Invalidate()
	if !p.dirty {
		t.Error("expected preview to be dirty after invalidate")
	}
}

func TestPreviewScrolling(t *testing.T) {
	p := NewPreview()
	p.ScrollDown(5)
	if p.scrollOff != 5 {
		t.Errorf("expected scroll 5, got %d", p.scrollOff)
	}

	p.ScrollUp(3)
	if p.scrollOff != 2 {
		t.Errorf("expected scroll 2, got %d", p.scrollOff)
	}

	p.ScrollUp(10)
	if p.scrollOff != 0 {
		t.Error("expected scroll to clamp at 0")
	}
}

func TestBrainViewSetGraph(t *testing.T) {
	bv := NewBrainView()
	g := brain.NewGraph()
	a := g.AddNode("alpha", "alpha.md")
	b := g.AddNode("beta", "beta.md")
	g.AddEdge(a, b)
	g.BuildLinks()

	bv.SetGraph(g)
	if bv.Graph == nil {
		t.Error("expected graph to be set")
	}
	if len(bv.positions) != 2 {
		t.Errorf("expected 2 positions, got %d", len(bv.positions))
	}
}

func TestBrainViewLayoutConverges(t *testing.T) {
	bv := NewBrainView()
	g := brain.NewGraph()
	a := g.AddNode("a", "a.md")
	b := g.AddNode("b", "b.md")
	c := g.AddNode("c", "c.md")
	g.AddEdge(a, b)
	g.AddEdge(b, c)
	g.BuildLinks()

	bv.SetGraph(g)
	for range 200 {
		bv.StepLayout()
	}
	if !bv.settled {
		t.Error("expected layout to settle")
	}
}

func TestBrainViewSelection(t *testing.T) {
	bv := NewBrainView()
	g := brain.NewGraph()
	g.AddNode("a", "a.md")
	g.AddNode("b", "b.md")
	g.AddNode("c", "c.md")
	g.BuildLinks()

	bv.SetGraph(g)
	if bv.SelectedNode != 0 {
		t.Errorf("expected selected 0, got %d", bv.SelectedNode)
	}

	bv.MoveSelection(1)
	if bv.SelectedNode != 1 {
		t.Errorf("expected selected 1, got %d", bv.SelectedNode)
	}

	bv.MoveSelection(-1)
	if bv.SelectedNode != 0 {
		t.Errorf("expected selected 0, got %d", bv.SelectedNode)
	}

	// Wrap around
	bv.MoveSelection(-1)
	if bv.SelectedNode != 2 {
		t.Errorf("expected selected 2 (wrap), got %d", bv.SelectedNode)
	}
}

func TestBrainViewCurrentFile(t *testing.T) {
	bv := NewBrainView()
	g := brain.NewGraph()
	g.AddNode("alpha", "alpha.md")
	g.AddNode("beta", "beta.md")
	g.BuildLinks()

	bv.SetGraph(g)
	bv.SetCurrentFile("beta")
	if bv.CurrentFile != 1 {
		t.Errorf("expected current file 1, got %d", bv.CurrentFile)
	}

	bv.SetCurrentFile("nonexistent")
	if bv.CurrentFile != -1 {
		t.Errorf("expected -1 for nonexistent, got %d", bv.CurrentFile)
	}
}
