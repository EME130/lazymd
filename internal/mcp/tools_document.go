package mcp

import (
	"context"
	"fmt"
	"strings"

	mcplib "github.com/mark3labs/mcp-go/mcp"
)

func (s *LazyMDServer) registerDocumentTools() {
	// open_file
	s.server.AddTool(mcplib.NewTool("open_file",
		mcplib.WithDescription("Open a markdown (.md) or rndm (.rndm) file for editing. The file becomes the active document for all subsequent operations."),
		mcplib.WithString("path", mcplib.Required(), mcplib.Description("Path to the markdown file to open")),
	), s.toolOpenFile)

	// read_document
	s.server.AddTool(mcplib.NewTool("read_document",
		mcplib.WithDescription("Read the full content of the currently open document. Returns the raw markdown text."),
	), s.toolReadDocument)

	// write_document
	s.server.AddTool(mcplib.NewTool("write_document",
		mcplib.WithDescription("Save the current document to disk. Optionally specify a different path to save-as."),
		mcplib.WithString("path", mcplib.Description("File path to save to (defaults to the current file path)")),
	), s.toolWriteDocument)

	// list_headings
	s.server.AddTool(mcplib.NewTool("list_headings",
		mcplib.WithDescription("List all markdown headings (H1-H6) in the current document with their line numbers and levels."),
	), s.toolListHeadings)

	// edit_section
	s.server.AddTool(mcplib.NewTool("edit_section",
		mcplib.WithDescription("Replace the content of a markdown section (identified by heading). The heading line is preserved; only the body content between this heading and the next heading of equal or higher level is replaced."),
		mcplib.WithString("heading", mcplib.Required(), mcplib.Description("The heading text to find (case-insensitive, without # prefix)")),
		mcplib.WithString("content", mcplib.Required(), mcplib.Description("New content for the section body")),
	), s.toolEditSection)

	// insert_text
	s.server.AddTool(mcplib.NewTool("insert_text",
		mcplib.WithDescription("Insert text at a specific line number or at the end of the document."),
		mcplib.WithString("text", mcplib.Required(), mcplib.Description("Text to insert")),
		mcplib.WithNumber("line", mcplib.Description("Line number to insert before (1-indexed). Omit to append at end.")),
	), s.toolInsertText)

	// delete_lines
	s.server.AddTool(mcplib.NewTool("delete_lines",
		mcplib.WithDescription("Delete one or more lines from the document."),
		mcplib.WithNumber("start_line", mcplib.Required(), mcplib.Description("First line to delete (1-indexed)")),
		mcplib.WithNumber("end_line", mcplib.Description("Last line to delete (1-indexed, inclusive). Defaults to start_line.")),
	), s.toolDeleteLines)

	// search_content
	s.server.AddTool(mcplib.NewTool("search_content",
		mcplib.WithDescription("Search the document for lines matching a query (case-insensitive substring match). Returns matching lines with line numbers."),
		mcplib.WithString("query", mcplib.Required(), mcplib.Description("Search query string")),
	), s.toolSearchContent)

	// get_structure
	s.server.AddTool(mcplib.NewTool("get_structure",
		mcplib.WithDescription("Get document metadata and structural overview including line count, byte size, file path, modification status, and a hierarchical outline of all headings."),
	), s.toolGetStructure)
}

func (s *LazyMDServer) toolOpenFile(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	path, err := req.RequireString("path")
	if err != nil {
		return errResult("Missing 'path' argument")
	}

	if err := s.buf.LoadFile(path); err != nil {
		return errResult("Failed to open file: %v", err)
	}
	s.filePath = path

	return textResult("Opened %s (%d lines, %d bytes)", path, s.buf.LineCount(), s.buf.Length())
}

func (s *LazyMDServer) toolReadDocument(_ context.Context, _ mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	return mcplib.NewToolResultText(s.buf.Content()), nil
}

func (s *LazyMDServer) toolWriteDocument(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	path := getOptionalString(req, "path")
	if path == "" {
		path = s.filePath
	}
	if path == "" {
		return errResult("No file path specified and no file currently open")
	}

	if err := s.buf.SaveFile(path); err != nil {
		return errResult("Failed to save: %v", err)
	}
	if s.filePath != path {
		s.filePath = path
	}

	return textResult("Saved to %s (%d bytes)", path, s.buf.Length())
}

func (s *LazyMDServer) toolListHeadings(_ context.Context, _ mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	var sb strings.Builder
	lineCount := s.buf.LineCount()
	found := 0

	for i := 0; i < lineCount; i++ {
		line := s.buf.Line(i)
		if level, title, ok := parseHeading(line); ok {
			if found > 0 {
				sb.WriteByte('\n')
			}
			fmt.Fprintf(&sb, "L%d: %s %s", i+1, line[:level], title)
			found++
		}
	}

	if found == 0 {
		return mcplib.NewToolResultText("No headings found"), nil
	}
	return mcplib.NewToolResultText(sb.String()), nil
}

