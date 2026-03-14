package highlight

import "strings"

// BuiltinHighlighter is a keyword-based syntax highlighter.
type BuiltinHighlighter struct{}

// NewBuiltin creates a new BuiltinHighlighter.
func NewBuiltin() *BuiltinHighlighter {
	return &BuiltinHighlighter{}
}

func (h *BuiltinHighlighter) Tokenize(line string, langName string, state *State) []Span {
	lang := FindLang(langName)
	if lang == nil {
		return nil
	}
	return highlightLine(line, lang, state)
}

func (h *BuiltinHighlighter) SupportsLanguage(langName string) bool {
	return FindLang(langName) != nil
}

func highlightLine(line string, lang *LangDef, state *State) []Span {
	if len(line) == 0 {
		return nil
	}

	var spans []Span
	i := 0

	// Continue block comment from previous line
	if state.InBlockComment {
		if lang.BlockCommentEnd != "" {
			if endPos := strings.Index(line, lang.BlockCommentEnd); endPos >= 0 {
				end := endPos + len(lang.BlockCommentEnd)
				spans = append(spans, Span{Start: 0, End: end, Kind: Comment})
				state.InBlockComment = false
				i = end
			} else {
				return []Span{{Start: 0, End: len(line), Kind: Comment}}
			}
		} else {
			return []Span{{Start: 0, End: len(line), Kind: Comment}}
		}
	}

	// Continue multiline string from previous line
	if state.InMultilineString {
		if endPos := findTripleQuoteEnd(line, 0); endPos >= 0 {
			spans = append(spans, Span{Start: 0, End: endPos, Kind: String})
			state.InMultilineString = false
			i = endPos
		} else {
			return []Span{{Start: 0, End: len(line), Kind: String}}
		}
	}

	for i < len(line) {
		// Whitespace
		if line[i] == ' ' || line[i] == '\t' {
			wsStart := i
			for i < len(line) && (line[i] == ' ' || line[i] == '\t') {
				i++
			}
			spans = append(spans, Span{Start: wsStart, End: i, Kind: Normal})
			continue
		}

		// Line comment
		if lang.LineComment != "" &&
			i+len(lang.LineComment) <= len(line) &&
			line[i:i+len(lang.LineComment)] == lang.LineComment {
			spans = append(spans, Span{Start: i, End: len(line), Kind: Comment})
			return spans
		}

		// Block comment start
		if lang.BlockCommentStart != "" &&
			i+len(lang.BlockCommentStart) <= len(line) &&
			line[i:i+len(lang.BlockCommentStart)] == lang.BlockCommentStart {
			if lang.BlockCommentEnd != "" {
				if endPos := findSubstring(line, i+len(lang.BlockCommentStart), lang.BlockCommentEnd); endPos >= 0 {
					end := endPos + len(lang.BlockCommentEnd)
					spans = append(spans, Span{Start: i, End: end, Kind: Comment})
					i = end
					continue
				}
			}
			spans = append(spans, Span{Start: i, End: len(line), Kind: Comment})
			state.InBlockComment = true
			return spans
		}

		// Triple-quote strings (Python)
		if lang.SupportsTripleQt &&
			i+3 <= len(line) &&
			(line[i:i+3] == `"""` || line[i:i+3] == `'''`) {
			if endPos := findTripleQuoteEnd(line, i+3); endPos >= 0 {
				spans = append(spans, Span{Start: i, End: endPos, Kind: String})
				i = endPos
				continue
			}
			spans = append(spans, Span{Start: i, End: len(line), Kind: String})
			state.InMultilineString = true
			return spans
		}

		// String delimiters
		if strings.ContainsRune(lang.StringDelimiters, rune(line[i])) {
			strEnd := scanString(line, i)
			spans = append(spans, Span{Start: i, End: strEnd, Kind: String})
			i = strEnd
			continue
		}

		// Numbers
		if isDigit(line[i]) || (line[i] == '.' && i+1 < len(line) && isDigit(line[i+1])) {
			numEnd := scanNumber(line, i)
			spans = append(spans, Span{Start: i, End: numEnd, Kind: Number})
			i = numEnd
			continue
		}

		// Annotation prefix
		if lang.AnnotationPrefix != 0 && line[i] == lang.AnnotationPrefix {
			if lang.AnnotationPrefix == '#' && i+1 < len(line) && line[i+1] == '[' {
				// Rust-style #[attr]
				attrEnd := scanUntilChar(line, i, ']')
				spans = append(spans, Span{Start: i, End: attrEnd, Kind: Annotation})
				i = attrEnd
				continue
			} else if lang.AnnotationPrefix == '@' {
				identEnd := scanIdentifier(line, i+1)
				if identEnd > i+1 {
					word := line[i:identEnd]
					if matchWord(lang.Builtins, word) {
						spans = append(spans, Span{Start: i, End: identEnd, Kind: Builtin})
					} else {
						spans = append(spans, Span{Start: i, End: identEnd, Kind: Annotation})
					}
					i = identEnd
					continue
				}
			}
		}

		// Identifiers
		if isIdentStart(line[i]) {
			identEnd := scanIdentifier(line, i)
			word := line[i:identEnd]

			// Rust macros (word!)
			effectiveEnd := identEnd
			if effectiveEnd < len(line) && line[effectiveEnd] == '!' && matchWord(lang.Builtins, line[i:effectiveEnd+1]) {
				effectiveEnd++
				spans = append(spans, Span{Start: i, End: effectiveEnd, Kind: Builtin})
				i = effectiveEnd
				continue
			}

			if matchWord(lang.Keywords, word) {
				spans = append(spans, Span{Start: i, End: identEnd, Kind: Keyword})
			} else if matchWord(lang.Types, word) {
				spans = append(spans, Span{Start: i, End: identEnd, Kind: TypeName})
			} else if matchWord(lang.Builtins, word) {
				spans = append(spans, Span{Start: i, End: identEnd, Kind: Builtin})
			} else {
				spans = append(spans, Span{Start: i, End: identEnd, Kind: Normal})
			}
			i = identEnd
			continue
		}

		// Operators
		if isOperator(line[i]) {
			spans = append(spans, Span{Start: i, End: i + 1, Kind: Operator})
			i++
			continue
		}

		// Punctuation
		if isPunctuation(line[i]) {
			spans = append(spans, Span{Start: i, End: i + 1, Kind: Punctuation})
			i++
			continue
		}

		// Everything else
		spans = append(spans, Span{Start: i, End: i + 1, Kind: Normal})
		i++
	}

	return spans
}

