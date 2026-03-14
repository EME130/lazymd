package mcp

import (
	"context"
	"fmt"
	"sort"
	"strings"

	mcplib "github.com/mark3labs/mcp-go/mcp"

	"github.com/EME130/lazymd/internal/brain"
)

func (s *LazyMDServer) registerBrainTools() {
	// list_links
	s.server.AddTool(mcplib.NewTool("list_links",
		mcplib.WithDescription("List all outgoing [[wiki-links]] from the current document."),
	), s.toolListLinks)

	// get_backlinks
	s.server.AddTool(mcplib.NewTool("get_backlinks",
		mcplib.WithDescription("Find all files in the vault that link TO a given note via [[wiki-links]]."),
		mcplib.WithString("note", mcplib.Description("Filename stem to find backlinks for (e.g. 'daily-note'). Defaults to current open file.")),
	), s.toolGetBacklinks)

	// get_graph
	s.server.AddTool(mcplib.NewTool("get_graph",
		mcplib.WithDescription("Return the vault's connection graph as JSON. Shows nodes, edges, and stats."),
		mcplib.WithString("node", mcplib.Description("Optional filename stem to center the graph on.")),
		mcplib.WithNumber("depth", mcplib.Description("How many hops from the center node to include. Defaults to 2.")),
	), s.toolGetGraph)

	// get_neighbors
	s.server.AddTool(mcplib.NewTool("get_neighbors",
		mcplib.WithDescription("Get all directly connected notes for a given note — both outgoing links and backlinks."),
		mcplib.WithString("note", mcplib.Description("Filename stem to find neighbors for. Defaults to current open file.")),
		mcplib.WithNumber("depth", mcplib.Description("How many hops to traverse. Defaults to 1.")),
	), s.toolGetNeighbors)

	// find_path
	s.server.AddTool(mcplib.NewTool("find_path",
		mcplib.WithDescription("Find the shortest path between two notes in the knowledge graph."),
		mcplib.WithString("from", mcplib.Required(), mcplib.Description("Filename stem of the starting note")),
		mcplib.WithString("to", mcplib.Required(), mcplib.Description("Filename stem of the target note")),
	), s.toolFindPath)

	// get_orphans
	s.server.AddTool(mcplib.NewTool("get_orphans",
		mcplib.WithDescription("List all orphan notes — files with zero incoming and zero outgoing [[wiki-links]]."),
	), s.toolGetOrphans)

	// get_hub_notes
	s.server.AddTool(mcplib.NewTool("get_hub_notes",
		mcplib.WithDescription("Find the most connected notes in the vault, ranked by total link count."),
		mcplib.WithNumber("limit", mcplib.Description("Maximum number of results to return. Defaults to 10.")),
	), s.toolGetHubNotes)
}

func (s *LazyMDServer) scanVault() (*brain.Graph, error) {
	return brain.Scan(".")
}

func (s *LazyMDServer) toolListLinks(_ context.Context, _ mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	content := s.buf.Content()
	links := brain.ExtractWikiLinks(content)

	if len(links) == 0 {
		return mcplib.NewToolResultText("No [[wiki-links]] found in current document"), nil
	}

	// Build JSON-like output with line numbers
	var sb strings.Builder
	sb.WriteByte('[')
	first := true
	lineNum := 1
	i := 0
	for i+3 < len(content) {
		if content[i] == '\n' {
			lineNum++
			i++
			continue
		}
		if content[i] == '[' && content[i+1] == '[' {
			start := i + 2
			if end := findWikiLinkEnd(content, start); end >= 0 {
				raw := content[start:end]
				target := raw
				if pipeIdx := strings.Index(raw, "|"); pipeIdx >= 0 {
					target = raw[:pipeIdx]
				}
				if len(target) > 0 {
					if !first {
						sb.WriteByte(',')
					}
					first = false
					fmt.Fprintf(&sb, `{"target":%q,"line":%d}`, target, lineNum)
				}
				i = end + 2
				continue
			}
		}
		i++
	}
	sb.WriteByte(']')

	return mcplib.NewToolResultText(sb.String()), nil
}

func findWikiLinkEnd(content string, start int) int {
	for i := start; i+1 < len(content); i++ {
		if content[i] == ']' && content[i+1] == ']' {
			return i
		}
		if content[i] == '\n' {
			return -1
		}
	}
	return -1
}

