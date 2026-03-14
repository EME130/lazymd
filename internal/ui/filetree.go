package ui

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/EME130/lazymd/internal/themes"
	"github.com/charmbracelet/lipgloss"
)

// FileEntry represents a file or directory in the tree.
type FileEntry struct {
	Name  string
	Path  string
	IsDir bool
	Depth int
}

// FileTreeModel manages the file tree panel.
type FileTreeModel struct {
	Entries  []FileEntry
	Cursor   int
	ScrollOff int
	RootDir  string
}

// NewFileTree creates a file tree model rooted at dir.
func NewFileTree(dir string) FileTreeModel {
	ft := FileTreeModel{RootDir: dir}
	ft.Scan()
	return ft
}

// Scan scans the root directory and populates entries.
func (ft *FileTreeModel) Scan() {
	ft.Entries = ft.Entries[:0]
	ft.scanDir(ft.RootDir, 0)
}

func (ft *FileTreeModel) scanDir(dir string, depth int) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}

	// Sort: dirs first, then alphabetical
	sort.Slice(entries, func(i, j int) bool {
		di, dj := entries[i].IsDir(), entries[j].IsDir()
		if di != dj {
			return di
		}
		return strings.ToLower(entries[i].Name()) < strings.ToLower(entries[j].Name())
	})

	for _, e := range entries {
		name := e.Name()
		// Skip hidden files/dirs
		if strings.HasPrefix(name, ".") {
			continue
		}

		fullPath := filepath.Join(dir, name)

		if e.IsDir() {
			ft.Entries = append(ft.Entries, FileEntry{
				Name:  name,
				Path:  fullPath,
				IsDir: true,
				Depth: depth,
			})
			// Don't recurse deeply to keep it fast
			if depth < 2 {
				ft.scanDir(fullPath, depth+1)
			}
		} else {
			ext := filepath.Ext(name)
			if ext == ".md" || ext == ".rndm" {
				ft.Entries = append(ft.Entries, FileEntry{
					Name:  name,
					Path:  fullPath,
					IsDir: false,
					Depth: depth,
				})
			}
		}
	}
}

// SelectedPath returns the path of the currently selected entry.
func (ft *FileTreeModel) SelectedPath() string {
	if ft.Cursor >= 0 && ft.Cursor < len(ft.Entries) {
		return ft.Entries[ft.Cursor].Path
	}
	return ""
}

// MoveUp moves cursor up.
func (ft *FileTreeModel) MoveUp() {
	if ft.Cursor > 0 {
		ft.Cursor--
	}
}

// MoveDown moves cursor down.
func (ft *FileTreeModel) MoveDown() {
	if ft.Cursor < len(ft.Entries)-1 {
		ft.Cursor++
	}
}

// View renders the file tree into the given rect dimensions.
func (ft *FileTreeModel) View(rect Rect) string {
	c := themes.CurrentColors()
	if len(ft.Entries) == 0 {
		style := lipgloss.NewStyle().
			Width(rect.W).Height(rect.H).
			Foreground(lipgloss.Color(c.TextMuted))
		return style.Render("  No files found")
	}

	// Ensure cursor is visible
	if ft.Cursor < ft.ScrollOff {
		ft.ScrollOff = ft.Cursor
	}
	if ft.Cursor >= ft.ScrollOff+rect.H {
		ft.ScrollOff = ft.Cursor - rect.H + 1
	}

	var lines []string
	for i := 0; i < rect.H; i++ {
		idx := ft.ScrollOff + i
		if idx >= len(ft.Entries) {
			lines = append(lines, strings.Repeat(" ", rect.W))
			continue
		}

		entry := ft.Entries[idx]
		indent := strings.Repeat("  ", entry.Depth)
		icon := "📄"
		if entry.IsDir {
			icon = "📁"
		}

		label := fmt.Sprintf("%s%s %s", indent, icon, entry.Name)

		// Truncate
		if len(label) > rect.W-1 {
			label = label[:rect.W-1]
		}

		// Pad
		pad := rect.W - lipgloss.Width(label)
		if pad < 0 {
			pad = 0
		}
		line := label + strings.Repeat(" ", pad)

		if idx == ft.Cursor {
			style := lipgloss.NewStyle().
				Background(lipgloss.Color(c.BorderActive)).
				Foreground(lipgloss.Color("#000000"))
			line = style.Render(line)
		} else if entry.IsDir {
			style := lipgloss.NewStyle().
				Foreground(lipgloss.Color(c.H2)).Bold(true)
			line = style.Render(line)
		}

		lines = append(lines, line)
	}

	content := strings.Join(lines, "\n")
	border := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder(), false, true, false, false).
		BorderForeground(lipgloss.Color(c.Border)).
		Width(rect.W).Height(rect.H)
	return border.Render(content)
}
