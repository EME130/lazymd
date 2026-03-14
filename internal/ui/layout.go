package ui

// Panel identifies a UI panel.
type Panel int

const (
	PanelEditor Panel = iota
	PanelFileTree
	PanelPreview
	PanelBrain
)

// Rect holds computed dimensions for a panel.
type Rect struct {
	W, H int
}

// LayoutState manages panel layout and visibility.
type LayoutState struct {
	ActivePanel  Panel
	ShowFileTree bool
	ShowPreview  bool
	ShowBrain    bool

	TreeRect    Rect
	EditorRect  Rect
	PreviewRect Rect
	BrainRect   Rect

	// Status/command bar heights
	TitleH   int
	StatusH  int
	CommandH int
}

// NewLayout creates a default layout state.
func NewLayout() LayoutState {
	return LayoutState{
		ActivePanel:  PanelEditor,
		ShowFileTree: false,
		ShowPreview:  false,
		ShowBrain:    false,
		TitleH:       1,
		StatusH:      1,
		CommandH:     1,
	}
}

// Compute recalculates panel dimensions based on terminal size.
// Algorithm matches Layout.zig: tree_w = min(w/5, 30), right_w = min(w/4, 40).
func (l *LayoutState) Compute(w, h int) {
	bodyH := h - l.TitleH - l.StatusH - l.CommandH
	if bodyH < 1 {
		bodyH = 1
	}

	treeW := 0
	if l.ShowFileTree {
		treeW = w / 5
		if treeW > 30 {
			treeW = 30
		}
		if treeW < 10 {
			treeW = 10
		}
	}

	rightW := 0
	if l.ShowPreview || l.ShowBrain {
		rightW = w / 4
		if rightW > 40 {
			rightW = 40
		}
		if rightW < 10 {
			rightW = 10
		}
	}

	editorW := w - treeW - rightW
	if editorW < 10 {
		editorW = 10
	}

	l.TreeRect = Rect{W: treeW, H: bodyH}
	l.EditorRect = Rect{W: editorW, H: bodyH}

	if l.ShowBrain {
		l.BrainRect = Rect{W: rightW, H: bodyH}
		l.PreviewRect = Rect{}
	} else if l.ShowPreview {
		l.PreviewRect = Rect{W: rightW, H: bodyH}
		l.BrainRect = Rect{}
	} else {
		l.PreviewRect = Rect{}
		l.BrainRect = Rect{}
	}
}

// TogglePanel toggles a panel's visibility.
func (l *LayoutState) TogglePanel(p Panel) {
	switch p {
	case PanelFileTree:
		l.ShowFileTree = !l.ShowFileTree
	case PanelPreview:
		l.ShowPreview = !l.ShowPreview
		if l.ShowPreview {
			l.ShowBrain = false
		}
	case PanelBrain:
		l.ShowBrain = !l.ShowBrain
		if l.ShowBrain {
			l.ShowPreview = false
		}
	}
}

// CyclePanel moves focus to the next visible panel.
func (l *LayoutState) CyclePanel() {
	panels := []Panel{PanelEditor}
	if l.ShowFileTree {
		panels = append([]Panel{PanelFileTree}, panels...)
	}
	if l.ShowPreview {
		panels = append(panels, PanelPreview)
	}
	if l.ShowBrain {
		panels = append(panels, PanelBrain)
	}

	for i, p := range panels {
		if p == l.ActivePanel {
			l.ActivePanel = panels[(i+1)%len(panels)]
			return
		}
	}
	l.ActivePanel = PanelEditor
}

// HitTest returns which panel occupies a given x coordinate.
func (l *LayoutState) HitTest(x, _ int) Panel {
	offset := 0
	if l.ShowFileTree {
		offset += l.TreeRect.W
		if x < offset {
			return PanelFileTree
		}
	}
	offset += l.EditorRect.W
	if x < offset {
		return PanelEditor
	}
	if l.ShowBrain {
		return PanelBrain
	}
	if l.ShowPreview {
		return PanelPreview
	}
	return PanelEditor
}
