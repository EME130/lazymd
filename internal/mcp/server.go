package mcp

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	mcplib "github.com/mark3labs/mcp-go/mcp"
	mcpserver "github.com/mark3labs/mcp-go/server"

	"github.com/EME130/lazymd/internal/buffer"
	"github.com/EME130/lazymd/internal/nav"
)

// LazyMDServer is the MCP server for LazyMD.
type LazyMDServer struct {
	buf      *buffer.Buffer
	nav      *nav.BuiltinNavigator
	filePath string
	server   *mcpserver.MCPServer
}

// New creates a new LazyMDServer.
func New(buf *buffer.Buffer) *LazyMDServer {
	s := &LazyMDServer{
		buf: buf,
		nav: nav.NewBuiltin(buf),
	}

	s.server = mcpserver.NewMCPServer(
		"LazyMD",
		"0.1.0",
		mcpserver.WithToolCapabilities(false),
	)

	s.registerDocumentTools()
	s.registerNavigationTools()
	s.registerBrainTools()

	return s
}

// Run starts the MCP server over stdio.
func (s *LazyMDServer) Run() error {
	return mcpserver.ServeStdio(s.server)
}

// SetFilePath sets the current file path (for pre-loading).
func (s *LazyMDServer) SetFilePath(path string) {
	s.filePath = path
}

// fileStem returns the stem of the current file path.
func (s *LazyMDServer) fileStem() string {
	if s.filePath == "" {
		return ""
	}
	base := filepath.Base(s.filePath)
	ext := filepath.Ext(base)
	if ext != "" {
		return base[:len(base)-len(ext)]
	}
	return base
}

// containsIgnoreCase checks if haystack contains needle (case-insensitive).
func containsIgnoreCase(haystack, needle string) bool {
	return strings.Contains(strings.ToLower(haystack), strings.ToLower(needle))
}

// parseHeading extracts heading level and title from a line. Returns (level, title, ok).
func parseHeading(line string) (int, string, bool) {
	if len(line) == 0 || line[0] != '#' {
		return 0, "", false
	}
	level := 0
	for level < len(line) && line[level] == '#' {
		level++
	}
	if level > 6 || level >= len(line) || line[level] != ' ' {
		return 0, "", false
	}
	title := strings.TrimRight(line[level+1:], " \t\r")
	return level, title, true
}

// LoadFileIfNeeded loads a file into the buffer if a path was set at startup.
func (s *LazyMDServer) LoadFileIfNeeded() error {
	if s.filePath == "" {
		return nil
	}
	if _, err := os.Stat(s.filePath); err != nil {
		return nil // file doesn't exist yet, that's OK
	}
	return s.buf.LoadFile(s.filePath)
}

// getOptionalString gets an optional string argument from the request.
func getOptionalString(req mcplib.CallToolRequest, key string) string {
	args := req.GetArguments()
	if args == nil {
		return ""
	}
	v, ok := args[key]
	if !ok {
		return ""
	}
	s, ok := v.(string)
	if !ok {
		return ""
	}
	return s
}

// getOptionalInt gets an optional int argument from the request. Returns (value, ok).
func getOptionalInt(req mcplib.CallToolRequest, key string) (int, bool) {
	args := req.GetArguments()
	if args == nil {
		return 0, false
	}
	v, ok := args[key]
	if !ok {
		return 0, false
	}
	f, ok := v.(float64)
	if !ok {
		return 0, false
	}
	return int(f), true
}

// getOptionalBool gets an optional bool argument from the request. Returns (value, ok).
func getOptionalBool(req mcplib.CallToolRequest, key string) (bool, bool) {
	args := req.GetArguments()
	if args == nil {
		return false, false
	}
	v, ok := args[key]
	if !ok {
		return false, false
	}
	b, ok := v.(bool)
	if !ok {
		return false, false
	}
	return b, true
}

// errResult returns an MCP tool error result.
func errResult(msg string, args ...any) (*mcplib.CallToolResult, error) {
	return mcplib.NewToolResultError(fmt.Sprintf(msg, args...)), nil
}

// textResult returns an MCP tool text result.
func textResult(msg string, args ...any) (*mcplib.CallToolResult, error) {
	return mcplib.NewToolResultText(fmt.Sprintf(msg, args...)), nil
}