func (s *LazyMDServer) toolGetBacklinks(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	stem := getOptionalString(req, "note")
	if stem == "" {
		stem = s.fileStem()
	}
	if stem == "" {
		return errResult("No file open and no 'note' argument provided")
	}

	graph, err := s.scanVault()
	if err != nil {
		return errResult("Failed to scan vault")
	}

	nodeID, ok := graph.Resolve(stem)
	if !ok {
		return errResult("Note '%s' not found in vault", stem)
	}

	backlinks := graph.GetBacklinks(nodeID)
	if len(backlinks) == 0 {
		return textResult("No backlinks found for '%s'", stem)
	}

	var sb strings.Builder
	fmt.Fprintf(&sb, "Backlinks for '%s':\n", stem)
	for _, blID := range backlinks {
		node := graph.Nodes[blID]
		fmt.Fprintf(&sb, "  <- %s (%s)\n", node.Name, node.Path)
	}
	return mcplib.NewToolResultText(sb.String()), nil
}

func (s *LazyMDServer) toolGetGraph(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	graph, err := s.scanVault()
	if err != nil {
		return errResult("Failed to scan vault")
	}

	centerNode := getOptionalString(req, "node")
	depth := 2
	if d, ok := getOptionalInt(req, "depth"); ok && d > 0 && d <= 10 {
		depth = d
	}

	// Determine visible nodes
	var visibleSet map[uint16]bool
	if centerNode != "" {
		if nid, ok := graph.Resolve(centerNode); ok {
			neighbors := graph.GetNeighbors(nid, uint16(depth))
			visibleSet = make(map[uint16]bool, len(neighbors))
			for _, n := range neighbors {
				visibleSet[n] = true
			}
		}
	}

	var sb strings.Builder
	sb.WriteString(`{"nodes":[`)
	first := true
	for _, node := range graph.Nodes {
		if visibleSet != nil && !visibleSet[node.ID] {
			continue
		}
		if !first {
			sb.WriteByte(',')
		}
		first = false
		fmt.Fprintf(&sb, `{"id":%d,"name":%q,"path":%q,"out_links":%d,"in_links":%d}`,
			node.ID, node.Name, node.Path, len(node.OutLinks), len(node.InLinks))
	}
	sb.WriteString(`],"edges":[`)
	first = true
	for _, edge := range graph.Edges {
		if visibleSet != nil && (!visibleSet[edge.From] || !visibleSet[edge.To]) {
			continue
		}
		if !first {
			sb.WriteByte(',')
		}
		first = false
		fmt.Fprintf(&sb, `{"from":%d,"to":%d}`, edge.From, edge.To)
	}
	sb.WriteString(`],`)

	orphans := graph.GetOrphans()
	fmt.Fprintf(&sb, `"stats":{"total_notes":%d,"total_links":%d,"orphans":%d}}`,
		graph.NodeCount(), graph.EdgeCount(), len(orphans))

	return mcplib.NewToolResultText(sb.String()), nil
}

func (s *LazyMDServer) toolGetNeighbors(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	stem := getOptionalString(req, "note")
	if stem == "" {
		stem = s.fileStem()
	}
	if stem == "" {
		return errResult("No file open and no 'note' argument provided")
	}

	depth := uint16(1)
	if d, ok := getOptionalInt(req, "depth"); ok && d > 0 && d <= 10 {
		depth = uint16(d)
	}

	graph, err := s.scanVault()
	if err != nil {
		return errResult("Failed to scan vault")
	}

	nodeID, ok := graph.Resolve(stem)
	if !ok {
		return errResult("Note '%s' not found in vault", stem)
	}

	neighbors := graph.GetNeighbors(nodeID, depth)
	node := graph.Nodes[nodeID]

	var sb strings.Builder
	fmt.Fprintf(&sb, "Neighbors of '%s' (depth=%d):\n\n", node.Name, depth)

	sb.WriteString("Outgoing links:\n")
	if len(node.OutLinks) == 0 {
		sb.WriteString("  (none)\n")
	} else {
		for _, out := range node.OutLinks {
			t := graph.Nodes[out]
			fmt.Fprintf(&sb, "  -> %s (%s) [out:%d in:%d]\n", t.Name, t.Path, len(t.OutLinks), len(t.InLinks))
		}
	}

	sb.WriteString("\nBacklinks (incoming):\n")
	if len(node.InLinks) == 0 {
		sb.WriteString("  (none)\n")
	} else {
		for _, inID := range node.InLinks {
			src := graph.Nodes[inID]
			fmt.Fprintf(&sb, "  <- %s (%s) [out:%d in:%d]\n", src.Name, src.Path, len(src.OutLinks), len(src.InLinks))
		}
	}

	if depth > 1 {
		fmt.Fprintf(&sb, "\nAll reachable within %d hops: %d notes\n", depth, len(neighbors))
		for _, nid := range neighbors {
			if nid == nodeID {
				continue
			}
			n := graph.Nodes[nid]
			fmt.Fprintf(&sb, "  %s (%s)\n", n.Name, n.Path)
		}
	}

	return mcplib.NewToolResultText(sb.String()), nil
}

