package brain

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAddNodesAndEdges(t *testing.T) {
	g := NewGraph()
	a := g.AddNode("note-a", "notes/note-a.md")
	b := g.AddNode("note-b", "notes/note-b.md")
	c := g.AddNode("note-c", "note-c.md")

	g.AddEdge(a, b)
	g.AddEdge(a, c)
	g.AddEdge(b, c)
	g.BuildLinks()

	if g.NodeCount() != 3 {
		t.Fatalf("expected 3 nodes, got %d", g.NodeCount())
	}
	if g.EdgeCount() != 3 {
		t.Fatalf("expected 3 edges, got %d", g.EdgeCount())
	}

	if len(g.Nodes[a].OutLinks) != 2 {
		t.Fatalf("expected 2 out-links for a, got %d", len(g.Nodes[a].OutLinks))
	}
	if len(g.Nodes[b].OutLinks) != 1 {
		t.Fatalf("expected 1 out-link for b, got %d", len(g.Nodes[b].OutLinks))
	}
	if len(g.Nodes[c].OutLinks) != 0 {
		t.Fatalf("expected 0 out-links for c, got %d", len(g.Nodes[c].OutLinks))
	}
	if len(g.Nodes[a].InLinks) != 0 {
		t.Fatalf("expected 0 in-links for a, got %d", len(g.Nodes[a].InLinks))
	}
	if len(g.Nodes[b].InLinks) != 1 {
		t.Fatalf("expected 1 in-link for b, got %d", len(g.Nodes[b].InLinks))
	}
	if len(g.Nodes[c].InLinks) != 2 {
		t.Fatalf("expected 2 in-links for c, got %d", len(g.Nodes[c].InLinks))
	}
}

func TestResolveWikiLinks(t *testing.T) {
	g := NewGraph()
	g.AddNode("daily-note", "notes/daily-note.md")
	g.AddNode("README", "README.md")

	id, ok := g.Resolve("daily-note")
	if !ok || id != 0 {
		t.Fatalf("expected id 0, got %d (ok=%v)", id, ok)
	}
	id, ok = g.Resolve("readme")
	if !ok || id != 1 {
		t.Fatalf("expected id 1, got %d (ok=%v)", id, ok)
	}
	id, ok = g.Resolve("daily-note|My Daily Note")
	if !ok || id != 0 {
		t.Fatalf("expected id 0 for alias, got %d (ok=%v)", id, ok)
	}
	id, ok = g.Resolve("notes/daily-note")
	if !ok || id != 0 {
		t.Fatalf("expected id 0 for path, got %d (ok=%v)", id, ok)
	}
	_, ok = g.Resolve("nonexistent")
	if ok {
		t.Fatal("expected not found")
	}
}

func TestDuplicateEdgePrevention(t *testing.T) {
	g := NewGraph()
	a := g.AddNode("a", "a.md")
	b := g.AddNode("b", "b.md")
	g.AddEdge(a, b)
	g.AddEdge(a, b) // duplicate
	if g.EdgeCount() != 1 {
		t.Fatalf("expected 1 edge, got %d", g.EdgeCount())
	}
}

func TestOrphanDetection(t *testing.T) {
	g := NewGraph()
	a := g.AddNode("a", "a.md")
	b := g.AddNode("b", "b.md")
	g.AddNode("orphan", "orphan.md") // id=2
	g.AddEdge(a, b)
	g.BuildLinks()

	orphans := g.GetOrphans()
	if len(orphans) != 1 {
		t.Fatalf("expected 1 orphan, got %d", len(orphans))
	}
	if orphans[0] != 2 {
		t.Fatalf("expected orphan id 2, got %d", orphans[0])
	}
}

