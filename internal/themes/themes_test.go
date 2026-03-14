package themes

import "testing"

func TestThemeLookup(t *testing.T) {
	idx, ok := FindByName("dracula")
	if !ok {
		t.Fatal("dracula not found")
	}
	if BuiltinThemes[idx].Name != "dracula" {
		t.Errorf("expected dracula, got %s", BuiltinThemes[idx].Name)
	}

	_, ok = FindByName("nonexistent")
	if ok {
		t.Error("nonexistent should not be found")
	}

	idx, ok = FindByName("default")
	if !ok || idx != 0 {
		t.Errorf("default should be index 0, got %d", idx)
	}
}

func TestThemeCycle(t *testing.T) {
	currentIndex = 0
	Cycle()
	if currentIndex != 1 {
		t.Errorf("expected 1, got %d", currentIndex)
	}

	currentIndex = len(BuiltinThemes) - 1
	Cycle()
	if currentIndex != 0 {
		t.Errorf("expected 0 after wrap, got %d", currentIndex)
	}
	currentIndex = 0
}

func TestThemeCount(t *testing.T) {
	if Count() < 12 {
		t.Errorf("expected >= 12 themes, got %d", Count())
	}
}

func TestSyntaxColor(t *testing.T) {
	tc := &BuiltinThemes[0].Colors
	if tc.SyntaxColor("keyword") != tc.SynKeyword {
		t.Error("keyword mismatch")
	}
	if tc.SyntaxColor("string") != tc.SynString {
		t.Error("string mismatch")
	}
	if tc.SyntaxColor("comment") != tc.SynComment {
		t.Error("comment mismatch")
	}
}

func TestSetByName(t *testing.T) {
	currentIndex = 0
	ok := SetByName("nord")
	if !ok {
		t.Fatal("nord not found")
	}
	if Current().Name != "nord" {
		t.Errorf("expected nord, got %s", Current().Name)
	}
	currentIndex = 0
}
