package editor

func (e *EditorModel) handleInsert(key Key) {
	if key.Type == KeyEscape {
		e.mode = ModeNormal
		if e.Col > 0 {
			e.Col--
		}
		return
	}

	if key.Ctrl && key.Type == KeyChar {
		switch key.Char {
		case 's':
			e.Save()
		}
		return
	}

	switch key.Type {
	case KeyChar:
		offset := e.Buf.PosToOffset(e.Row, e.Col)
		// UTF-8 encode the rune
		var buf [4]byte
		n := encodeRune(buf[:], key.Char)
		e.Buf.InsertString(offset, string(buf[:n]))
		e.Col++
		e.MarkChanged()

	case KeyEnter:
		offset := e.Buf.PosToOffset(e.Row, e.Col)
		e.Buf.InsertByte(offset, '\n')
		e.Row++
		e.Col = 0
		e.MarkChanged()

	case KeyBackspace:
		offset := e.Buf.PosToOffset(e.Row, e.Col)
		if offset > 0 {
			prevByte := e.Buf.ByteAt(offset - 1)
			e.Buf.DeleteByte(offset - 1)
			if prevByte == '\n' {
				if e.Row > 0 {
					e.Row--
					e.Col = e.Buf.LineLen(e.Row)
				}
			} else {
				if e.Col > 0 {
					e.Col--
				}
			}
			e.MarkChanged()
		}

	case KeyDelete:
		offset := e.Buf.PosToOffset(e.Row, e.Col)
		if offset < e.Buf.Length() {
			e.Buf.DeleteByte(offset)
			e.MarkChanged()
		}

	case KeyTab:
		offset := e.Buf.PosToOffset(e.Row, e.Col)
		e.Buf.InsertString(offset, "    ")
		e.Col += 4
		e.MarkChanged()

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
	}
}

// encodeRune encodes a rune into buf and returns the number of bytes written.
func encodeRune(buf []byte, r rune) int {
	if r < 0x80 {
		buf[0] = byte(r)
		return 1
	}
	if r < 0x800 {
		buf[0] = byte(0xC0 | (r >> 6))
		buf[1] = byte(0x80 | (r & 0x3F))
		return 2
	}
	if r < 0x10000 {
		buf[0] = byte(0xE0 | (r >> 12))
		buf[1] = byte(0x80 | ((r >> 6) & 0x3F))
		buf[2] = byte(0x80 | (r & 0x3F))
		return 3
	}
	buf[0] = byte(0xF0 | (r >> 18))
	buf[1] = byte(0x80 | ((r >> 12) & 0x3F))
	buf[2] = byte(0x80 | ((r >> 6) & 0x3F))
	buf[3] = byte(0x80 | (r & 0x3F))
	return 4
}
