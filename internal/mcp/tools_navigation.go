package mcp

import (
	"context"
	"fmt"
	"strings"

	mcplib "github.com/mark3labs/mcp-go/mcp"

	"github.com/EME130/lazymd/internal/nav"
)

func (s *LazyMDServer) registerNavigationTools() {
	// read_section
	s.server.AddTool(mcplib.NewTool("read_section",
		mcplib.WithDescription("Read a section by heading path. Navigate nested headings using '/' separator (e.g. 'Plan/Step 1/Subtask A'). Returns the heading line and all body content until the next same-or-higher-level heading."),
		mcplib.WithString("heading_path", mcplib.Required(), mcplib.Description("Slash-separated heading path (e.g. 'Plan/Step 1/Subtask A'). Case-insensitive.")),
	), s.toolReadSection)

	// list_tasks
	s.server.AddTool(mcplib.NewTool("list_tasks",
		mcplib.WithDescription("List all task checkboxes (- [ ] / - [x]) in the document. Optionally scope to a section and filter by completion status."),
		mcplib.WithString("section", mcplib.Description("Optional heading path to scope the search (e.g. 'Plan/Step 1'). Omit to search entire document.")),
		mcplib.WithString("status", mcplib.Description("Filter by task status: 'all', 'pending', or 'done'. Defaults to 'all'."), mcplib.Enum("all", "pending", "done")),
	), s.toolListTasks)

	// update_task
	s.server.AddTool(mcplib.NewTool("update_task",
		mcplib.WithDescription("Toggle or set a task checkbox at a specific line. Changes '- [ ]' to '- [x]' or vice versa."),
		mcplib.WithNumber("line", mcplib.Required(), mcplib.Description("Line number of the task checkbox (1-indexed)")),
		mcplib.WithBoolean("done", mcplib.Required(), mcplib.Description("Set to true to mark done [x], false to mark pending [ ]")),
	), s.toolUpdateTask)

	// get_breadcrumb
	s.server.AddTool(mcplib.NewTool("get_breadcrumb",
		mcplib.WithDescription("Get the heading hierarchy (breadcrumb) for a specific line."),
		mcplib.WithNumber("line", mcplib.Required(), mcplib.Description("Line number to get breadcrumb for (1-indexed)")),
	), s.toolGetBreadcrumb)

	// move_section
	s.server.AddTool(mcplib.NewTool("move_section",
		mcplib.WithDescription("Relocate a section to a new position relative to a target heading."),
		mcplib.WithString("heading", mcplib.Required(), mcplib.Description("Heading text of the section to move (case-insensitive, without # prefix)")),
		mcplib.WithString("after", mcplib.Description("Place the section after this heading's section. Mutually exclusive with 'before'.")),
		mcplib.WithString("before", mcplib.Description("Place the section before this heading. Mutually exclusive with 'after'.")),
	), s.toolMoveSection)

	// read_section_range
	s.server.AddTool(mcplib.NewTool("read_section_range",
		mcplib.WithDescription("Read lines from a section with line numbers. Like read_section but with optional offset/limit for precise editing context."),
		mcplib.WithString("heading_path", mcplib.Required(), mcplib.Description("Slash-separated heading path. Case-insensitive.")),
		mcplib.WithNumber("start_offset", mcplib.Description("Start offset within section (0 = heading line). Defaults to 0.")),
		mcplib.WithNumber("end_offset", mcplib.Description("End offset within section (exclusive). Defaults to end of section.")),
	), s.toolReadSectionRange)
}

func (s *LazyMDServer) toolReadSection(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	headingPath, err := req.RequireString("heading_path")
	if err != nil {
		return errResult("Missing 'heading_path' argument")
	}

	section, err := s.nav.ReadSection(headingPath)
	if err != nil {
		return errResult("Heading path '%s' not found", headingPath)
	}

	result := fmt.Sprintf("[L%d-L%d, h%d] %s\n\n%s", section.HeadingLine+1, section.EndLine, section.Level, section.Title, section.Content)
	return mcplib.NewToolResultText(result), nil
}

func (s *LazyMDServer) toolListTasks(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	sectionStr := getOptionalString(req, "section")
	statusStr := getOptionalString(req, "status")
	if statusStr == "" {
		statusStr = "all"
	}

	var status nav.TaskStatus
	switch strings.ToLower(statusStr) {
	case "pending":
		status = nav.TaskPending
	case "done":
		status = nav.TaskDone
	default:
		status = nav.TaskAll
	}

	var sectionPtr *string
	if sectionStr != "" {
		sectionPtr = &sectionStr
	}

	tasks, err := s.nav.ListTasks(sectionPtr, status)
	if err != nil {
		return errResult("Section not found")
	}

	if len(tasks) == 0 {
		return mcplib.NewToolResultText("No tasks found"), nil
	}

	var sb strings.Builder
	for i, t := range tasks {
		if i > 0 {
			sb.WriteByte('\n')
		}
		mark := ' '
		if t.Done {
			mark = 'x'
		}
		fmt.Fprintf(&sb, "L%d: [%c] %s (under: %s)", t.Line+1, mark, t.Text, t.Breadcrumb)
	}
	return mcplib.NewToolResultText(sb.String()), nil
}

func (s *LazyMDServer) toolUpdateTask(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	lineF, err := req.RequireFloat("line")
	if err != nil {
		return errResult("Missing 'line' argument")
	}
	lineNum := int(lineF)
	if lineNum < 1 {
		return errResult("Line must be >= 1")
	}

	done, ok := getOptionalBool(req, "done")
	if !ok {
		return errResult("Missing 'done' argument")
	}

	result, err := s.nav.UpdateTask(lineNum-1, done)
	if err != nil {
		return errResult("Line %d is not a task checkbox", lineNum)
	}
	return mcplib.NewToolResultText(result), nil
}

func (s *LazyMDServer) toolGetBreadcrumb(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	lineF, err := req.RequireFloat("line")
	if err != nil {
		return errResult("Missing 'line' argument")
	}
	lineNum := int(lineF)
	if lineNum < 1 {
		return errResult("Line must be >= 1")
	}

	result, err := s.nav.GetBreadcrumb(lineNum - 1)
	if err != nil {
		return errResult("Line %d out of range", lineNum)
	}
	return mcplib.NewToolResultText(result), nil
}

func (s *LazyMDServer) toolMoveSection(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	heading, err := req.RequireString("heading")
	if err != nil {
		return errResult("Missing 'heading' argument")
	}

	after := getOptionalString(req, "after")
	before := getOptionalString(req, "before")

	target := after
	isBefore := false
	if before != "" {
		target = before
		isBefore = true
	}
	if target == "" {
		return errResult("Must specify either 'after' or 'before' argument")
	}

	result, err := s.nav.MoveSection(heading, target, isBefore)
	if err != nil {
		return errResult("Heading not found")
	}
	return mcplib.NewToolResultText(result), nil
}

func (s *LazyMDServer) toolReadSectionRange(_ context.Context, req mcplib.CallToolRequest) (*mcplib.CallToolResult, error) {
	headingPath, err := req.RequireString("heading_path")
	if err != nil {
		return errResult("Missing 'heading_path' argument")
	}

	var startOff, endOff *int
	if v, ok := getOptionalInt(req, "start_offset"); ok {
		startOff = &v
	}
	if v, ok := getOptionalInt(req, "end_offset"); ok {
		endOff = &v
	}

	result, err := s.nav.ReadSectionRange(headingPath, startOff, endOff)
	if err != nil {
		return errResult("Heading path '%s' not found", headingPath)
	}
	return mcplib.NewToolResultText(result), nil
}
