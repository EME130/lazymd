package ui

import (
	"fmt"
	"math"
	"strings"

	"github.com/EME130/lazymd/internal/brain"
	"github.com/EME130/lazymd/internal/themes"
	"github.com/charmbracelet/lipgloss"
)

// Force-directed layout constants.
const (
	maxIterations = 100
	repulsion     = 500.0
	attraction    = 0.05
	damping       = 0.9
	centerPull    = 0.01
	minDist       = 1.0
)

type pos struct{ x, y float64 }

type cell struct {
	ch    rune
	style lipgloss.Style
}

// BrainViewModel displays the knowledge graph as a force-directed ASCII layout.
type BrainViewModel struct {
	Graph        *brain.Graph
	positions    []pos
	SelectedNode int
	CurrentFile  int // node ID of current file, -1 if none
	LocalMode    bool
	settled      bool
	iteration    int
	viewportX    float64
	viewportY    float64
	zoom         float64
}

// NewBrainView creates a new brain view model.
func NewBrainView() BrainViewModel {
	return BrainViewModel{
		SelectedNode: 0,
		CurrentFile:  -1,
		zoom:         1.0,
	}
}

// SetGraph sets the graph and initializes node positions.
func (bv *BrainViewModel) SetGraph(g *brain.Graph) {
	bv.Graph = g
	bv.settled = false
	bv.iteration = 0
	bv.positions = nil

	n := len(g.Nodes)
	if n == 0 {
		return
	}

	bv.positions = make([]pos, n)
	radius := float64(min(n*3, 40))
	for i := range bv.positions {
		angle := float64(i) * (2.0 * math.Pi / float64(n))
		bv.positions[i] = pos{
			x: radius * math.Cos(angle),
			y: radius * math.Sin(angle),
		}
	}

	if bv.SelectedNode >= n {
		bv.SelectedNode = 0
	}
}

// SetCurrentFile sets the current file node by name.
func (bv *BrainViewModel) SetCurrentFile(name string) {
	if bv.Graph == nil {
		return
	}
	if id, ok := bv.Graph.Resolve(name); ok {
		bv.CurrentFile = int(id)
	} else {
		bv.CurrentFile = -1
	}
}

// StepLayout runs one iteration of the force-directed layout.
func (bv *BrainViewModel) StepLayout() {
	if bv.settled || bv.iteration >= maxIterations {
		return
	}
	g := bv.Graph
	if g == nil {
		return
	}
	n := len(g.Nodes)
	if n <= 1 {
		bv.settled = true
		return
	}

	forces := make([]pos, n)

	// Repulsion between all pairs
	for i := 0; i < n; i++ {
		for j := i + 1; j < n; j++ {
			dx := bv.positions[j].x - bv.positions[i].x
			dy := bv.positions[j].y - bv.positions[i].y
			dist := math.Sqrt(dx*dx + dy*dy)
			if dist < minDist {
				dist = minDist
				dx = 0.5
				dy = 0.5
			}
			force := repulsion / (dist * dist)
			fx := (dx / dist) * force
			fy := (dy / dist) * force
			forces[i].x -= fx
			forces[i].y -= fy
			forces[j].x += fx
			forces[j].y += fy
		}
	}

	// Attraction along edges
	for _, edge := range g.Edges {
		dx := bv.positions[edge.To].x - bv.positions[edge.From].x
		dy := bv.positions[edge.To].y - bv.positions[edge.From].y
		fx := dx * attraction
		fy := dy * attraction
		forces[edge.From].x += fx
		forces[edge.From].y += fy
		forces[edge.To].x -= fx
		forces[edge.To].y -= fy
	}

	// Center pull
	for i := 0; i < n; i++ {
		forces[i].x -= bv.positions[i].x * centerPull
		forces[i].y -= bv.positions[i].y * centerPull
	}

	// Apply forces with damping
	maxMove := 0.0
	for i := 0; i < n; i++ {
		fx := forces[i].x * damping
		fy := forces[i].y * damping
		bv.positions[i].x += fx
		bv.positions[i].y += fy
		move := math.Abs(fx) + math.Abs(fy)
		if move > maxMove {
			maxMove = move
		}
	}

	bv.iteration++
	if maxMove < 0.1 || bv.iteration >= maxIterations {
		bv.settled = true
	}
}

// MoveSelection moves the selected node by delta.
func (bv *BrainViewModel) MoveSelection(delta int) {
	if bv.Graph == nil {
		return
	}
	n := len(bv.Graph.Nodes)
	if n == 0 {
		return
	}
	bv.SelectedNode = ((bv.SelectedNode + delta) % n + n) % n
}

