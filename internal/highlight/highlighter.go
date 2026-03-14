package highlight

// TokenKind identifies the kind of code token.
type TokenKind int

const (
	Keyword     TokenKind = iota
	TypeName
	Builtin
	String
	Number
	Comment
	Operator
	Punctuation
	Annotation
	Normal
)

// Span represents a range of text with a token kind.
type Span struct {
	Start int
	End   int
	Kind  TokenKind
}

// State tracks highlighting state across lines.
type State struct {
	InBlockComment    bool
	InMultilineString bool
}

// Highlighter is the interface for syntax highlighting.
type Highlighter interface {
	Tokenize(line string, langName string, state *State) []Span
	SupportsLanguage(langName string) bool
}
