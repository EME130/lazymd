package brain

import (
	"os"
	"path/filepath"
	"strings"
)

const maxFileSize = 64 * 1024

// Scan recursively scans a vault directory for .md/.rndm files,
// extracts [[wiki-links]], and builds a Graph.
func Scan(rootPath string) (*Graph, error) {
	graph := NewGraph()

	// Phase 1: Collect all markdown files and create nodes
	var filePaths []string
	err := filepath.WalkDir(rootPath, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil // skip errors
		}
		if d.IsDir() {
			if strings.HasPrefix(d.Name(), ".") {
				return filepath.SkipDir
			}
			return nil
		}
		if !isMarkdown(d.Name()) {
			return nil
		}
		rel, err := filepath.Rel(rootPath, path)
		if err != nil {
			return nil
		}
		filePaths = append(filePaths, rel)
		return nil
	})
	if err != nil {
		return nil, err
	}

	for _, relPath := range filePaths {
		stem := extractStem(relPath)
		graph.AddNode(stem, relPath)
	}

	// Phase 2: Read each file, extract links, create edges
	for nodeIdx, relPath := range filePaths {
		content, err := readFileContent(rootPath, relPath)
		if err != nil {
			continue
		}

		links := ExtractWikiLinks(content)
		for _, linkTarget := range links {
			if targetID, ok := graph.Resolve(linkTarget); ok {
				graph.AddEdge(uint16(nodeIdx), targetID)
			}
		}
	}

	// Phase 3: Build backlink/outlink arrays
	graph.BuildLinks()

	return graph, nil
}

// ExtractWikiLinks extracts all [[wiki-link]] targets from content.
func ExtractWikiLinks(content string) []string {
	var links []string
	i := 0
	for i+3 < len(content) {
		if content[i] == '[' && content[i+1] == '[' {
			start := i + 2
			if end := findLinkEnd(content, start); end >= 0 {
				raw := content[start:end]
				target := raw
				if pipeIdx := strings.Index(raw, "|"); pipeIdx >= 0 {
					target = raw[:pipeIdx]
				}
				if len(target) > 0 {
					links = append(links, target)
				}
				i = end + 1
				continue
			}
		}
		i++
	}
	return links
}

func readFileContent(root, relPath string) (string, error) {
	fullPath := filepath.Join(root, relPath)
	info, err := os.Stat(fullPath)
	if err != nil {
		return "", err
	}
	if info.Size() > maxFileSize {
		return "", nil
	}
	data, err := os.ReadFile(fullPath)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func findLinkEnd(content string, start int) int {
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

func extractStem(path string) string {
	base := filepath.Base(path)
	ext := filepath.Ext(base)
	if ext != "" {
		base = base[:len(base)-len(ext)]
	}
	return base
}

func isMarkdown(name string) bool {
	return strings.HasSuffix(name, ".md") || strings.HasSuffix(name, ".rndm")
}
