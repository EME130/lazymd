package brain

import "strings"

// Node represents a note in the knowledge graph.
type Node struct {
	ID       uint16
	Name     string   // filename stem ("daily-note")
	Path     string   // relative path ("notes/daily-note.md")
	OutLinks []uint16 // nodes this file links TO
	InLinks  []uint16 // nodes that link TO this file (backlinks)
}

// Edge represents a directed link between two nodes.
type Edge struct {
	From uint16
	To   uint16
}

// Graph is a knowledge graph of notes connected by wiki-links.
type Graph struct {
	Nodes    []Node
	Edges    []Edge
	nameToID map[string]uint16
}

// NewGraph creates an empty Graph.
func NewGraph() *Graph {
	return &Graph{
		nameToID: make(map[string]uint16),
	}
}

// AddNode adds a node to the graph and returns its ID.
func (g *Graph) AddNode(name, path string) uint16 {
	id := uint16(len(g.Nodes))
	g.Nodes = append(g.Nodes, Node{
		ID:   id,
		Name: name,
		Path: path,
	})
	g.nameToID[name] = id
	return id
}

// AddEdge adds a directed edge, deduplicating.
func (g *Graph) AddEdge(from, to uint16) {
	for _, e := range g.Edges {
		if e.From == from && e.To == to {
			return
		}
	}
	g.Edges = append(g.Edges, Edge{From: from, To: to})
}

// Resolve resolves a wiki-link text to a node ID.
// Handles path prefixes (notes/foo), aliases (foo|display), and case-insensitive matching.
func (g *Graph) Resolve(wikiLinkText string) (uint16, bool) {
	target := wikiLinkText
	if idx := strings.LastIndex(target, "/"); idx >= 0 {
		target = target[idx+1:]
	}
	if idx := strings.Index(target, "|"); idx >= 0 {
		target = target[:idx]
	}

	if id, ok := g.nameToID[target]; ok {
		return id, true
	}
	for _, node := range g.Nodes {
		if strings.EqualFold(node.Name, target) {
			return node.ID, true
		}
	}
	return 0, false
}

// BuildLinks populates InLinks and OutLinks arrays from the edge list.
func (g *Graph) BuildLinks() {
	n := len(g.Nodes)
	outCounts := make([]int, n)
	inCounts := make([]int, n)

	for _, e := range g.Edges {
		outCounts[e.From]++
		inCounts[e.To]++
	}

	for i := range g.Nodes {
		g.Nodes[i].OutLinks = make([]uint16, 0, outCounts[i])
		g.Nodes[i].InLinks = make([]uint16, 0, inCounts[i])
	}

	for _, e := range g.Edges {
		g.Nodes[e.From].OutLinks = append(g.Nodes[e.From].OutLinks, e.To)
		g.Nodes[e.To].InLinks = append(g.Nodes[e.To].InLinks, e.From)
	}
}

// GetBacklinks returns the IDs of nodes that link to the given node.
func (g *Graph) GetBacklinks(nodeID uint16) []uint16 {
	if int(nodeID) >= len(g.Nodes) {
		return nil
	}
	return g.Nodes[nodeID].InLinks
}

// GetOrphans returns IDs of nodes with zero links (both in and out).
func (g *Graph) GetOrphans() []uint16 {
	var orphans []uint16
	for _, node := range g.Nodes {
		if len(node.InLinks) == 0 && len(node.OutLinks) == 0 {
			orphans = append(orphans, node.ID)
		}
	}
	return orphans
}

// GetNeighbors returns all node IDs reachable within depth hops via BFS.
func (g *Graph) GetNeighbors(nodeID, depth uint16) []uint16 {
	if int(nodeID) >= len(g.Nodes) {
		return nil
	}

	visited := make([]bool, len(g.Nodes))
	type qItem struct {
		id uint16
		d  uint16
	}
	queue := []qItem{{id: nodeID, d: 0}}
	visited[nodeID] = true
	var result []uint16

	for len(queue) > 0 {
		item := queue[0]
		queue = queue[1:]
		result = append(result, item.id)

		if item.d >= depth {
			continue
		}

		node := g.Nodes[item.id]
		for _, next := range node.OutLinks {
			if !visited[next] {
				visited[next] = true
				queue = append(queue, qItem{id: next, d: item.d + 1})
			}
		}
		for _, next := range node.InLinks {
			if !visited[next] {
				visited[next] = true
				queue = append(queue, qItem{id: next, d: item.d + 1})
			}
		}
	}
	return result
}

// FindPath finds the shortest path between two nodes using BFS.
// Returns the path as a slice of node IDs, or nil if no path exists.
func (g *Graph) FindPath(fromID, toID uint16) ([]uint16, bool) {
	if fromID == toID {
		return []uint16{fromID}, true
	}

	n := len(g.Nodes)
	visited := make([]bool, n)
	parent := make([]int, n)
	for i := range parent {
		parent[i] = -1
	}

	visited[fromID] = true
	queue := []uint16{fromID}

	found := false
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]

		if cur == toID {
			found = true
			break
		}

		node := g.Nodes[cur]
		for _, next := range node.OutLinks {
			if !visited[next] {
				visited[next] = true
				parent[next] = int(cur)
				queue = append(queue, next)
			}
		}
		for _, next := range node.InLinks {
			if !visited[next] {
				visited[next] = true
				parent[next] = int(cur)
				queue = append(queue, next)
			}
		}
	}

	if !found {
		return nil, false
	}

	// Reconstruct path
	var path []uint16
	for cur := toID; cur != fromID; cur = uint16(parent[cur]) {
		path = append(path, cur)
	}
	path = append(path, fromID)

	// Reverse
	for i, j := 0, len(path)-1; i < j; i, j = i+1, j-1 {
		path[i], path[j] = path[j], path[i]
	}
	return path, true
}

// NodeCount returns the number of nodes.
func (g *Graph) NodeCount() int {
	return len(g.Nodes)
}

// EdgeCount returns the number of edges.
func (g *Graph) EdgeCount() int {
	return len(g.Edges)
}
