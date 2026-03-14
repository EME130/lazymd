package markdown

import "strings"

// TokenType identifies the kind of markdown element a span represents.
type TokenType int

const (
	Normal TokenType = iota
	H1
	H2
	H3
	H4
	H5
	H6
	Bold
	Italic
	BoldItalic
	CodeInline
	CodeBlockMarker
	CodeBlock
	LinkText
	LinkURL
	ImageMarker
	ListBullet
	ListNumber
	Blockquote
	HR
	Strikethrough
	TaskCheckbox
	HTMLTag
	WikiLink
)

// Span represents a range of text with a token type.
type Span struct {
	Start int
	End   int
	Token TokenType
}

// LineContext tracks state across line tokenization.
type LineContext struct {
	InCodeBlock bool
}

// CodeFenceInfo is the result of parsing a code fence line.
type CodeFenceInfo struct {
	IsFence  bool
	Language string // empty if no language tag
}

// IsCodeFence returns true if the line is a code fence (``` or ~~~).
func IsCodeFence(line string) bool {
	trimmed := strings.TrimLeft(line, " ")
	if len(trimmed) < 3 {
		return false
	}
	return strings.HasPrefix(trimmed, "```") || strings.HasPrefix(trimmed, "~~~")
}

// ParseCodeFence parses a code fence line, extracting the language tag if present.
func ParseCodeFence(line string) CodeFenceInfo {
	trimmed := strings.TrimLeft(line, " ")
	if len(trimmed) < 3 {
		return CodeFenceInfo{}
	}

	var fenceChar byte
	if trimmed[0] == '`' && trimmed[1] == '`' && trimmed[2] == '`' {
		fenceChar = '`'
	} else if trimmed[0] == '~' && trimmed[1] == '~' && trimmed[2] == '~' {
		fenceChar = '~'
	} else {
		return CodeFenceInfo{}
	}

	i := 3
	for i < len(trimmed) && trimmed[i] == fenceChar {
		i++
	}
	for i < len(trimmed) && trimmed[i] == ' ' {
		i++
	}

	if i >= len(trimmed) {
		return CodeFenceInfo{IsFence: true}
	}

	langStart := i
	for i < len(trimmed) && trimmed[i] != ' ' && trimmed[i] != '\t' {
		i++
	}

	lang := trimmed[langStart:i]
	return CodeFenceInfo{IsFence: true, Language: lang}
}

// TokenizeLine tokenizes a single line of markdown, updating ctx for code block state.
func TokenizeLine(line string, ctx *LineContext) []Span {
	if IsCodeFence(line) {
		ctx.InCodeBlock = !ctx.InCodeBlock
		return []Span{{Start: 0, End: len(line), Token: CodeBlockMarker}}
	}

	if ctx.InCodeBlock {
		return []Span{{Start: 0, End: len(line), Token: CodeBlock}}
	}

	if len(line) == 0 {
		return nil
	}

	trimmed := strings.TrimLeft(line, " \t")

	if IsHorizontalRule(trimmed) {
		return []Span{{Start: 0, End: len(line), Token: HR}}
	}

	if level := parseHeader(trimmed); level > 0 {
		token := TokenType(int(H1) + level - 1) // H1..H6
		return []Span{{Start: 0, End: len(line), Token: token}}
	}

	if len(trimmed) > 0 && trimmed[0] == '>' {
		return []Span{{Start: 0, End: len(line), Token: Blockquote}}
	}

	if isListItem(trimmed) {
		indent := len(line) - len(trimmed)
		bulletEnd := indent + 2
		spans := []Span{{Start: 0, End: bulletEnd, Token: ListBullet}}
		if bulletEnd < len(line) {
			spans = append(spans, tokenizeInline(line, bulletEnd, len(line))...)
		}
		return spans
	}

	if isNumberedList(trimmed) {
		indent := len(line) - len(trimmed)
		numEnd := indent + numberedListPrefixLen(trimmed)
		spans := []Span{{Start: 0, End: numEnd, Token: ListNumber}}
		if numEnd < len(line) {
			spans = append(spans, tokenizeInline(line, numEnd, len(line))...)
		}
		return spans
	}

	return tokenizeInline(line, 0, len(line))
}

