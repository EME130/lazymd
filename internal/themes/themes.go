package themes

import "strings"

// Color represents a terminal color as a hex string (e.g. "#8BE9FD").
// Empty string means default terminal color. Compatible with lipgloss.Color.
type Color = string

// ThemeColors defines all colors for a LazyMD theme.
type ThemeColors struct {
	// UI chrome
	TitleFg       Color
	TitleBg       Color
	StatusFg      Color
	StatusBg      Color
	Border        Color
	BorderActive  Color
	Gutter        Color
	GutterActive  Color

	// Markdown syntax
	H1, H2, H3, H4, H5, H6 Color
	Bold                     Color
	Italic                   Color
	Code                     Color
	CodeBg                   Color
	CodeBlockBg              Color
	Link                     Color
	LinkURL                  Color
	ListMarker               Color
	Blockquote               Color
	HR                       Color
	Strikethrough            Color
	Checkbox                 Color
	CheckboxDone             Color

	// Code highlighting
	SynKeyword     Color
	SynType        Color
	SynString      Color
	SynNumber      Color
	SynComment     Color
	SynBuiltin     Color
	SynOperator    Color
	SynPunctuation Color
	SynAnnotation  Color
	SynNormal      Color

	// Mode colors
	ModeNormalBg  Color
	ModeInsertBg  Color
	ModeCommandBg Color

	// General
	Text      Color
	TextMuted Color
	ErrColor  Color
	Success   Color
}

// ThemeDef defines a named theme.
type ThemeDef struct {
	Name        string
	Description string
	Colors      ThemeColors
}

// Default ANSI-approximate colors
var defaultColors = ThemeColors{
	TitleFg: "#FFFFFF", TitleBg: "#0000FF",
	StatusFg: "#FFFFFF", StatusBg: "#303030",
	Border: "#808080", BorderActive: "#00FFFF",
	Gutter: "#808080", GutterActive: "#FFFFFF",
	H1: "#00FFFF", H2: "#00FF00", H3: "#FFFF00", H4: "#5555FF", H5: "#FF00FF", H6: "#008B8B",
	Bold: "#FFFFFF", Italic: "#C0C0C0",
	Code: "#FFFF00", CodeBg: "#303030", CodeBlockBg: "#262626",
	Link: "#5555FF", LinkURL: "#0000FF",
	ListMarker: "#FF00FF", Blockquote: "#808080", HR: "#808080",
	Strikethrough: "#808080", Checkbox: "#FFFF00", CheckboxDone: "#00FF00",
	SynKeyword: "#FF00FF", SynType: "#00FFFF", SynString: "#00FF00",
	SynNumber: "#FFFF00", SynComment: "#808080", SynBuiltin: "#5555FF",
	SynOperator: "#FFFFFF", SynPunctuation: "#C0C0C0", SynAnnotation: "#FFFF00", SynNormal: "#C0C0C0",
	ModeNormalBg: "#0000FF", ModeInsertBg: "#008000", ModeCommandBg: "#800080",
	Text: "", TextMuted: "#808080", ErrColor: "#FF0000", Success: "#00FF00",
}

