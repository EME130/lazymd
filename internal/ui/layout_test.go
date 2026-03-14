package ui

import "testing"

func TestLayoutCompute(t *testing.T) {
	l := NewLayout()
	l.Compute(120, 40)

	// No side panels, editor gets full width
	if l.EditorRect.W != 120 {
		t.Errorf("expected editor width 120, got %d", l.EditorRect.W)
	}
	bodyH := 40 - l.TitleH - l.StatusH - l.CommandH
	if l.EditorRect.H != bodyH {
		t.Errorf("expected editor height %d, got %d", bodyH, l.EditorRect.H)
	}
}

func TestLayoutWithPanels(t *testing.T) {
	l := NewLayout()
	l.ShowFileTree = true
	l.ShowPreview = true
	l.Compute(120, 40)

	if l.TreeRect.W == 0 {
		t.Error("expected non-zero tree width")
	}
	if l.PreviewRect.W == 0 {
		t.Error("expected non-zero preview width")
	}
	total := l.TreeRect.W + l.EditorRect.W + l.PreviewRect.W
	if total != 120 {
		t.Errorf("expected total width 120, got %d", total)
	}
}

func TestLayoutToggle(t *testing.T) {
	l := NewLayout()

	l.TogglePanel(PanelFileTree)
	if !l.ShowFileTree {
		t.Error("expected file tree visible")
	}

	l.TogglePanel(PanelPreview)
	if !l.ShowPreview {
		t.Error("expected preview visible")
	}

	// Brain toggles off preview
	l.TogglePanel(PanelBrain)
	if !l.ShowBrain {
		t.Error("expected brain visible")
	}
	if l.ShowPreview {
		t.Error("expected preview hidden when brain is shown")
	}
}

func TestLayoutCyclePanel(t *testing.T) {
	l := NewLayout()
	l.ActivePanel = PanelEditor

	// Only editor visible, cycle stays on editor
	l.CyclePanel()
	if l.ActivePanel != PanelEditor {
		t.Errorf("expected PanelEditor, got %d", l.ActivePanel)
	}

	// Show file tree, cycle should go to file tree
	l.ShowFileTree = true
	l.ActivePanel = PanelEditor
	l.CyclePanel()
	if l.ActivePanel != PanelFileTree {
		t.Errorf("expected PanelFileTree after cycle, got %d", l.ActivePanel)
	}
}

func TestLayoutHitTest(t *testing.T) {
	l := NewLayout()
	l.ShowFileTree = true
	l.Compute(120, 40)

	// Click in file tree area
	p := l.HitTest(5, 10)
	if p != PanelFileTree {
		t.Errorf("expected PanelFileTree, got %d", p)
	}

	// Click in editor area
	p = l.HitTest(l.TreeRect.W+5, 10)
	if p != PanelEditor {
		t.Errorf("expected PanelEditor, got %d", p)
	}
}