func (s *LazyMDServer) toolEditSection(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	heading, err := req.RequireString("heading")
	if err != nil {
		return errResult("Missing 'heading' argument")
	}
	content, err := req.RequireString("content")
	if err != nil {
		return errResult("Missing 'content' argument")
	}

	lineCount := s.buf.LineCount()

	// Find the heading
	sectionStart := -1
	sectionLevel := 0
	for i := 0; i < lineCount; i++ {
		if level, title, ok := parseHeading(s.buf.Line(i)); ok {
			if strings.EqualFold(title, heading) {
				sectionStart = i
				sectionLevel = level
				break
			}
		}
	}

	if sectionStart < 0 {
		return errResult("Heading '%s' not found", heading)
	}

	// Find section end
	sectionEnd := lineCount
	for i := sectionStart + 1; i < lineCount; i++ {
		if level, _, ok := parseHeading(s.buf.Line(i)); ok {
			if level <= sectionLevel {
				sectionEnd = i
				break
			}
		}
	}

	// Calculate byte range (content AFTER heading line)
	contentStartLine := sectionStart + 1
	startOffset := s.buf.PosToOffset(contentStartLine, 0)
	if contentStartLine >= lineCount {
		startOffset = s.buf.Length()
	}
	endOffset := s.buf.Length()
	if sectionEnd < lineCount {
		endOffset = s.buf.PosToOffset(sectionEnd, 0)
	}

	// Delete old content
	if endOffset > startOffset {
		s.buf.DeleteRange(startOffset, endOffset-startOffset)
	}

	// Insert new content (ensure trailing newline)
	newContent := content
	if len(newContent) > 0 && newContent[len(newContent)-1] != '\n' {
		newContent += "\n"
	}
	s.buf.InsertString(startOffset, newContent)

	return textResult("Updated section '%s' (%d bytes)", heading, len(newContent))
}

func (s *LazyMDServer) toolInsertText(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	text, err := req.RequireString("text")
	if err != nil {
		return errResult("Missing 'text' argument")
	}

	lineNum, hasLine := getOptionalInt(req, "line")
	var offset int
	if hasLine && lineNum > 0 {
		line := lineNum - 1
		if line > s.buf.LineCount() {
			line = s.buf.LineCount()
		}
		offset = s.buf.PosToOffset(line, 0)
	} else {
		offset = s.buf.Length()
	}

	s.buf.InsertString(offset, text)

	return textResult("Inserted %d bytes at offset %d", len(text), offset)
}

func (s *LazyMDServer) toolDeleteLines(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	startLineF, err := req.RequireFloat("start_line")
	if err != nil {
		return errResult("Missing 'start_line' argument")
	}
	startLine := int(startLineF)
	if startLine < 1 {
		return errResult("start_line must be >= 1")
	}

	endLine := startLine
	if el, ok := getOptionalInt(req, "end_line"); ok {
		endLine = el
	}

	lineCount := s.buf.LineCount()
	start := startLine - 1
	end := endLine
	if end > lineCount {
		end = lineCount
	}

	if start >= lineCount {
		return errResult("Line %d out of range (document has %d lines)", startLine, lineCount)
	}

	startOffset := s.buf.PosToOffset(start, 0)
	var endOffset int
	if end < lineCount {
		endOffset = s.buf.PosToOffset(end, 0)
	} else {
		endOffset = s.buf.Length()
	}

	if endOffset > startOffset {
		s.buf.DeleteRange(startOffset, endOffset-startOffset)
	}

	return textResult("Deleted lines %d-%d", startLine, endLine)
}

func (s *LazyMDServer) toolSearchContent(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	query, err := req.RequireString("query")
	if err != nil {
		return errResult("Missing 'query' argument")
	}

	var sb strings.Builder
	lineCount := s.buf.LineCount()
	found := 0

	for i := 0; i < lineCount; i++ {
		line := s.buf.Line(i)
		if containsIgnoreCase(line, query) {
			if found > 0 {
				sb.WriteByte('\n')
			}
			fmt.Fprintf(&sb, "L%d: %s", i+1, line)
			found++
			if found >= 50 {
				sb.WriteString("\n... (truncated, 50+ matches)")
				break
			}
		}
	}

	if found == 0 {
		return textResult("No matches for '%s'", query)
	}
	return mcplib.NewToolResultText(sb.String()), nil
}

func (s *LazyMDServer) toolGetStructure(_ context.Context, _ mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	var sb strings.Builder

	fmt.Fprintf(&sb, "Lines: %d\nBytes: %d\n", s.buf.LineCount(), s.buf.Length())
	if s.filePath != "" {
		fmt.Fprintf(&sb, "File: %s\n", s.filePath)
	}
	fmt.Fprintf(&sb, "Modified: %v\n\nOutline:\n", s.buf.IsDirty())

	lineCount := s.buf.LineCount()
	headings := 0
	for i := 0; i < lineCount; i++ {
		if level, title, ok := parseHeading(s.buf.Line(i)); ok {
			indent := strings.Repeat("  ", level-1)
			fmt.Fprintf(&sb, "%s- %s (L%d)\n", indent, title, i+1)
			headings++
		}
	}

	if headings == 0 {
		sb.WriteString("  (no headings)\n")
	}

	return mcplib.NewToolResultText(sb.String()), nil
}