func TestBFSNeighbors(t *testing.T) {
	g := NewGraph()
	a := g.AddNode("a", "a.md")
	b := g.AddNode("b", "b.md")
	c := g.AddNode("c", "c.md")
	g.AddNode("d", "d.md") // id=3
	g.AddEdge(a, b)
	g.AddEdge(b, c)
	g.AddEdge(c, 3)
	g.BuildLinks()

	n1 := g.GetNeighbors(a, 1)
	if len(n1) != 2 {
		t.Fatalf("expected 2 neighbors at depth 1, got %d", len(n1))
	}

	n2 := g.GetNeighbors(a, 2)
	if len(n2) != 3 {
		t.Fatalf("expected 3 neighbors at depth 2, got %d", len(n2))
	}
}

func TestFindPath(t *testing.T) {
	g := NewGraph()
	a := g.AddNode("a", "a.md")
	b := g.AddNode("b", "b.md")
	c := g.AddNode("c", "c.md")
	g.AddNode("d", "d.md") // id=3, isolated
	g.AddEdge(a, b)
	g.AddEdge(b, c)
	g.BuildLinks()

	path, ok := g.FindPath(a, c)
	if !ok {
		t.Fatal("expected path to exist")
	}
	if len(path) != 3 {
		t.Fatalf("expected path length 3, got %d", len(path))
	}
	if path[0] != a || path[1] != b || path[2] != c {
		t.Fatalf("expected path [a,b,c], got %v", path)
	}

	// Same node
	path, ok = g.FindPath(a, a)
	if !ok {
		t.Fatal("expected same-node path")
	}
	if len(path) != 1 {
		t.Fatalf("expected path length 1, got %d", len(path))
	}

	// No path
	_, ok = g.FindPath(a, 3)
	if ok {
		t.Fatal("expected no path to isolated node")
	}
}

func TestExtractWikiLinks(t *testing.T) {
	links := ExtractWikiLinks("See [[foo]] and [[bar|Bar Note]] here")
	if len(links) != 2 {
		t.Fatalf("expected 2 links, got %d", len(links))
	}
	if links[0] != "foo" {
		t.Fatalf("expected 'foo', got %q", links[0])
	}
	if links[1] != "bar" {
		t.Fatalf("expected 'bar', got %q", links[1])
	}
}

func TestExtractWikiLinksIgnoresBroken(t *testing.T) {
	links := ExtractWikiLinks("[[good]] and [[broken\nlink]] end")
	if len(links) != 1 {
		t.Fatalf("expected 1 link, got %d", len(links))
	}
	if links[0] != "good" {
		t.Fatalf("expected 'good', got %q", links[0])
	}
}

func TestExtractStem(t *testing.T) {
	tests := []struct {
		input, want string
	}{
		{"notes/daily-note.md", "daily-note"},
		{"README.md", "README"},
		{"a/b/c/test.rndm", "test"},
		{"noext", "noext"},
	}
	for _, tt := range tests {
		got := extractStem(tt.input)
		if got != tt.want {
			t.Errorf("extractStem(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestIsMarkdown(t *testing.T) {
	if !isMarkdown("test.md") {
		t.Error("expected test.md to be markdown")
	}
	if !isMarkdown("test.rndm") {
		t.Error("expected test.rndm to be markdown")
	}
	if isMarkdown("test.txt") {
		t.Error("expected test.txt not to be markdown")
	}
}

func TestScan(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "note-a.md"), []byte("Hello [[note-b]]"), 0644)
	os.WriteFile(filepath.Join(dir, "note-b.md"), []byte("Link to [[note-a]]"), 0644)
	os.WriteFile(filepath.Join(dir, "orphan.md"), []byte("No links here"), 0644)

	g, err := Scan(dir)
	if err != nil {
		t.Fatal(err)
	}
	if g.NodeCount() != 3 {
		t.Fatalf("expected 3 nodes, got %d", g.NodeCount())
	}
	if g.EdgeCount() != 2 {
		t.Fatalf("expected 2 edges, got %d", g.EdgeCount())
	}

	orphans := g.GetOrphans()
	if len(orphans) != 1 {
		t.Fatalf("expected 1 orphan, got %d", len(orphans))
	}
}
