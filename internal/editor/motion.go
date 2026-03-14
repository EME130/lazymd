package editor

// moveCursorUp moves the cursor up one line.
func (e *EditorModel) moveCursorUp() {
	if e.Row > 0 {
		e.Row--
		lineLen := e.Buf.LineLen(e.Row)
		if e.DesiredCol < lineLen {
			e.Col = e.DesiredCol
		} else {
			e.Col = lineLen
		}
	}
}

// moveCursorDown moves the cursor down one line.
func (e *EditorModel) moveCursorDown() {
	if e.Row+1 < e.Buf.LineCount() {
		e.Row++
		lineLen := e.Buf.LineLen(e.Row)
		if e.DesiredCol < lineLen {
			e.Col = e.DesiredCol
		} else {
			e.Col = lineLen
		}
	}
}

// moveCursorLeft moves the cursor left one column.
func (e *EditorModel) moveCursorLeft() {
	if e.Col > 0 {
		e.Col--
		e.DesiredCol = e.Col
	}
}

// moveCursorRight moves the cursor right one column.
func (e *EditorModel) moveCursorRight() {
	lineLen := e.Buf.LineLen(e.Row)
	var maxCol int
	if e.mode == ModeInsert {
		maxCol = lineLen
	} else if lineLen > 0 {
		maxCol = lineLen - 1
	}
	if e.Col < maxCol {
		e.Col++
		e.DesiredCol = e.Col
	}
}

// cursorToLineEnd moves cursor to end of current line.
func (e *EditorModel) cursorToLineEnd() {
	lineLen := e.Buf.LineLen(e.Row)
	if lineLen > 0 && e.mode == ModeNormal {
		e.Col = lineLen - 1
	} else {
		e.Col = lineLen
	}
	e.DesiredCol = 1<<31 - 1 // maxInt-ish
}

// cursorToFirstNonBlank moves cursor to first non-blank character.
func (e *EditorModel) cursorToFirstNonBlank() {
	line := e.Buf.Line(e.Row)
	col := 0
	for col < len(line) && (line[col] == ' ' || line[col] == '\t') {
		col++
	}
	e.Col = col
	e.DesiredCol = col
}

// wordForward moves cursor to start of next word.
func (e *EditorModel) wordForward() {
	line := e.Buf.Line(e.Row)
	col := e.Col
	// Skip current word
	for col < len(line) && !isWordSep(line[col]) {
		col++
	}
	// Skip separators
	for col < len(line) && isWordSep(line[col]) {
		col++
	}
	if col >= len(line) && e.Row+1 < e.Buf.LineCount() {
		e.Row++
		e.Col = 0
		e.cursorToFirstNonBlank()
	} else {
		e.Col = col
	}
	e.DesiredCol = e.Col
}

// wordBackward moves cursor to start of previous word.
func (e *EditorModel) wordBackward() {
	line := e.Buf.Line(e.Row)
	col := e.Col
	if col == 0 {
		if e.Row > 0 {
			e.Row--
			e.cursorToLineEnd()
		}
		return
	}
	col--
	// Skip separators
	for col > 0 && isWordSep(line[col]) {
		col--
	}
	// Skip word
	for col > 0 && !isWordSep(line[col-1]) {
		col--
	}
	e.Col = col
	e.DesiredCol = col
}

// wordEnd moves cursor to end of current/next word.
func (e *EditorModel) wordEnd() {
	line := e.Buf.Line(e.Row)
	col := e.Col + 1
	// Skip separators
	for col < len(line) && isWordSep(line[col]) {
		col++
	}
	// Skip word
	for col < len(line) && !isWordSep(line[col]) {
		col++
	}
	if col > 0 {
		e.Col = col - 1
	} else {
		e.Col = 0
	}
	e.DesiredCol = e.Col
}

func isWordSep(c byte) bool {
	switch c {
	case ' ', '\t', '\n', '.', ',', ';', ':', '(', ')', '[', ']', '{', '}':
		return true
	}
	return false
}

// clampCursor ensures cursor is within valid bounds.
func (e *EditorModel) clampCursor() {
	lineLen := e.Buf.LineLen(e.Row)
	if e.mode == ModeNormal && lineLen > 0 {
		if e.Col >= lineLen {
			e.Col = lineLen - 1
		}
	} else {
		if e.Col > lineLen {
			e.Col = lineLen
		}
	}
}

// deleteLine deletes the current line.
func (e *EditorModel) deleteLine() {
	lineCount := e.Buf.LineCount()
	if lineCount == 0 {
		return
	}

	start := e.Buf.PosToOffset(e.Row, 0)
	var end int
	if e.Row+1 < lineCount {
		end = e.Buf.PosToOffset(e.Row+1, 0)
	} else {
		end = e.Buf.Length()
		// Include preceding newline if not first line
		if e.Row > 0 && start > 0 {
			e.Buf.DeleteRange(start-1, end-start+1)
			e.Row--
			e.clampCursor()
			e.MarkChanged()
			return
		}
	}

	if end > start {
		e.Buf.DeleteRange(start, end-start)
	}
	if e.Row >= e.Buf.LineCount() && e.Row > 0 {
		e.Row--
	}
	e.clampCursor()
	e.MarkChanged()
}

// UpdateScroll adjusts scroll position to keep cursor visible.
func (e *EditorModel) UpdateScroll() {
	if e.Row < e.ScrollRow {
		e.ScrollRow = e.Row
	}
	if e.ViewHeight > 0 && e.Row >= e.ScrollRow+e.ViewHeight {
		e.ScrollRow = e.Row - e.ViewHeight + 1
	}
	if e.Col < e.ScrollCol {
		e.ScrollCol = e.Col
	}
	if e.ViewWidth > 0 && e.Col >= e.ScrollCol+e.ViewWidth {
		e.ScrollCol = e.Col - e.ViewWidth + 1
	}
}
