package nav

import (
	"errors"
	"fmt"
	"strings"

	"github.com/EME130/lazymd/internal/buffer"
)

var (
	ErrHeadingNotFound = errors.New("heading not found")
	ErrInvalidArgument = errors.New("invalid argument")
)

// BuiltinNavigator implements Navigator using a Buffer.
type BuiltinNavigator struct {
	buf *buffer.Buffer
}

// NewBuiltin creates a BuiltinNavigator for the given buffer.
func NewBuiltin(buf *buffer.Buffer) *BuiltinNavigator {
	return &BuiltinNavigator{buf: buf}
}

type headingMatch struct {
	line  int
	level int
	title string
}

func parseHeading(lineText string) *headingMatch {
	if len(lineText) == 0 || lineText[0] != '#' {
		return nil
	}
	level := 0
	for level < len(lineText) && lineText[level] == '#' {
		level++
	}
	if level > 6 || level >= len(lineText) || lineText[level] != ' ' {
		return nil
	}
	title := strings.TrimRight(lineText[level+1:], " \t\r")
	return &headingMatch{level: level, title: title}
}

// findSectionBounds returns (startLine, endLine) where endLine is exclusive.
func findSectionBounds(buf *buffer.Buffer, headingLine, headingLevel int) (int, int) {
	lineCount := buf.LineCount()
	end := lineCount
	for i := headingLine + 1; i < lineCount; i++ {
		if h := parseHeading(buf.Line(i)); h != nil {
			if h.level <= headingLevel {
				end = i
				break
			}
		}
	}
	return headingLine, end
}

// resolveHeadingPath resolves a slash-separated heading path.
func resolveHeadingPath(buf *buffer.Buffer, path string) *headingMatch {
	lineCount := buf.LineCount()

	var segments []string
	for _, seg := range strings.Split(path, "/") {
		trimmed := strings.TrimSpace(seg)
		if trimmed != "" {
			segments = append(segments, trimmed)
		}
	}
	if len(segments) == 0 {
		return nil
	}

	segIdx := 0
	searchStart := 0
	parentLevel := 0
	var lastMatch *headingMatch

	for segIdx < len(segments) {
		found := false
		for i := searchStart; i < lineCount; i++ {
			h := parseHeading(buf.Line(i))
			if h == nil {
				continue
			}
			if segIdx > 0 && h.level <= parentLevel {
				break
			}
			if strings.EqualFold(h.title, segments[segIdx]) {
				lastMatch = &headingMatch{line: i, level: h.level, title: h.title}
				parentLevel = h.level
				searchStart = i + 1
				segIdx++
				found = true
				break
			}
		}
		if !found {
			return nil
		}
	}
	return lastMatch
}

func buildBreadcrumb(buf *buffer.Buffer, targetLine int) string {
	var crumbs []string
	var levels []int
	lineCount := buf.LineCount()

	for i := 0; i < lineCount && i <= targetLine; i++ {
		h := parseHeading(buf.Line(i))
		if h == nil {
			continue
		}
		for len(crumbs) > 0 && levels[len(levels)-1] >= h.level {
			crumbs = crumbs[:len(crumbs)-1]
			levels = levels[:len(levels)-1]
		}
		crumbs = append(crumbs, h.title)
		levels = append(levels, h.level)
	}

	if len(crumbs) == 0 {
		return "(no heading)"
	}
	return strings.Join(crumbs, " > ")
}

func (n *BuiltinNavigator) ReadSection(headingPath string) (*SectionContent, error) {
	match := resolveHeadingPath(n.buf, headingPath)
	if match == nil {
		return nil, ErrHeadingNotFound
	}
	startLine, endLine := findSectionBounds(n.buf, match.line, match.level)

	var sb strings.Builder
	for i := startLine; i < endLine; i++ {
		sb.WriteString(n.buf.Line(i))
		if i+1 < endLine {
			sb.WriteByte('\n')
		}
	}

	contentStart := startLine + 1
	if contentStart > endLine {
		contentStart = endLine
	}

	return &SectionContent{
		HeadingLine: startLine,
		Level:       match.level,
		Title:       match.title,
		Content:     sb.String(),
		StartLine:   contentStart,
		EndLine:     endLine,
	}, nil
}

func (n *BuiltinNavigator) ListTasks(section *string, status TaskStatus) ([]TaskItem, error) {
	rangeStart := 0
	rangeEnd := n.buf.LineCount()

	if section != nil {
		match := resolveHeadingPath(n.buf, *section)
		if match == nil {
			return nil, ErrHeadingNotFound
		}
		rangeStart, rangeEnd = findSectionBounds(n.buf, match.line, match.level)
	}

	var tasks []TaskItem
	for i := rangeStart; i < rangeEnd; i++ {
		line := n.buf.Line(i)
		trimmed := strings.TrimLeft(line, " \t")

		if len(trimmed) < 6 ||
			(trimmed[0] != '-' && trimmed[0] != '*' && trimmed[0] != '+') ||
			trimmed[1] != ' ' || trimmed[2] != '[' {
			continue
		}

		checkChar := trimmed[3]
		isDone := checkChar == 'x' || checkChar == 'X'
		isPending := checkChar == ' '

		if (!isDone && !isPending) || trimmed[4] != ']' {
			continue
		}

		if status == TaskPending && isDone {
			continue
		}
		if status == TaskDone && !isDone {
			continue
		}

		textStart := 5
		if len(trimmed) > 5 && trimmed[5] == ' ' {
			textStart = 6
		}
		taskText := ""
		if textStart < len(trimmed) {
			taskText = trimmed[textStart:]
		}

		tasks = append(tasks, TaskItem{
			Line:       i,
			Done:       isDone,
			Text:       taskText,
			Breadcrumb: buildBreadcrumb(n.buf, i),
		})
	}
	return tasks, nil
}

