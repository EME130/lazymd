package editor

func (e *EditorModel) handleNormal(key Key) {
	// Ctrl shortcuts
	if key.Ctrl && key.Type == KeyChar {
		switch key.Char {
		case 's':
			e.Save()
		case 'u':
			n := e.Count
			if n == 0 {
				n = e.ViewHeight / 2
				if n == 0 {
					n = 1
				}
			}
			e.Count = 0
			for range n {
				e.moveCursorUp()
			}
		case 'd':
			n := e.Count
			if n == 0 {
				n = e.ViewHeight / 2
				if n == 0 {
					n = 1
				}
			}
			e.Count = 0
			for range n {
				e.moveCursorDown()
			}
		case 'r':
			e.Buf.Redo()
		}
		return
	}

	switch key.Type {
	case KeyChar:
		c := key.Char

		// Count prefix
		if c >= '1' && c <= '9' && e.Count == 0 && e.PendingOp == 0 {
			e.Count = int(c - '0')
			return
		}
		if c >= '0' && c <= '9' && e.Count > 0 {
			e.Count = e.Count*10 + int(c-'0')
			return
		}

		n := e.Count
		if n == 0 {
			n = 1
		}
		e.Count = 0

		// Handle pending operator
		if e.PendingOp != 0 {
			op := e.PendingOp
			e.PendingOp = 0
			if op == 'd' && c == 'd' {
				for range n {
					e.deleteLine()
				}
			}
			return
		}

		switch c {
		// Movement
		case 'h':
			for range n {
				e.moveCursorLeft()
			}
		case 'j':
			for range n {
				e.moveCursorDown()
			}
		case 'k':
			for range n {
				e.moveCursorUp()
			}
		case 'l':
			for range n {
				e.moveCursorRight()
			}
		case 'w':
			for range n {
				e.wordForward()
			}
		case 'b':
			for range n {
				e.wordBackward()
			}
		case 'e':
			for range n {
				e.wordEnd()
			}
		case '0':
			e.Col = 0
		case '$':
			e.cursorToLineEnd()
		case '^':
			e.cursorToFirstNonBlank()

		// Enter insert mode
		case 'i':
			e.mode = ModeInsert
		case 'I':
			e.cursorToFirstNonBlank()
			e.mode = ModeInsert
		case 'a':
			e.moveCursorRight()
			e.mode = ModeInsert
		case 'A':
			e.cursorToLineEnd()
			e.moveCursorRight()
			e.mode = ModeInsert
		case 'o':
			e.cursorToLineEnd()
			offset := e.Buf.PosToOffset(e.Row, e.Col)
			e.Buf.InsertByte(offset, '\n')
			e.Row++
			e.Col = 0
			e.mode = ModeInsert
			e.MarkChanged()
		case 'O':
			lineStart := e.Buf.PosToOffset(e.Row, 0)
			e.Buf.InsertByte(lineStart, '\n')
			e.Col = 0
			e.mode = ModeInsert
			e.MarkChanged()

		// Editing
		case 'x':
			for range n {
				offset := e.Buf.PosToOffset(e.Row, e.Col)
				if offset < e.Buf.Length() {
					e.Buf.DeleteByte(offset)
					e.MarkChanged()
				}
			}
			e.clampCursor()
		case 'd':
			e.PendingOp = 'd'
		case 'u':
			e.Buf.Undo()
		case 'p':
			// paste - TODO: clipboard

		// Jumps
		case 'g':
			e.Row = 0
		case 'G':
			if e.Buf.LineCount() > 0 {
				e.Row = e.Buf.LineCount() - 1
			}

		// Command mode
		case ':':
			e.mode = ModeCommand
			e.CmdBuf = ""
		}

	case KeyUp:
		e.moveCursorUp()
	case KeyDown:
		e.moveCursorDown()
	case KeyLeft:
		e.moveCursorLeft()
	case KeyRight:
		e.moveCursorRight()
	case KeyHome:
		e.Col = 0
	case KeyEnd:
		e.cursorToLineEnd()
	case KeyPageUp:
		for range e.ViewHeight {
			e.moveCursorUp()
		}
	case KeyPageDown:
		for range e.ViewHeight {
			e.moveCursorDown()
		}
	}
}