func tokenizeInline(line string, start, end int) []Span {
	var spans []Span
	i := start
	textStart := start

	for i < end {
		// Inline code
		if line[i] == '`' {
			if i > textStart {
				spans = append(spans, Span{Start: textStart, End: i, Token: Normal})
			}
			codeEnd := findInlineCode(line, i, end)
			spans = append(spans, Span{Start: i, End: codeEnd, Token: CodeInline})
			i = codeEnd
			textStart = i
			continue
		}

		// Bold + italic (*** or ___)
		if i+2 < end &&
			((line[i] == '*' && line[i+1] == '*' && line[i+2] == '*') ||
				(line[i] == '_' && line[i+1] == '_' && line[i+2] == '_')) {
			marker := string([]byte{line[i], line[i], line[i]})
			if close := findClosing(line, i+3, end, marker); close >= 0 {
				if i > textStart {
					spans = append(spans, Span{Start: textStart, End: i, Token: Normal})
				}
				spans = append(spans, Span{Start: i, End: close + 3, Token: BoldItalic})
				i = close + 3
				textStart = i
				continue
			}
		}

		// Bold (** or __)
		if i+1 < end &&
			((line[i] == '*' && line[i+1] == '*') ||
				(line[i] == '_' && line[i+1] == '_')) {
			marker := string([]byte{line[i], line[i]})
			if close := findClosing(line, i+2, end, marker); close >= 0 {
				if i > textStart {
					spans = append(spans, Span{Start: textStart, End: i, Token: Normal})
				}
				spans = append(spans, Span{Start: i, End: close + 2, Token: Bold})
				i = close + 2
				textStart = i
				continue
			}
		}

		// Italic (* or _)
		if line[i] == '*' || line[i] == '_' {
			marker := string([]byte{line[i]})
			if close := findClosing(line, i+1, end, marker); close >= 0 && close > i+1 {
				if i > textStart {
					spans = append(spans, Span{Start: textStart, End: i, Token: Normal})
				}
				spans = append(spans, Span{Start: i, End: close + 1, Token: Italic})
				i = close + 1
				textStart = i
				continue
			}
		}

		// Strikethrough (~~)
		if i+1 < end && line[i] == '~' && line[i+1] == '~' {
			if close := findClosing(line, i+2, end, "~~"); close >= 0 {
				if i > textStart {
					spans = append(spans, Span{Start: textStart, End: i, Token: Normal})
				}
				spans = append(spans, Span{Start: i, End: close + 2, Token: Strikethrough})
				i = close + 2
				textStart = i
				continue
			}
		}

		// Wiki-links [[target]] or [[target|display]]
		if i+1 < end && line[i] == '[' && line[i+1] == '[' {
			if wlEnd := findWikiLinkEnd(line, i+2, end); wlEnd >= 0 {
				if i > textStart {
					spans = append(spans, Span{Start: textStart, End: i, Token: Normal})
				}
				spans = append(spans, Span{Start: i, End: wlEnd, Token: WikiLink})
				i = wlEnd
				textStart = i
				continue
			}
		}

		// Links [text](url)
		if line[i] == '[' {
			if textEnd, urlEnd := parseLink(line, i, end); textEnd >= 0 {
				if i > textStart {
					spans = append(spans, Span{Start: textStart, End: i, Token: Normal})
				}
				spans = append(spans, Span{Start: i, End: textEnd, Token: LinkText})
				spans = append(spans, Span{Start: textEnd, End: urlEnd, Token: LinkURL})
				i = urlEnd
				textStart = i
				continue
			}
		}

		i++
	}

	if textStart < end {
		spans = append(spans, Span{Start: textStart, End: end, Token: Normal})
	}
	return spans
}

func parseHeader(line string) int {
	level := 0
	for _, c := range line {
		switch {
		case c == '#':
			level++
			if level > 6 {
				return 0
			}
		case c == ' ':
			if level >= 1 {
				return level
			}
			return 0
		default:
			return 0
		}
	}
	return 0
}

// IsHorizontalRule returns true if the line is a horizontal rule (---, ***, ___).
func IsHorizontalRule(line string) bool {
	if len(line) < 3 {
		return false
	}
	ch := line[0]
	if ch != '-' && ch != '*' && ch != '_' {
		return false
	}
	count := 0
	for _, c := range line {
		if byte(c) == ch {
			count++
		} else if c != ' ' {
			return false
		}
	}
	return count >= 3
}

func isListItem(line string) bool {
	if len(line) < 2 {
		return false
	}
	return (line[0] == '-' || line[0] == '*' || line[0] == '+') && line[1] == ' '
}

func isNumberedList(line string) bool {
	i := 0
	for i < len(line) && line[i] >= '0' && line[i] <= '9' {
		i++
	}
	if i == 0 || i >= len(line) {
		return false
	}
	return line[i] == '.' && i+1 < len(line) && line[i+1] == ' '
}

func numberedListPrefixLen(line string) int {
	i := 0
	for i < len(line) && line[i] >= '0' && line[i] <= '9' {
		i++
	}
	return i + 2 // digits + "." + " "
}

func findInlineCode(line string, start, end int) int {
	for i := start + 1; i < end; i++ {
		if line[i] == '`' {
			return i + 1
		}
	}
	return end
}

// findClosing returns the index where marker starts, or -1 if not found.
func findClosing(line string, start, end int, marker string) int {
	if start+len(marker) > end {
		return -1
	}
	for i := start; i+len(marker) <= end; i++ {
		if line[i:i+len(marker)] == marker {
			return i
		}
	}
	return -1
}

func findWikiLinkEnd(line string, start, end int) int {
	for i := start; i+1 < end; i++ {
		if line[i] == ']' && line[i+1] == ']' {
			return i + 2
		}
		if line[i] == '\n' {
			return -1
		}
	}
	return -1
}

// parseLink returns (textEnd, urlEnd) or (-1, -1) if not a valid link.
func parseLink(line string, start, end int) (int, int) {
	i := start + 1
	for i < end {
		if line[i] == ']' {
			break
		}
		i++
	}
	if i >= end {
		return -1, -1
	}
	bracketClose := i
	if bracketClose+1 >= end || line[bracketClose+1] != '(' {
		return -1, -1
	}
	i = bracketClose + 2
	for i < end {
		if line[i] == ')' {
			return bracketClose + 1, i + 1
		}
		i++
	}
	return -1, -1
}