func (s *LazyMDServer) toolFindPath(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	fromStr, err := req.RequireString("from")
	if err != nil {
		return errResult("Missing 'from' argument")
	}
	toStr, err := req.RequireString("to")
	if err != nil {
		return errResult("Missing 'to' argument")
	}

	graph, err := s.scanVault()
	if err != nil {
		return errResult("Failed to scan vault")
	}

	fromID, ok := graph.Resolve(fromStr)
	if !ok {
		return errResult("Source note '%s' not found", fromStr)
	}
	toID, ok := graph.Resolve(toStr)
	if !ok {
		return errResult("Target note '%s' not found", toStr)
	}

	if fromID == toID {
		return textResult("'%s' and '%s' are the same note", fromStr, toStr)
	}

	path, found := graph.FindPath(fromID, toID)
	if !found {
		return textResult("No path exists between '%s' and '%s'", fromStr, toStr)
	}

	var sb strings.Builder
	fmt.Fprintf(&sb, "Path (%d hops):\n", len(path)-1)
	for i, nid := range path {
		if i > 0 {
			sb.WriteString(" -> ")
		}
		sb.WriteString(graph.Nodes[nid].Name)
	}
	sb.WriteByte('\n')

	return mcplib.NewToolResultText(sb.String()), nil
}

func (s *LazyMDServer) toolGetOrphans(_ context.Context, _ mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	graph, err := s.scanVault()
	if err != nil {
		return errResult("Failed to scan vault")
	}

	orphans := graph.GetOrphans()
	if len(orphans) == 0 {
		return textResult("No orphan notes found. All %d notes are connected.", graph.NodeCount())
	}

	var sb strings.Builder
	fmt.Fprintf(&sb, "Orphan notes (%d/%d notes have no links):\n\n", len(orphans), graph.NodeCount())
	for _, oid := range orphans {
		node := graph.Nodes[oid]
		fmt.Fprintf(&sb, "  %s (%s)\n", node.Name, node.Path)
	}

	return mcplib.NewToolResultText(sb.String()), nil
}

func (s *LazyMDServer) toolGetHubNotes(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	limit := 10
	if l, ok := getOptionalInt(req, "limit"); ok && l > 0 && l <= 100 {
		limit = l
	}

	graph, err := s.scanVault()
	if err != nil {
		return errResult("Failed to scan vault")
	}

	if graph.NodeCount() == 0 {
		return mcplib.NewToolResultText("No notes found in vault"), nil
	}

	type entry struct {
		id    uint16
		total int
	}
	entries := make([]entry, len(graph.Nodes))
	for i, node := range graph.Nodes {
		entries[i] = entry{id: uint16(i), total: len(node.OutLinks) + len(node.InLinks)}
	}
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].total > entries[j].total
	})

	shown := limit
	if shown > len(entries) {
		shown = len(entries)
	}

	var sb strings.Builder
	fmt.Fprintf(&sb, "Top %d most connected notes:\n\n", shown)
	for rank, e := range entries[:shown] {
		node := graph.Nodes[e.id]
		fmt.Fprintf(&sb, "  %d. %s — %d links (out:%d in:%d) — %s\n",
			rank+1, node.Name, e.total, len(node.OutLinks), len(node.InLinks), node.Path)
	}

	return mcplib.NewToolResultText(sb.String()), nil
}
