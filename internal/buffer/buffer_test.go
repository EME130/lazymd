package buffer

import "testing"

func TestInsertAndRead(t *testing.T) {
	buf := New()
	buf.InsertString(0, "Hello\nWorld")

	if buf.Length() != 11 {
		t.Fatalf("expected length 11, got %d", buf.Length())
	}
	if buf.LineCount() != 2 {
		t.Fatalf("expected 2 lines, got %d", buf.LineCount())
	}
	if buf.Line(0) != "Hello" {
		t.Fatalf("expected line 0 = %q, got %q", "Hello", buf.Line(0))
	}
	if buf.Line(1) != "World" {
		t.Fatalf("expected line 1 = %q, got %q", "World", buf.Line(1))
	}
}

func TestDelete(t *testing.T) {
	buf := New()
	buf.InsertString(0, "ABCDE")
	buf.DeleteRange(1, 2)

	if buf.Length() != 3 {
		t.Fatalf("expected length 3, got %d", buf.Length())
	}
	if buf.Line(0) != "ADE" {
		t.Fatalf("expected line 0 = %q, got %q", "ADE", buf.Line(0))
	}
}

func TestUndoInsert(t *testing.T) {
	buf := New()
	buf.InsertString(0, "Hello")

	if buf.Length() != 5 {
		t.Fatalf("expected length 5, got %d", buf.Length())
	}
	buf.Undo()
	if buf.Length() != 0 {
		t.Fatalf("expected length 0 after undo, got %d", buf.Length())
	}
}

func TestPositionConversion(t *testing.T) {
	buf := New()
	buf.InsertString(0, "Line1\nLine2\nLine3")

	pos := buf.OffsetToPos(7)
	if pos.Row != 1 || pos.Col != 1 {
		t.Fatalf("expected row=1 col=1, got row=%d col=%d", pos.Row, pos.Col)
	}

	off := buf.PosToOffset(2, 3)
	if off != 15 {
		t.Fatalf("expected offset 15, got %d", off)
	}
}

func TestFileIO(t *testing.T) {
	buf := New()
	buf.InsertString(0, "Hello\nWorld\n")

	path := t.TempDir() + "/test.md"
	if err := buf.SaveFile(path); err != nil {
		t.Fatalf("SaveFile: %v", err)
	}
	if buf.IsDirty() {
		t.Fatal("expected not dirty after save")
	}

	buf2 := New()
	if err := buf2.LoadFile(path); err != nil {
		t.Fatalf("LoadFile: %v", err)
	}
	if buf2.Content() != "Hello\nWorld\n" {
		t.Fatalf("expected %q, got %q", "Hello\nWorld\n", buf2.Content())
	}
}

func TestRedo(t *testing.T) {
	buf := New()
	buf.InsertString(0, "Hello")
	buf.Undo()
	if buf.Length() != 0 {
		t.Fatalf("expected length 0 after undo, got %d", buf.Length())
	}
	buf.Redo()
	if buf.Length() != 5 {
		t.Fatalf("expected length 5 after redo, got %d", buf.Length())
	}
	if buf.Line(0) != "Hello" {
		t.Fatalf("expected %q, got %q", "Hello", buf.Line(0))
	}
}

func TestSetContent(t *testing.T) {
	buf := New()
	buf.InsertString(0, "old content")

	buf.SetContent("Hello\nNew World")

	if buf.LineCount() != 2 {
		t.Fatalf("expected 2 lines, got %d", buf.LineCount())
	}
	if buf.Line(0) != "Hello" {
		t.Fatalf("expected line 0 = %q, got %q", "Hello", buf.Line(0))
	}
	if buf.Line(1) != "New World" {
		t.Fatalf("expected line 1 = %q, got %q", "New World", buf.Line(1))
	}
	if buf.IsDirty() {
		t.Fatal("expected buffer to not be dirty after SetContent")
	}
	if buf.Length() != 15 {
		t.Fatalf("expected length 15, got %d", buf.Length())
	}
}

func TestSetContentClearsUndo(t *testing.T) {
	buf := New()
	buf.InsertString(0, "first")
	buf.InsertString(5, " second")

	buf.SetContent("replaced")

	buf.Undo()
	if buf.Content() != "replaced" {
		t.Fatalf("expected undo to be no-op after SetContent, got %q", buf.Content())
	}
}

func TestSetContentEmpty(t *testing.T) {
	buf := New()
	buf.InsertString(0, "something")

	buf.SetContent("")

	if buf.Length() != 0 {
		t.Fatalf("expected length 0, got %d", buf.Length())
	}
	if buf.LineCount() != 1 {
		t.Fatalf("expected 1 line, got %d", buf.LineCount())
	}
}