// BuiltinThemes contains all 12 built-in themes.
var BuiltinThemes = []ThemeDef{
	{Name: "default", Description: "Default LazyMD theme", Colors: defaultColors},
	{Name: "dracula", Description: "Dracula dark theme", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#44475A", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#8BE9FD", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#8BE9FD", H2: "#50FA7B", H3: "#F1FA8C", H4: "#BD93F9", H5: "#FF79C6", H6: "#FFB86C",
		Bold: "#F8F8F2", Italic: "#F8F8F2", Code: "#50FA7B", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#8BE9FD", LinkURL: "#6272A4", ListMarker: "#FF79C6", Blockquote: "#6272A4",
		HR: "#6272A4", Strikethrough: "#6272A4", Checkbox: "#F1FA8C", CheckboxDone: "#50FA7B",
		SynKeyword: "#FF79C6", SynType: "#8BE9FD", SynString: "#F1FA8C", SynNumber: "#BD93F9",
		SynComment: "#6272A4", SynBuiltin: "#50FA7B", SynOperator: "#FF79C6", SynPunctuation: "#F8F8F2",
		SynAnnotation: "#50FA7B", SynNormal: "#F8F8F2",
		ModeNormalBg: "#BD93F9", ModeInsertBg: "#50FA7B", ModeCommandBg: "#FF79C6",
		Text: "#F8F8F2", TextMuted: "#6272A4", ErrColor: "#FF5555", Success: "#50FA7B",
	}},
	{Name: "gruvbox", Description: "Gruvbox retro groove", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#3C3836", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#83A598", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#83A598", H2: "#B8BB26", H3: "#FABD2F", H4: "#83A598", H5: "#D3869B", H6: "#FE8019",
		Bold: "#EBDBB2", Italic: "#EBDBB2", Code: "#B8BB26", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#83A598", LinkURL: "#458588", ListMarker: "#FE8019", Blockquote: "#928374",
		HR: "#928374", Strikethrough: "#928374", Checkbox: "#FABD2F", CheckboxDone: "#B8BB26",
		SynKeyword: "#FB4934", SynType: "#FABD2F", SynString: "#B8BB26", SynNumber: "#D3869B",
		SynComment: "#928374", SynBuiltin: "#FE8019", SynOperator: "#EBDBB2", SynPunctuation: "#BDAE93",
		SynAnnotation: "#83A598", SynNormal: "#EBDBB2",
		ModeNormalBg: "#458588", ModeInsertBg: "#98971A", ModeCommandBg: "#B16286",
		Text: "#EBDBB2", TextMuted: "#928374", ErrColor: "#FB4934", Success: "#B8BB26",
	}},
	{Name: "nord", Description: "Arctic, north-bluish clean", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#3B4252", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#88C0D0", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#88C0D0", H2: "#A3BE8C", H3: "#EBCB8B", H4: "#81A1C1", H5: "#B48EAD", H6: "#D08770",
		Bold: "#ECEFF4", Italic: "#ECEFF4", Code: "#A3BE8C", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#88C0D0", LinkURL: "#5E81AC", ListMarker: "#D08770", Blockquote: "#4C566A",
		HR: "#4C566A", Strikethrough: "#4C566A", Checkbox: "#EBCB8B", CheckboxDone: "#A3BE8C",
		SynKeyword: "#81A1C1", SynType: "#88C0D0", SynString: "#A3BE8C", SynNumber: "#B48EAD",
		SynComment: "#4C566A", SynBuiltin: "#EBCB8B", SynOperator: "#ECEFF4", SynPunctuation: "#D8DEE9",
		SynAnnotation: "#D08770", SynNormal: "#D8DEE9",
		ModeNormalBg: "#5E81AC", ModeInsertBg: "#A3BE8C", ModeCommandBg: "#B48EAD",
		Text: "#D8DEE9", TextMuted: "#4C566A", ErrColor: "#BF616A", Success: "#A3BE8C",
	}},
	{Name: "solarized", Description: "Solarized dark precision colors", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#002B36", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#268BD2", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#268BD2", H2: "#859900", H3: "#B58900", H4: "#2AA198", H5: "#D33682", H6: "#CB4B16",
		Bold: "#EEE8D5", Italic: "#EEE8D5", Code: "#859900", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#268BD2", LinkURL: "#268BD2", ListMarker: "#6C71C4", Blockquote: "#586E75",
		HR: "#586E75", Strikethrough: "#586E75", Checkbox: "#B58900", CheckboxDone: "#859900",
		SynKeyword: "#859900", SynType: "#B58900", SynString: "#2AA198", SynNumber: "#D33682",
		SynComment: "#586E75", SynBuiltin: "#268BD2", SynOperator: "#839496", SynPunctuation: "#839496",
		SynAnnotation: "#CB4B16", SynNormal: "#839496",
		ModeNormalBg: "#268BD2", ModeInsertBg: "#859900", ModeCommandBg: "#D33682",
		Text: "#839496", TextMuted: "#586E75", ErrColor: "#DC322F", Success: "#859900",
	}},
	{Name: "monokai", Description: "Monokai classic dark", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#272822", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#66D9EF", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#66D9EF", H2: "#A6E22E", H3: "#E6DB74", H4: "#66D9EF", H5: "#F92672", H6: "#FD971F",
		Bold: "#F8F8F2", Italic: "#F8F8F2", Code: "#A6E22E", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#66D9EF", LinkURL: "#66D9EF", ListMarker: "#F92672", Blockquote: "#75715E",
		HR: "#75715E", Strikethrough: "#75715E", Checkbox: "#E6DB74", CheckboxDone: "#A6E22E",
		SynKeyword: "#F92672", SynType: "#66D9EF", SynString: "#E6DB74", SynNumber: "#AE81FF",
		SynComment: "#75715E", SynBuiltin: "#A6E22E", SynOperator: "#F92672", SynPunctuation: "#F8F8F2",
		SynAnnotation: "#A6E22E", SynNormal: "#F8F8F2",
		ModeNormalBg: "#66D9EF", ModeInsertBg: "#A6E22E", ModeCommandBg: "#F92672",
		Text: "#F8F8F2", TextMuted: "#75715E", ErrColor: "#F92672", Success: "#A6E22E",
	}},
	{Name: "catppuccin", Description: "Catppuccin mocha soothing pastels", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#1E1E2E", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#89B4FA", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#89B4FA", H2: "#A6E3A1", H3: "#F9E2AF", H4: "#74C7EC", H5: "#F5C2E7", H6: "#FAB387",
		Bold: "#CDD6F4", Italic: "#CDD6F4", Code: "#A6E3A1", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#89B4FA", LinkURL: "#89B4FA", ListMarker: "#F5C2E7", Blockquote: "#6C7086",
		HR: "#6C7086", Strikethrough: "#6C7086", Checkbox: "#F9E2AF", CheckboxDone: "#A6E3A1",
		SynKeyword: "#CBA6F7", SynType: "#F9E2AF", SynString: "#A6E3A1", SynNumber: "#FAB387",
		SynComment: "#6C7086", SynBuiltin: "#89B4FA", SynOperator: "#74C7EC", SynPunctuation: "#BAC2DE",
		SynAnnotation: "#F5C2E7", SynNormal: "#CDD6F4",
		ModeNormalBg: "#89B4FA", ModeInsertBg: "#A6E3A1", ModeCommandBg: "#CBA6F7",
		Text: "#CDD6F4", TextMuted: "#6C7086", ErrColor: "#F38BA8", Success: "#A6E3A1",
	}},
	{Name: "tokyo-night", Description: "Tokyo Night vibrant dark", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#1A1B26", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#7DCFFF", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#7DCFFF", H2: "#9ECE6A", H3: "#E0AF68", H4: "#7AA2F7", H5: "#BB9AF7", H6: "#FF9E64",
		Bold: "#C0CAF5", Italic: "#C0CAF5", Code: "#9ECE6A", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#7DCFFF", LinkURL: "#7AA2F7", ListMarker: "#FF9E64", Blockquote: "#565F89",
		HR: "#565F89", Strikethrough: "#565F89", Checkbox: "#E0AF68", CheckboxDone: "#9ECE6A",
		SynKeyword: "#BB9AF7", SynType: "#7DCFFF", SynString: "#9ECE6A", SynNumber: "#FF9E64",
		SynComment: "#565F89", SynBuiltin: "#7AA2F7", SynOperator: "#89DDFF", SynPunctuation: "#A9B1D6",
		SynAnnotation: "#E0AF68", SynNormal: "#C0CAF5",
		ModeNormalBg: "#7AA2F7", ModeInsertBg: "#9ECE6A", ModeCommandBg: "#BB9AF7",
		Text: "#C0CAF5", TextMuted: "#565F89", ErrColor: "#F7768E", Success: "#9ECE6A",
	}},
	{Name: "one-dark", Description: "Atom One Dark", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#282C34", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#61AFEF", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#61AFEF", H2: "#98C379", H3: "#E5C07B", H4: "#61AFEF", H5: "#C678DD", H6: "#D19A66",
		Bold: "#ABB2BF", Italic: "#ABB2BF", Code: "#98C379", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#61AFEF", LinkURL: "#61AFEF", ListMarker: "#C678DD", Blockquote: "#5C6370",
		HR: "#5C6370", Strikethrough: "#5C6370", Checkbox: "#E5C07B", CheckboxDone: "#98C379",
		SynKeyword: "#C678DD", SynType: "#E5C07B", SynString: "#98C379", SynNumber: "#D19A66",
		SynComment: "#5C6370", SynBuiltin: "#61AFEF", SynOperator: "#56B6C2", SynPunctuation: "#ABB2BF",
		SynAnnotation: "#E5C07B", SynNormal: "#ABB2BF",
		ModeNormalBg: "#61AFEF", ModeInsertBg: "#98C379", ModeCommandBg: "#C678DD",
		Text: "#ABB2BF", TextMuted: "#5C6370", ErrColor: "#E06C75", Success: "#98C379",
	}},
	{Name: "rose-pine", Description: "Rose Pine all natural", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#191724", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#9CCFD8", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#9CCFD8", H2: "#31748F", H3: "#F6C177", H4: "#9CCFD8", H5: "#C4A7E7", H6: "#EBBCBA",
		Bold: "#E0DEF4", Italic: "#E0DEF4", Code: "#F6C177", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#9CCFD8", LinkURL: "#9CCFD8", ListMarker: "#EB6F92", Blockquote: "#6E6A86",
		HR: "#6E6A86", Strikethrough: "#6E6A86", Checkbox: "#F6C177", CheckboxDone: "#9CCFD8",
		SynKeyword: "#31748F", SynType: "#F6C177", SynString: "#9CCFD8", SynNumber: "#C4A7E7",
		SynComment: "#6E6A86", SynBuiltin: "#EB6F92", SynOperator: "#E0DEF4", SynPunctuation: "#908CAA",
		SynAnnotation: "#F6C177", SynNormal: "#E0DEF4",
		ModeNormalBg: "#9CCFD8", ModeInsertBg: "#31748F", ModeCommandBg: "#C4A7E7",
		Text: "#E0DEF4", TextMuted: "#6E6A86", ErrColor: "#EB6F92", Success: "#9CCFD8",
	}},
	{Name: "kanagawa", Description: "Kanagawa wave inspired by Hokusai", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#16161D", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#7FB4CA", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#7FB4CA", H2: "#98BB6C", H3: "#E6A478", H4: "#7FB4CA", H5: "#957FB8", H6: "#FF5E63",
		Bold: "#DCD7BA", Italic: "#DCD7BA", Code: "#98BB6C", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#7FB4CA", LinkURL: "#7FB4CA", ListMarker: "#E46876", Blockquote: "#727169",
		HR: "#727169", Strikethrough: "#727169", Checkbox: "#E6A478", CheckboxDone: "#98BB6C",
		SynKeyword: "#957FB8", SynType: "#7FB4CA", SynString: "#98BB6C", SynNumber: "#FF5E63",
		SynComment: "#727169", SynBuiltin: "#E6A478", SynOperator: "#DCD7BA", SynPunctuation: "#9B9885",
		SynAnnotation: "#E46876", SynNormal: "#DCD7BA",
		ModeNormalBg: "#7FB4CA", ModeInsertBg: "#98BB6C", ModeCommandBg: "#957FB8",
		Text: "#DCD7BA", TextMuted: "#727169", ErrColor: "#E82424", Success: "#98BB6C",
	}},
	{Name: "everforest", Description: "Everforest comfortable green", Colors: ThemeColors{
		TitleFg: "#FFFFFF", TitleBg: "#27322B", StatusFg: "#FFFFFF", StatusBg: "#303030",
		Border: "#808080", BorderActive: "#83C092", Gutter: "#808080", GutterActive: "#FFFFFF",
		H1: "#83C092", H2: "#A7C080", H3: "#DBBC7F", H4: "#7FBBB3", H5: "#D699B6", H6: "#E67E80",
		Bold: "#D3C6AA", Italic: "#D3C6AA", Code: "#A7C080", CodeBg: "#303030", CodeBlockBg: "#262626",
		Link: "#83C092", LinkURL: "#83C092", ListMarker: "#E67E80", Blockquote: "#859289",
		HR: "#859289", Strikethrough: "#859289", Checkbox: "#DBBC7F", CheckboxDone: "#A7C080",
		SynKeyword: "#E67E80", SynType: "#DBBC7F", SynString: "#A7C080", SynNumber: "#D699B6",
		SynComment: "#859289", SynBuiltin: "#83C092", SynOperator: "#D3C6AA", SynPunctuation: "#9DA9A0",
		SynAnnotation: "#7FBBB3", SynNormal: "#D3C6AA",
		ModeNormalBg: "#83C092", ModeInsertBg: "#A7C080", ModeCommandBg: "#D699B6",
		Text: "#D3C6AA", TextMuted: "#859289", ErrColor: "#E67E80", Success: "#A7C080",
	}},
}