func (n *BuiltinNavigator) UpdateTask(line int, done bool) (string, error) {
	if line >= n.buf.LineCount() {
		return "", ErrInvalidArgument
	}

	lineText := n.buf.Line(line)
	trimmed := strings.TrimLeft(lineText, " \t")
	indentLen := len(lineText) - len(trimmed)

	if len(trimmed) < 6 ||
		(trimmed[0] != '-' && trimmed[0] != '*' && trimmed[0] != '+') ||
		trimmed[1] != ' ' || trimmed[2] != '[' || trimmed[4] != ']' {
		return "", ErrInvalidArgument
	}

	checkChar := trimmed[3]
	if checkChar != ' ' && checkChar != 'x' && checkChar != 'X' {
		return "", ErrInvalidArgument
	}

	newCheck := ' '
	if done {
		newCheck = 'x'
	}
	newLine := fmt.Sprintf("%s%c [%c]%s\n", lineText[:indentLen], trimmed[0], newCheck, trimmed[5:])

	startOffset := n.buf.PosToOffset(line, 0)
	var endOffset int
	if line+1 < n.buf.LineCount() {
		endOffset = n.buf.PosToOffset(line+1, 0)
	} else {
		endOffset = n.buf.Length()
	}

	if endOffset > startOffset {
		n.buf.DeleteRange(startOffset, endOffset-startOffset)
	}
	n.buf.InsertString(startOffset, newLine)

	return strings.TrimRight(newLine, "\n"), nil
}

func (n *BuiltinNavigator) GetBreadcrumb(line int) (string, error) {
	if line >= n.buf.LineCount() {
		return "", ErrInvalidArgument
	}
	return buildBreadcrumb(n.buf, line), nil
}

func (n *BuiltinNavigator) MoveSection(heading, target string, before bool) (string, error) {
	lineCount := n.buf.LineCount()

	// Find source section
	var srcLine, srcLevel int
	srcFound := false
	for i := 0; i < lineCount; i++ {
		h := parseHeading(n.buf.Line(i))
		if h != nil && strings.EqualFold(h.title, heading) {
			srcLine = i
			srcLevel = h.level
			srcFound = true
			break
		}
	}
	if !srcFound {
		return "", ErrHeadingNotFound
	}
	_, srcEnd := findSectionBounds(n.buf, srcLine, srcLevel)

	// Find target section
	var tgtLine, tgtLevel int
	tgtFound := false
	for i := 0; i < lineCount; i++ {
		h := parseHeading(n.buf.Line(i))
		if h != nil && strings.EqualFold(h.title, target) {
			tgtLine = i
			tgtLevel = h.level
			tgtFound = true
			break
		}
	}
	if !tgtFound {
		return "", ErrHeadingNotFound
	}

	insertLine := tgtLine
	if !before {
		_, insertLine = findSectionBounds(n.buf, tgtLine, tgtLevel)
	}

	// Extract source section text
	var sb strings.Builder
	for i := srcLine; i < srcEnd; i++ {
		sb.WriteString(n.buf.Line(i))
		sb.WriteByte('\n')
	}
	extracted := sb.String()

	// Delete source, then insert at adjusted position
	srcStartOffset := n.buf.PosToOffset(srcLine, 0)
	var srcEndOffset int
	if srcEnd < n.buf.LineCount() {
		srcEndOffset = n.buf.PosToOffset(srcEnd, 0)
	} else {
		srcEndOffset = n.buf.Length()
	}
	srcByteLen := srcEndOffset - srcStartOffset
	srcLineCount := srcEnd - srcLine

	n.buf.DeleteRange(srcStartOffset, srcByteLen)

	adjInsertLine := insertLine
	if insertLine > srcLine {
		adjInsertLine = insertLine - srcLineCount
	}

	var insertOffset int
	if adjInsertLine < n.buf.LineCount() {
		insertOffset = n.buf.PosToOffset(adjInsertLine, 0)
	} else {
		insertOffset = n.buf.Length()
	}

	n.buf.InsertString(insertOffset, extracted)

	newEnd := adjInsertLine + srcLineCount
	return fmt.Sprintf("Moved '%s' to lines %d-%d", heading, adjInsertLine+1, newEnd), nil
}

func (n *BuiltinNavigator) ReadSectionRange(headingPath string, startOff, endOff *int) (string, error) {
	match := resolveHeadingPath(n.buf, headingPath)
	if match == nil {
		return "", ErrHeadingNotFound
	}
	sectionStart, sectionEnd := findSectionBounds(n.buf, match.line, match.level)

	sOff := 0
	if startOff != nil {
		sOff = *startOff
	}
	absStart := sectionStart + sOff
	if absStart > sectionEnd {
		absStart = sectionEnd
	}

	absEnd := sectionEnd
	if endOff != nil {
		absEnd = sectionStart + *endOff
		if absEnd > sectionEnd {
			absEnd = sectionEnd
		}
	}

	if absStart >= absEnd {
		return "(empty range)", nil
	}

	var sb strings.Builder
	for i := absStart; i < absEnd; i++ {
		fmt.Fprintf(&sb, "L%d: %s\n", i+1, n.buf.Line(i))
	}
	return sb.String(), nil
}