// View renders the brain view panel.
func (bv *BrainViewModel) View(rect Rect) string {
	c := themes.CurrentColors()

	if bv.Graph == nil {
		style := lipgloss.NewStyle().
			Width(rect.W).Height(rect.H).
			Foreground(lipgloss.Color(c.TextMuted))
		return style.Render("  No graph loaded")
	}

	g := bv.Graph
	n := len(g.Nodes)
	if n == 0 {
		style := lipgloss.NewStyle().
			Width(rect.W).Height(rect.H).
			Foreground(lipgloss.Color(c.TextMuted))
		return style.Render("  No notes found")
	}

	// Run layout steps
	if !bv.settled {
		for range 3 {
			bv.StepLayout()
		}
	}

	// Create a character grid
	gridW := rect.W - 2 // account for border
	gridH := rect.H - 2 // status line + border
	if gridW < 1 {
		gridW = 1
	}
	if gridH < 1 {
		gridH = 1
	}

	grid := make([][]cell, gridH)
	for i := range grid {
		grid[i] = make([]cell, gridW)
		for j := range grid[i] {
			grid[i][j] = cell{ch: ' ', style: lipgloss.NewStyle()}
		}
	}

	cx := float64(gridW) / 2.0
	cy := float64(gridH) / 2.0

	worldToScreen := func(wx, wy float64) (int, int) {
		sx := int((wx*bv.zoom-bv.viewportX)+cx)
		sy := int((wy*bv.zoom*0.5-bv.viewportY)+cy) // 0.5 aspect ratio
		return sx, sy
	}

	// Determine visible nodes
	visible := make([]int, 0, n)
	if bv.LocalMode {
		center := bv.SelectedNode
		if bv.CurrentFile >= 0 {
			center = bv.CurrentFile
		}
		neighbors := g.GetNeighbors(uint16(center), 2)
		for _, nid := range neighbors {
			visible = append(visible, int(nid))
		}
	} else {
		for i := 0; i < n; i++ {
			visible = append(visible, i)
		}
	}

	isVis := make([]bool, n)
	for _, v := range visible {
		isVis[v] = true
	}

	// Draw edges as dots
	edgeDot := lipgloss.NewStyle().Foreground(lipgloss.Color(c.Border))
	for _, edge := range g.Edges {
		if !isVis[int(edge.From)] || !isVis[int(edge.To)] {
			continue
		}
		x1, y1 := worldToScreen(bv.positions[edge.From].x, bv.positions[edge.From].y)
		x2, y2 := worldToScreen(bv.positions[edge.To].x, bv.positions[edge.To].y)
		drawLineOnGrid(grid, gridW, gridH, x1, y1, x2, y2, '·', edgeDot)
	}

	// Draw nodes
	for _, nid := range visible {
		sx, sy := worldToScreen(bv.positions[nid].x, bv.positions[nid].y)
		if sy < 0 || sy >= gridH || sx < 0 || sx >= gridW {
			continue
		}

		isSelected := nid == bv.SelectedNode
		isCurrent := nid == bv.CurrentFile

		var nodeStyle lipgloss.Style
		marker := '•'
		if isCurrent {
			nodeStyle = lipgloss.NewStyle().Foreground(lipgloss.Color(c.Success)).Bold(true)
			marker = '◉'
		} else if isSelected {
			nodeStyle = lipgloss.NewStyle().Foreground(lipgloss.Color(c.BorderActive)).Bold(true)
			marker = '○'
		} else {
			nodeStyle = lipgloss.NewStyle().Foreground(lipgloss.Color(c.Text))
		}

		grid[sy][sx] = cell{ch: marker, style: nodeStyle}

		// Draw label after marker
		label := g.Nodes[nid].Name
		maxLen := gridW - sx - 2
		if maxLen > 0 {
			if len(label) > maxLen {
				label = label[:maxLen]
			}
			for ci, ch := range label {
				col := sx + 1 + ci
				if col >= gridW {
					break
				}
				grid[sy][col] = cell{ch: ch, style: nodeStyle}
			}
		}
	}

	// Render grid to lines
	lines := make([]string, 0, gridH+1)
	for _, row := range grid {
		var sb strings.Builder
		for _, c := range row {
			sb.WriteString(c.style.Render(string(c.ch)))
		}
		lines = append(lines, sb.String())
	}

	// Status line
	var status string
	if bv.SelectedNode >= 0 && bv.SelectedNode < n {
		node := g.Nodes[bv.SelectedNode]
		mode := "GRAPH"
		if bv.LocalMode {
			mode = "LOCAL"
		}
		status = fmt.Sprintf(" %s  out:%d in:%d  [%s]",
			node.Name, len(node.OutLinks), len(node.InLinks), mode)
	}
	statusStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color(c.TitleFg)).Bold(true)
	lines = append(lines, statusStyle.Render(status))

	content := strings.Join(lines, "\n")
	border := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, false, false, true).
		BorderForeground(lipgloss.Color(c.Border)).
		Width(rect.W).Height(rect.H)
	return border.Render(content)
}

// drawLineOnGrid draws a simple line of characters between two points using Bresenham-lite.
func drawLineOnGrid(grid [][]cell, gridW, gridH, x1, y1, x2, y2 int, ch rune, style lipgloss.Style) {
	dx := x2 - x1
	dy := y2 - y1
	steps := abs(dx)
	if abs(dy) > steps {
		steps = abs(dy)
	}
	if steps == 0 {
		return
	}
	if steps > 200 {
		steps = 200
	}

	sx := float64(dx) / float64(steps)
	sy := float64(dy) / float64(steps)
	px := float64(x1)
	py := float64(y1)

	for range steps {
		ix := int(px)
		iy := int(py)
		if ix >= 0 && ix < gridW && iy >= 0 && iy < gridH {
			grid[iy][ix] = cell{ch: ch, style: style}
		}
		px += sx
		py += sy
	}
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