var currentIndex int

// Current returns the current theme.
func Current() *ThemeDef {
	return &BuiltinThemes[currentIndex]
}

// CurrentColors returns the current theme's colors.
func CurrentColors() *ThemeColors {
	return &BuiltinThemes[currentIndex].Colors
}

// Cycle advances to the next theme.
func Cycle() {
	currentIndex = (currentIndex + 1) % len(BuiltinThemes)
}

// SetByName sets the theme by name. Returns true if found.
func SetByName(name string) bool {
	idx, ok := FindByName(name)
	if ok {
		currentIndex = idx
	}
	return ok
}

// FindByName returns the index of a theme by name.
func FindByName(name string) (int, bool) {
	lower := strings.ToLower(name)
	for i, t := range BuiltinThemes {
		if strings.ToLower(t.Name) == lower {
			return i, true
		}
	}
	return 0, false
}

// Count returns the number of built-in themes.
func Count() int {
	return len(BuiltinThemes)
}

// SetIndex sets the theme by index.
func SetIndex(idx int) {
	if idx >= 0 && idx < len(BuiltinThemes) {
		currentIndex = idx
	}
}

// CurrentIndex returns the current theme index.
func CurrentIndex() int {
	return currentIndex
}

// SyntaxColor returns the color for a syntax token kind.
func (tc *ThemeColors) SyntaxColor(kind string) Color {
	switch kind {
	case "keyword":
		return tc.SynKeyword
	case "type_name":
		return tc.SynType
	case "string":
		return tc.SynString
	case "number":
		return tc.SynNumber
	case "comment":
		return tc.SynComment
	case "builtin":
		return tc.SynBuiltin
	case "operator":
		return tc.SynOperator
	case "punctuation":
		return tc.SynPunctuation
	case "annotation":
		return tc.SynAnnotation
	default:
		return tc.SynNormal
	}
}