func findSubstring(line string, start int, needle string) int {
	if len(needle) == 0 {
		return -1
	}
	idx := strings.Index(line[start:], needle)
	if idx < 0 {
		return -1
	}
	return start + idx
}

func findTripleQuoteEnd(line string, start int) int {
	for i := start; i+3 <= len(line); i++ {
		if line[i:i+3] == `"""` || line[i:i+3] == `'''` {
			return i + 3
		}
	}
	return -1
}

func scanString(line string, start int) int {
	quote := line[start]
	for i := start + 1; i < len(line); i++ {
		if line[i] == '\\' {
			i++ // skip escaped char
			continue
		}
		if line[i] == quote {
			return i + 1
		}
	}
	return len(line)
}

func isDigit(ch byte) bool {
	return ch >= '0' && ch <= '9'
}

func scanNumber(line string, start int) int {
	i := start
	if i+1 < len(line) && line[i] == '0' {
		if line[i+1] == 'x' || line[i+1] == 'X' ||
			line[i+1] == 'b' || line[i+1] == 'B' ||
			line[i+1] == 'o' || line[i+1] == 'O' {
			i += 2
			for i < len(line) && (isHexDigit(line[i]) || line[i] == '_') {
				i++
			}
			return i
		}
	}
	for i < len(line) && (isDigit(line[i]) || line[i] == '_') {
		i++
	}
	if i < len(line) && line[i] == '.' {
		i++
		for i < len(line) && (isDigit(line[i]) || line[i] == '_') {
			i++
		}
	}
	if i < len(line) && (line[i] == 'e' || line[i] == 'E') {
		i++
		if i < len(line) && (line[i] == '+' || line[i] == '-') {
			i++
		}
		for i < len(line) && isDigit(line[i]) {
			i++
		}
	}
	return i
}

func isHexDigit(ch byte) bool {
	return isDigit(ch) || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F')
}

func isIdentStart(ch byte) bool {
	return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

func scanIdentifier(line string, start int) int {
	i := start
	for i < len(line) && (isIdentStart(line[i]) || isDigit(line[i]) || line[i] == '?') {
		i++
	}
	return i
}

func scanUntilChar(line string, start int, ch byte) int {
	for i := start; i < len(line); i++ {
		if line[i] == ch {
			return i + 1
		}
	}
	return len(line)
}

func matchWord(list []string, word string) bool {
	for _, entry := range list {
		if entry == word {
			return true
		}
	}
	return false
}

func isOperator(ch byte) bool {
	switch ch {
	case '=', '+', '-', '*', '/', '%', '!', '<', '>', '&', '|', '^', '~':
		return true
	}
	return false
}

func isPunctuation(ch byte) bool {
	switch ch {
	case '(', ')', '{', '}', '[', ']', ';', ',', '.', ':', '?':
		return true
	}
	return false
}
