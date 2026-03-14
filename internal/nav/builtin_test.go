package nav

import (
	"strings"
	"testing"

	"github.com/EME130/lazymd/internal/buffer"
)

func TestResolveHeadingPathSimple(t *testing.T) {
	buf := buffer.New()
	buf.InsertString(0, "# Plan\nSome text\n## Step 1\nContent\n### Subtask A\nDetails")

	match := resolveHeadingPath(buf, "Plan/Step 1/Subtask A")
	if match == nil {
		t.Fatal("expected match, got nil")
	}
	if match.line != 4 {
		t.Fatalf("expected line 4, got %d", match.line)
	}
	if match.level != 3 {
		t.Fatalf("expected level 3, got %d", match.level)
	}
}

func TestResolveHeadingPathNotFound(t *testing.T) {
	buf := buffer.New()
	buf.InsertString(0, "# Plan\n## Step 1")

	match := resolveHeadingPath(buf, "Plan/Nonexistent")
	if match != nil {
		t.Fatal("expected nil, got match")
	}
}

func TestReadSection(t *testing.T) {
	buf := buffer.New()
	buf.InsertString(0, "# Plan\nIntro\n## Step 1\nContent 1\n## Step 2\nContent 2")

	nav := NewBuiltin(buf)
	section, err := nav.ReadSection("Plan/Step 1")
	if err != nil {
		t.Fatal(err)
	}
	if section.HeadingLine != 2 {
		t.Fatalf("expected heading line 2, got %d", section.HeadingLine)
	}
	if section.Level != 2 {
		t.Fatalf("expected level 2, got %d", section.Level)
	}
	if !strings.Contains(section.Content, "Content 1") {
		t.Fatal("expected content to contain 'Content 1'")
	}
	if strings.Contains(section.Content, "Content 2") {
		t.Fatal("expected content NOT to contain 'Content 2'")
	}
}

func TestListTasks(t *testing.T) {
	buf := buffer.New()
	buf.InsertString(0, "# Plan\n- [x] Done task\n- [ ] Pending task\nSome text\n- [ ] Another pending")

	nav := NewBuiltin(buf)
	all, err := nav.ListTasks(nil, TaskAll)
	if err != nil {
		t.Fatal(err)
	}
	if len(all) != 3 {
		t.Fatalf("expected 3 tasks, got %d", len(all))
	}
	if !all[0].Done {
		t.Fatal("expected task 0 to be done")
	}
	if all[1].Done {
		t.Fatal("expected task 1 to be pending")
	}

	pending, err := nav.ListTasks(nil, TaskPending)
	if err != nil {
		t.Fatal(err)
	}
	if len(pending) != 2 {
		t.Fatalf("expected 2 pending tasks, got %d", len(pending))
	}
}

func TestUpdateTask(t *testing.T) {
	buf := buffer.New()
	buf.InsertString(0, "# Plan\n- [ ] My task\nEnd")

	nav := NewBuiltin(buf)
	result, err := nav.UpdateTask(1, true)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(result, "[x]") {
		t.Fatalf("expected [x] in result, got %q", result)
	}
	// Verify buffer was updated
	line := buf.Line(1)
	if !strings.Contains(line, "[x]") {
		t.Fatalf("expected [x] in buffer line, got %q", line)
	}
}

func TestGetBreadcrumb(t *testing.T) {
	buf := buffer.New()
	buf.InsertString(0, "# Doc\n## Section A\n### Sub\nContent here")

	nav := NewBuiltin(buf)
	bc, err := nav.GetBreadcrumb(3)
	if err != nil {
		t.Fatal(err)
	}
	if bc != "Doc > Section A > Sub" {
		t.Fatalf("expected %q, got %q", "Doc > Section A > Sub", bc)
	}
}

func TestBuildBreadcrumbNoHeading(t *testing.T) {
	buf := buffer.New()
	buf.InsertString(0, "Just some text\nNo headings")

	bc := buildBreadcrumb(buf, 0)
	if bc != "(no heading)" {
		t.Fatalf("expected %q, got %q", "(no heading)", bc)
	}
}

func TestReadSectionRange(t *testing.T) {
	buf := buffer.New()
	buf.InsertString(0, "# Doc\n## Section\nLine A\nLine B\nLine C\n## Other")

	nav := NewBuiltin(buf)
	start, end := 1, 3
	ranged, err := nav.ReadSectionRange("Doc/Section", &start, &end)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(ranged, "Line A") {
		t.Fatal("expected 'Line A' in range")
	}
	if !strings.Contains(ranged, "Line B") {
		t.Fatal("expected 'Line B' in range")
	}
}
